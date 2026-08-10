---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: health feature additions
status: draft
created: 2026-04-26
---

# Health Features Build Guide — HLTH Smartband

## Executive Summary

This document covers five health features to add to the HLTH smartband. Each section includes the **actual algorithms, GitHub repos with working code, and specific integration steps** — not just concepts. All buildable with existing sensors (PPG + SpO2 + accelerometer + gyroscope). All ship as wellness features — no FDA clearance required.

| Feature | Build Effort | New Sensors? |
|---------|-------------|-------------|
| BP Calibration (enhancement) | Low-Medium | No |
| Respiratory Rate | Low | No |
| VO2 Max Estimation | Low | No |
| Recovery / Readiness Score | Low-Medium | No |
| Respiratory Illness Warning | Low-Medium | No |
| Resting Heart Rate | Low | No |

**CRITICAL**: Resting Heart Rate is a foundation metric. Recovery score, illness warning, mental wellness, menstrual cycle, longevity score, and VO2 max ALL depend on it. Build this FIRST.

---

## 0. Resting Heart Rate (Foundation — Build First)

### What It Is
The lowest reliable heart rate when the user is awake and still, or the lowest sustained heart rate during sleep. This is NOT just "heart rate" — the band already measures HR. Resting HR is a specific derivation that identifies WHICH heart rate readings represent the user's true resting state.

Currently the HLTH band measures heart rate but does not identify resting heart rate. This feature must be added because every composite score depends on it.

### Why It's Foundation

| Feature That Depends on RHR | How It Uses RHR |
|-----------------------------|----------------|
| Recovery score | RHR vs 14-day baseline = cardiovascular strain indicator |
| Illness warning | RHR elevated 2+ bpm above baseline for 2+ days = possible infection |
| Mental wellness | Chronically elevated RHR = autonomic stress |
| Menstrual cycle | RHR rises ~2-3 bpm in luteal phase |
| Longevity score | Lower RHR = younger cardiovascular age |
| VO2 max | RHR is a direct input to the Åstrand-Ryhming formula |
| Stress scoring | Elevated RHR vs baseline = acute stress |

### How Competitors Do It

| Device | RHR Method |
|--------|-----------|
| **Oura** | Lowest HR value during sleep |
| **Garmin** | Lowest 30-minute average HR in the last 24 hours |
| **WHOOP** | Overnight average HR, weighted more heavily during deep sleep |
| **Apple Watch** | HR samples when not moving, possibly excluding nighttime |
| **Fitbit** | Lowest HR when still for an extended period |

### The Algorithm

Two methods — use both, take the lower value:

#### Method A: Morning Resting HR

```python
import numpy as np

def calculate_morning_resting_hr(
    hr_readings,           # array of HR values (from PPG peaks)
    accel_magnitudes,      # array of accelerometer magnitude values
    timestamps,            # corresponding timestamps
    wake_time,             # detected wake time
    sampling_rate_hr=1,    # HR samples per second (from peak detection)
    sampling_rate_accel=25 # accelerometer samples per second
):
    """
    Resting HR = average HR during the first 5-minute window
    after wake detection where accelerometer shows minimal movement.
    
    Returns: resting HR in bpm, or None if no valid window found
    """
    # Define "at rest" threshold for accelerometer
    # Standard deviation of magnitude < 0.05g over 30-sec windows = still
    rest_threshold = 0.05  # g
    
    # Look at the first 30 minutes after wake
    search_window_minutes = 30
    
    # Find windows where user is still
    window_size_accel = 30 * sampling_rate_accel  # 30-second windows
    rest_windows = []
    
    post_wake_start = wake_time
    post_wake_end = wake_time + (search_window_minutes * 60)
    
    # Filter to post-wake period
    mask = (timestamps >= post_wake_start) & (timestamps <= post_wake_end)
    
    if not np.any(mask):
        return None
    
    post_wake_accel = accel_magnitudes[mask]
    post_wake_hr = hr_readings[mask[:len(hr_readings)]] if len(hr_readings) > 0 else None
    
    if post_wake_hr is None or len(post_wake_hr) < 60:
        return None
    
    # Slide through 30-second windows looking for stillness
    for i in range(0, len(post_wake_accel) - window_size_accel, window_size_accel // 2):
        window = post_wake_accel[i:i + window_size_accel]
        
        # Check if still: low variability in acceleration
        if np.std(window) < rest_threshold:
            rest_windows.append(i)
    
    # Need at least 5 minutes (10 consecutive 30-sec windows) of stillness
    if len(rest_windows) < 10:
        return None
    
    # Find the first 5-minute continuous rest period
    consecutive = 1
    best_start = rest_windows[0]
    for i in range(1, len(rest_windows)):
        if rest_windows[i] - rest_windows[i-1] <= window_size_accel:
            consecutive += 1
            if consecutive >= 10:
                # Found 5 minutes of stillness
                start_idx = best_start // sampling_rate_accel  # convert to HR time index
                end_idx = start_idx + (5 * 60 * sampling_rate_hr)  # 5 minutes of HR
                
                hr_window = post_wake_hr[start_idx:min(end_idx, len(post_wake_hr))]
                
                if len(hr_window) > 0:
                    # Remove outliers (outside 2 std devs)
                    mean_hr = np.mean(hr_window)
                    std_hr = np.std(hr_window)
                    clean_hr = hr_window[
                        (hr_window > mean_hr - 2*std_hr) & 
                        (hr_window < mean_hr + 2*std_hr)
                    ]
                    return round(np.mean(clean_hr), 1) if len(clean_hr) > 0 else None
        else:
            consecutive = 1
            best_start = rest_windows[i]
    
    return None
```

#### Method B: Overnight Minimum HR

```python
def calculate_overnight_resting_hr(
    hr_readings,       # array of HR values during sleep period
    timestamps,        # corresponding timestamps
    sleep_start,       # detected sleep start time
    sleep_end          # detected sleep end time
):
    """
    Resting HR = lowest 10-minute rolling average HR during sleep.
    
    More consistent than morning method. Less affected by 
    morning stress, caffeine, alarm startle.
    """
    # Filter to sleep period
    mask = (timestamps >= sleep_start) & (timestamps <= sleep_end)
    sleep_hr = hr_readings[mask]
    
    if len(sleep_hr) < 600:  # need at least 10 minutes of data
        return None
    
    # Remove physiologically impossible values
    sleep_hr = sleep_hr[(sleep_hr >= 30) & (sleep_hr <= 120)]
    
    if len(sleep_hr) < 600:
        return None
    
    # 10-minute rolling average (assuming 1 Hz HR)
    window = 600  # 10 minutes in seconds
    rolling_avg = np.convolve(sleep_hr, np.ones(window)/window, mode='valid')
    
    # Lowest 10-minute average = resting HR
    overnight_rhr = np.min(rolling_avg)
    
    # Also get the 5th percentile (more robust to brief dips)
    percentile_5 = np.percentile(rolling_avg, 5)
    
    # Use 5th percentile — more stable than absolute minimum
    return round(percentile_5, 1)


def get_daily_resting_hr(morning_rhr, overnight_rhr):
    """
    Combine both methods. Use the lower value.
    If only one is available, use that one.
    """
    values = [v for v in [morning_rhr, overnight_rhr] if v is not None]
    
    if not values:
        return None
    
    # Use the lower of the two
    rhr = min(values)
    
    # Sanity check
    if rhr < 30 or rhr > 120:
        return None
    
    return rhr
```

### Accelerometer-Based "At Rest" Detection

The key to resting HR is knowing when the user is still. This function is reusable across features:

```python
def detect_rest_state(accel_x, accel_y, accel_z, sampling_rate, window_seconds=30):
    """
    Detect whether the user is at rest (minimal movement).
    
    Returns: array of boolean values, True = at rest for that window.
    Used by: resting HR, stress scoring, recovery measurements.
    """
    magnitude = np.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
    
    window_size = window_seconds * sampling_rate
    is_resting = []
    
    for i in range(0, len(magnitude) - window_size, window_size):
        window = magnitude[i:i + window_size]
        
        # At rest if:
        # 1. Std dev of acceleration is low (not moving)
        # 2. Mean is close to 1g (just gravity, no sustained motion)
        std = np.std(window)
        mean = np.mean(window)
        
        at_rest = (std < 0.05) and (0.9 < mean < 1.1)
        is_resting.append(at_rest)
    
    return np.array(is_resting)
```

### Free Tools + Repos

| Resource                           | What                                                                                                         | Link                                                                    |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| **RapidHRV**                       | Python package for HR + HRV from wrist PPG, calibrated for low-motion conditions                             | https://github.com/pzsp2-23z/RapidHRV (also via `pip install rapidhrv`) |
| **Wearable Pulse Rate Estimation** | Random Forest model for HR from PPG + 3-axis accelerometer, includes confidence scoring                      | https://github.com/phthaloc/wearable_pulse_rate_estimation              |
| **Heart Rate Estimation PPG+Acc**  | Full pipeline: PPG + accelerometer → HR estimation with motion compensation                                  | https://github.com/ElliotY-ML/Heart_Rate_Estimation_PPG_Acc             |
| **Pulse-PPG Foundation Model**     | Open-source PPG foundation model (1D ResNet-26), trained on 200M seconds of field data from 120 participants | https://github.com/maxxu05                                              |
| **SPEAR**                          | Self-supervised PPG denoiser — cleans corrupted PPG for better HR extraction                                 | Published methodology — search "SPEAR PPG denoise"                      |
| **BeliefPPG**                      | Best benchmarked HR estimator: 0.7 ± 0.8 bpm bias                                                            | Published — search "BeliefPPG"                                          |
| **hrvanalysis**                    | Production HRV computation (uses R-R intervals which come from peak detection)                               | https://github.com/Aura-healthcare/hrv-analysis                         |
| **HeartPy**                        | HR analysis specifically designed for noisy wearable PPG                                                     | https://github.com/paulvangentcom/heartrate_analysis_python             |

### Free Datasets

| Dataset | What | Link |
|---------|------|------|
| **CAST (Cardiac Arrhythmia Suppression Trial)** | 24-hour HR data, smoothed to resemble wearable PPG | PhysioNet |
| **PPG-DaLiA** | 15 subjects, PPG + accelerometer during daily living activities | Public dataset |
| **TROIKA** | PPG + ECG + accelerometer for HR estimation during motion | PhysioNet |
| **PulseDB** | 5.2M PPG segments with demographics | https://www.frontiersin.org/articles/10.3389/fdgth.2022.1090854/full |

### Integration Steps

```
STEP 1: Every night during sleep
  - Run peak detection on PPG bursts during sleep
  - Calculate HR for each burst
  - Store timestamped HR values

STEP 2: Calculate overnight resting HR
  - After wake detection, take all sleep-period HR values
  - Compute lowest 10-minute rolling average (5th percentile)
  - Store as overnight_rhr

STEP 3: Calculate morning resting HR
  - After wake detection, monitor accelerometer for 30 minutes
  - Find first 5-minute window where user is still
  - Average HR during that window
  - Store as morning_rhr

STEP 4: Daily resting HR
  - daily_rhr = min(overnight_rhr, morning_rhr)
  - Store in daily_metrics table
  - Update 14-day rolling baseline

STEP 5: Display
  - Show on home screen: "Resting HR: 62 bpm"
  - Show trend chart: daily RHR over 7/30/90 days
  - Flag if significantly above 14-day baseline
```

### Build Effort: Low
The accelerometer-based rest detection is simple threshold logic. The HR averaging is basic math. The overnight minimum is a rolling window. This should be one of the first things built because everything else depends on it.

---

## 1. Blood Pressure Calibration (Enhancement to Existing Feature)

### What It Is
User inputs a reading from a standard arm cuff. The algorithm uses this as an anchor point to improve accuracy of continuous PPG-based BP estimation.

### Actual Algorithms + Code

#### Algorithm A: Reflective Pulse Transit Time (R-PTT) Calibration

This is the clinically validated approach. Uses the Moens-Korteweg and Bramwell-Hill equations from cardiovascular physics.

**How the calibration math works:**

```
1. During calibration, user wears band + takes cuff reading simultaneously
2. Algorithm extracts R-PTT from PPG waveform (time for pulse wave to travel)
3. Average R-PTT over first 30 seconds (mean point-to-point pairing)
4. Solve for three personalized constants: Ka, Kb, Kc
   BP = Ka × (1/R-PTT²) + Kb × (1/R-PTT) + Kc
5. These constants encode THIS user's vascular properties
6. All future readings use the personalized equation
```

**Published accuracy:** MAE 4.92 mmHg diastolic, 8.89 mmHg systolic (30 patients validated)

#### Algorithm B: Deep Learning Calibration (LSTM/CNN)

**GitHub repo with working code:**
- **Abhishek676062/cuff-less-blood-pressure-estimation**: https://github.com/Abhishek676062/cuff-less-blood-pressure-estimation
  - Full ML framework: LSTM, ANN, and CNN architectures
  - Takes PPG + ECG signals as input → predicts systolic + diastolic
  - Includes data loading, preprocessing, normalization, train/test split
  - Evaluation: MSE and RMSE in mmHg
  - **To add calibration**: fine-tune the pre-trained model on user's cuff readings

#### Algorithm C: Domain-Adapted Personalized Models

**GitHub repo:**
- **stmilab/cufflessbp_dann**: https://github.com/stmilab/cufflessbp_dann
  - Domain Adaptation Neural Network (DANN)
  - Pre-trains on large population dataset, then adapts to individual user with minimal calibration samples
  - Specifically designed for the calibration use case — few cuff readings needed

#### Feature Extraction Tool

**PhysioZoo PPG** (https://github.com/physiozoo/PhysioZoo): Extracts PPG morphological biomarkers needed for all BP algorithms:
- Fiducial point detection (pulse onset, systolic peak, diastolic minimum)
- Stiffness index calculation
- 9 statistical measures per biomarker (mean, SD, quartiles, skewness, kurtosis)
- Exports feature vectors ready for ML models

#### Training Data

**MIMIC database** (PhysioNet): Synchronized PPG + arterial blood pressure from ICU patients. Use Peter Charlton's BSP Book implementation for the complete pipeline: extract 10-min segments → compute morphological features → average over 30-sec windows → train regression model.

### Integration Steps

```
STEP 1: Extract PPG features using PhysioZoo PPG
  Input: raw PPG waveform from band
  Output: feature vector (PTT, stiffness index, morphology)

STEP 2: Pre-train BP model using MIMIC data
  Use Abhishek676062 repo or stmilab/cufflessbp_dann
  Train on population data → general BP estimation

STEP 3: Calibration event
  User takes cuff reading + band captures PPG simultaneously
  Extract features from that PPG segment
  Fine-tune model with (features, cuff_reading) pair
  Store personalized model parameters on device/cloud

STEP 4: Ongoing estimation
  Run PPG features through personalized model
  Output calibrated BP estimate

STEP 5: Recalibration prompt
  Every 2-4 weeks, prompt user to recalibrate
  Vascular properties drift — model needs refreshing
```

### Key References
- Abhishek676062 BP estimation: https://github.com/Abhishek676062/cuff-less-blood-pressure-estimation
- stmilab DANN calibration: https://github.com/stmilab/cufflessbp_dann
- PhysioZoo PPG features: https://github.com/physiozoo/PhysioZoo
- R-PTT calibration paper: MAE 4.92/8.89 mmHg validated on 30 patients
- Peter Charlton's BSP Book: comprehensive PPG→BP pipeline with MIMIC data

---

## 2. Respiratory Rate

### What It Is
Continuous breathing rate extracted from PPG. Normal: 12-20 breaths/min at rest.

### Actual Algorithms + Code

#### Algorithm A: Correncoder Deep Learning (Best Accuracy)

**GitHub repo with working code:**
- **harryjdavies/correncoder_ppg_respiration**: https://github.com/harryjdavies/correncoder_ppg_respiration
  - Deep learning model (PyTorch) that takes raw PPG → outputs full respiratory waveform
  - Not just rate — extracts the complete breathing pattern
  - Uses convolutional autoencoder architecture
  - Training script: `correncoder_capnobase_training.py`
  - Trained on CapnoBase dataset (PPG + capnogram ground truth)
  - Load trained model → feed PPG → get respiratory waveform → count peaks = breaths/min

**How to use:**
```python
import torch
# Load pre-trained correncoder model
model = torch.load('correncoder_model.pth')
model.eval()

# Feed raw PPG waveform
ppg_segment = preprocess(raw_ppg)  # bandpass filter, normalize
respiratory_waveform = model(ppg_segment)

# Extract rate from waveform
peaks = find_peaks(respiratory_waveform)
respiratory_rate = len(peaks) / duration_minutes
```

#### Algorithm B: Multi-Modal Fusion (PPG + Accelerometer)

**GitHub repo:**
- **Predicting_Respiratory_Rate** (ML competition winner, 90% accuracy)
  - Combines PPG + ECG/accelerometer features
  - Handles multi-rate sampling (1 Hz + 125 Hz)
  - Supervised ML regression on fused features
  - First place, NY division

#### Algorithm C: Multi-Method Feature Extraction + Regression

**GitHub repo:**
- **Kapil19-dev/RESPIRATION_RATE_ESTIMATION**: https://github.com/Kapil19-dev/RESPIRATION_RATE_ESTIMATION
  - Built on PPG-DaLiA dataset (publicly available)
  - Extracts respiratory signals from PPG, accelerometer, and ECG independently
  - Feature fusion from all modalities
  - Tests 4 regression models: Ridge, Random Forest, SVR, Bayesian Ridge
  - Also includes deep learning approach: encoder-decoder with residual blocks (IncResNet)
  - Multitask learning: predicts both respiratory waveform AND rate simultaneously

#### Algorithm D: Signal Processing Only (No ML — Simplest)

**Library: NeuroKit2** — one function call:
```python
import neurokit2 as nk

# Process PPG signal
signals, info = nk.ppg_process(ppg_signal, sampling_rate=75)

# Extract respiratory rate from PPG
rsp_rate = nk.ppg_rsp(signals["PPG_Clean"], sampling_rate=75)
```

**Library: BioSPPy** — also one function call:
```python
from biosppy.signals import ppg
result = ppg.ppg(signal=raw_ppg, sampling_rate=75, show=False)
# Respiratory rate derived from peak intervals
```

**Peter Charlton's RRest toolbox**: 15+ respiratory rate algorithms benchmarked against each other. Best performers: smart fusion of RIIV + RIAV + RIFV methods. Available at https://peterhcharlton.github.io/RRest

#### BIOBSS: End-to-End Wearable Signal Processing

**GitHub repo:**
- **obss/BIOBSS**: https://github.com/obss/BIOBSS
  - Complete pipeline: PPG → respiratory signal extraction → respiratory rate estimation
  - Also handles HRV analysis, activity index from accelerometer
  - Modular — use individual components or full pipeline

### Training Data
- **CapnoBase**: 42 recordings, PPG + reference capnogram (gold standard)
- **PPG-DaLiA**: 15 subjects, PPG + accelerometer during daily living
- **TROIKA**: PPG + ECG + accelerometer for RR estimation

### Integration Steps

```
OPTION 1 (Fastest — ship in days):
  Use NeuroKit2 ppg_rsp() function
  Input: raw PPG from band
  Output: breaths per minute
  Accuracy: ±2-3 breaths/min

OPTION 2 (Best accuracy — ship in 1-2 weeks):
  Use correncoder pre-trained model
  Input: raw PPG from band
  Output: full respiratory waveform + rate
  Accuracy: ±1-2 breaths/min
  Bonus: can visualize breathing pattern, not just number

OPTION 3 (Best with motion — for active monitoring):
  Use RESPIRATION_RATE_ESTIMATION repo
  Input: PPG + accelerometer from band
  Output: rate even during movement
  Accuracy: better during activity than PPG-only methods
```

### Key References
- Correncoder model: https://github.com/harryjdavies/correncoder_ppg_respiration
- RR estimation multi-modal: https://github.com/Kapil19-dev/RESPIRATION_RATE_ESTIMATION
- BIOBSS pipeline: https://github.com/obss/BIOBSS
- RRest benchmark (15 algorithms): https://peterhcharlton.github.io/RRest
- CapnoBase dataset: https://physionet.org

---

## 3. VO2 Max Estimation

### What It Is
Estimated cardiorespiratory fitness. Expressed in mL/kg/min. Strongest single predictor of longevity.

### Actual Algorithms + Code

#### Algorithm A: Åstrand-Ryhming Formula (Ship Immediately)

No ML needed. Pure math:

```python
def estimate_vo2max_astrand(age, sex, resting_hr, exercise_hr, exercise_intensity):
    """
    Åstrand-Ryhming submaximal test adaptation for wearables.
    
    exercise_intensity: estimated from accelerometer (METs or speed)
    exercise_hr: average HR during 10+ min steady-state activity
    """
    # Age-predicted max HR
    hr_max = 220 - age
    
    # Heart rate reserve method (Karvonen)
    hr_reserve = hr_max - resting_hr
    pct_hr_reserve = (exercise_hr - resting_hr) / hr_reserve
    
    # VO2 max estimation
    # Based on linear relationship between %HRR and %VO2max
    exercise_vo2 = exercise_intensity  # in METs, from accelerometer
    vo2_max = exercise_vo2 / pct_hr_reserve
    
    # Convert to mL/kg/min
    vo2_max_ml = vo2_max * 3.5  # 1 MET = 3.5 mL/kg/min
    
    # Age correction factor (Åstrand)
    if age < 25:
        correction = 1.0
    elif age < 35:
        correction = 0.87
    elif age < 40:
        correction = 0.83
    elif age < 45:
        correction = 0.78
    elif age < 50:
        correction = 0.75
    elif age < 55:
        correction = 0.71
    elif age < 60:
        correction = 0.68
    else:
        correction = 0.65
    
    return vo2_max_ml * correction
```

**Accuracy:** ±10-15% of lab-measured VO2 max. Good enough for a wellness feature.

#### Algorithm B: Heart Rate Recovery Method

```python
def vo2max_from_hr_recovery(exercise_hr_peak, hr_after_60sec, age, sex):
    """
    Uses post-exercise heart rate drop as fitness indicator.
    Faster drop = better parasympathetic reactivation = higher fitness.
    """
    hr_recovery = exercise_hr_peak - hr_after_60sec
    
    # Cole formula (validated in clinical studies)
    if sex == 'male':
        vo2_max = 28.5 + (0.54 * hr_recovery) - (0.155 * age)
    else:
        vo2_max = 23.8 + (0.54 * hr_recovery) - (0.155 * age)
    
    return vo2_max  # mL/kg/min
```

**Normal HR recovery:** >12 bpm drop in first minute = healthy. <12 bpm = concerning.

#### Algorithm C: ML-Based Estimation

**GitHub repo:**
- **SeanPresent/VO2MaxEstimation**: VO2 max prediction using ML on wearable data
- Features: resting HR, exercise HR, HR recovery, activity intensity, age, sex, weight
- Trains Random Forest / Gradient Boosting regression

#### Accelerometer-Based Activity Intensity (METs Estimation)

The accelerometer provides the "activity intensity" input needed for VO2 max:

```python
def estimate_mets_from_accelerometer(accel_magnitude, sampling_rate):
    """
    Convert raw accelerometer data to estimated METs.
    Based on Freedson equation (validated for wrist-worn devices).
    """
    # Calculate counts per minute from raw acceleration
    # accel_magnitude = sqrt(x² + y² + z²) for each sample
    epoch_seconds = 60
    samples_per_epoch = sampling_rate * epoch_seconds
    
    # Activity counts (simplified — sum of filtered acceleration)
    counts_per_min = sum(abs(accel_magnitude)) / len(accel_magnitude) * samples_per_epoch
    
    # Freedson equation (adult, wrist)
    if counts_per_min < 100:
        mets = 1.0  # sedentary
    elif counts_per_min < 1952:
        mets = 1.5  # light
    elif counts_per_min < 5725:
        mets = 1.4853 + (0.000476 * counts_per_min)  # moderate
    else:
        mets = 1.4853 + (0.000476 * counts_per_min)  # vigorous
    
    return mets
```

### Integration Steps

```
STEP 1: Detect sustained activity (NOT just exercise)
  Accelerometer shows elevated movement for 10+ min continuously
  This includes: walking, running, cycling, hiking, cleaning — any sustained movement
  PPG shows HR above 50% of heart rate reserve
  Walking counts — most people walk daily, so VO2 max unlocks fast
  Tag this as a "qualifying activity session"

STEP 2: During activity, collect:
  - Average HR (from PPG)
  - Activity intensity in METs (from accelerometer via Freedson equation)
  - Duration
  - Activity type (walking vs running vs other — from accelerometer cadence)

STEP 3: After activity stops (HR begins declining), collect:
  - Peak HR at end of activity
  - HR at 60 seconds post-activity (recovery)

STEP 4: Calculate VO2 max
  Run Algorithm A (Åstrand-Ryhming) using activity HR + METs
  Run Algorithm B (HR Recovery) using peak HR + 60-sec recovery
  Average the two estimates for better accuracy
  Walking gives a less precise estimate than running but still valid

STEP 5: Update over time
  Each qualifying activity session (10+ min sustained) produces a new estimate
  Use 7-day rolling average of estimates
  More intense activities (running) produce more accurate estimates
  Walking estimates improve with more data points over time
  Show trend: "Your fitness is improving"

STEP 6: User requirements
  Profile must have: age, sex
  Optional: weight (improves per-kg accuracy)
  Resting HR required (from Section 0 of this doc) — used in Karvonen formula
```

### Key References
- Åstrand-Ryhming protocol: published, no license needed
- Cole HR recovery formula: validated in clinical studies
- Freedson accelerometer equation: standard for wrist-worn activity counts
- HeartPy toolkit: https://github.com/paulvangentcom/heartrate_analysis_python
- NHANES fitness data: https://cdc.gov/nchs/nhanes

---

## 4. Recovery / Readiness Score

### What It Is
Daily 0-100 score = how recovered your body is. WHOOP's business model. Oura's flagship.

### Actual Algorithms + Code

#### The HRV Processing Pipeline (Foundation for Everything)

**GitHub repo with production-grade code:**
- **Aura-healthcare/hrv-analysis**: https://github.com/Aura-healthcare/hrv-analysis
  - `pip install hrv-analysis`
  - Production-ready HRV computation from R-R intervals
  - Handles artifact removal, ectopic beat detection, interpolation
  - Outputs ALL standard HRV metrics needed for recovery scoring

**Actual code to compute HRV features:**
```python
from hrvanalysis import (
    remove_outliers, 
    remove_ectopic_beats, 
    interpolate_nan_values,
    get_time_domain_features,
    get_frequency_domain_features
)

# rr_intervals from PPG peak detection (in milliseconds)
rr_intervals = [1000, 1050, 1020, 1080, 1100, 1110, 1060, ...]

# Step 1: Remove outliers (physiologically impossible values)
rr_clean = remove_outliers(rr_intervals=rr_intervals, low_rri=300, high_rri=2000)

# Step 2: Interpolate gaps
rr_interpolated = interpolate_nan_values(rr_intervals=rr_clean, interpolation_method="linear")

# Step 3: Remove ectopic beats (Malik method)
nn_intervals = remove_ectopic_beats(rr_intervals=rr_interpolated, method="malik")
nn_intervals = interpolate_nan_values(rr_intervals=nn_intervals)

# Step 4: Extract features
time_features = get_time_domain_features(nn_intervals)
# Returns: mean_nni, sdnn, sdsd, nni_50, pnni_50, nni_20, pnni_20,
#          rmssd, median_nni, range_nni, cvsd, cvnni, mean_hr, 
#          max_hr, min_hr, std_hr

freq_features = get_frequency_domain_features(nn_intervals)
# Returns: lf, hf, lf_hf_ratio, lfnu, hfnu, total_power, vlf
```

#### Recovery Score Algorithm (Reverse-Engineered from Oura)

**GitHub repo:**
- **pratikchheda4/oura-sleep-ring**: https://github.com/pratikchheda4/oura-sleep-ring
  - Reconstructed Oura's readiness formula using Lasso Regression on 1 year of data
  - **Best model: Lasso Regression — MSE 6.91, R² = 0.846**
  - Top 5 feature weights discovered:
    1. `total_sleep_time`: coefficient 25.26 (most important)
    2. `sleep_latency`: coefficient 12.14
    3. `awake_time × lowest_resting_heart_rate`: coefficient -10.30
    4. `sleep_latency²`: coefficient -9.49
    5. `rem_sleep_time`: coefficient 7.56

#### Recovery Score Algorithm (Open Wearables Platform)

**GitHub repo:**
- **the-momentum/open-wearables**: https://github.com/the-momentum/open-wearables
  - Released April 2026 — ships Sleep Score + Resilience Score with fully auditable code
  - Resilience Score = recovery metric combining HRV, resting HR, sleep quality
  - Uses **HRV-CV (Coefficient of Variation)** as core computation
  - Every coefficient published in the repo — fork and customize
  - Ingests data from Garmin, WHOOP, Polar, Oura via unified API
  - Includes webhook streaming and seed data generators for testing

#### Recovery Score Algorithm (TensorFlow Approach)

**GitHub repo:**
- **danielecursano/Fitbit-Readiness-Prediction-TF**: https://github.com/danielecursano/Fitbit-Readiness-Prediction-TF
  - TensorFlow neural network for readiness prediction
  - Trained on Fitbit biometric data (HR, HRV, sleep, activity)
  - Includes data preprocessing, model training, evaluation notebooks
  - Template architecture for custom readiness scoring

#### Building Your Own Score (Recommended Starting Point)

```python
import numpy as np

def calculate_recovery_score(
    rmssd_today,       # from hrvanalysis
    rmssd_baseline_14d,# 14-day rolling average
    rhr_today,         # resting heart rate (morning)
    rhr_baseline_14d,
    sleep_score,       # 0-100 from sleep staging (duration + deep% + efficiency)
    spo2_overnight,    # average overnight SpO2
    spo2_baseline_14d,
    strain_yesterday   # activity load from previous day (0-21 scale, like WHOOP)
):
    """
    Composite recovery score. Personalized against 14-day baselines.
    Returns 0-100.
    """
    # Normalize each metric against personal baseline
    # Positive = better than baseline, Negative = worse
    
    # HRV: higher is better
    hrv_norm = (rmssd_today - rmssd_baseline_14d) / rmssd_baseline_14d
    hrv_score = 50 + (hrv_norm * 100)  # center at 50, scale
    hrv_score = np.clip(hrv_score, 0, 100)
    
    # Resting HR: lower is better (invert)
    rhr_norm = (rhr_baseline_14d - rhr_today) / rhr_baseline_14d
    rhr_score = 50 + (rhr_norm * 100)
    rhr_score = np.clip(rhr_score, 0, 100)
    
    # Sleep: already 0-100
    sleep_score = np.clip(sleep_score, 0, 100)
    
    # SpO2: higher is better
    spo2_norm = (spo2_overnight - spo2_baseline_14d) / spo2_baseline_14d
    spo2_score = 50 + (spo2_norm * 200)  # SpO2 changes are small, amplify
    spo2_score = np.clip(spo2_score, 0, 100)
    
    # Strain: higher strain yesterday = needs more recovery
    strain_factor = max(0, 1 - (strain_yesterday / 21))  # 0-1 scale
    strain_score = strain_factor * 100
    
    # Weighted composite
    weights = {
        'hrv': 0.30,      # strongest recovery signal
        'rhr': 0.20,      # cardiovascular strain
        'sleep': 0.25,    # sleep is #1 recovery tool
        'spo2': 0.10,     # supplementary
        'strain': 0.15    # what the body is recovering from
    }
    
    recovery = (
        weights['hrv'] * hrv_score +
        weights['rhr'] * rhr_score +
        weights['sleep'] * sleep_score +
        weights['spo2'] * spo2_score +
        weights['strain'] * strain_score
    )
    
    return round(np.clip(recovery, 0, 100))

# Classification
def recovery_zone(score):
    if score >= 67:
        return "green", "Fully recovered — ready for high intensity"
    elif score >= 34:
        return "yellow", "Moderate — light to moderate activity recommended"
    else:
        return "red", "Low recovery — take it easy today"
```

### Integration Steps

```
STEP 1: Every morning, after wake detection:
  Extract 5-min resting PPG segment
  Run through hrvanalysis → get RMSSD, resting HR
  Pull overnight SpO2 average
  Pull sleep staging results from previous night

STEP 2: Compute 14-day rolling baselines
  Store daily RMSSD, RHR, SpO2, sleep scores
  Calculate rolling averages for normalization

STEP 3: Calculate recovery score
  Use the function above (or fork Open Wearables repo)
  Store daily score

STEP 4: Display
  Score number (0-100) + color zone (red/yellow/green)
  Contributing factors: "HRV 15% above baseline ✓"
  7-day trend chart
```

### Key References
- hrvanalysis package: https://github.com/Aura-healthcare/hrv-analysis
- Open Wearables (Resilience Score): https://github.com/the-momentum/open-wearables
- Oura score reconstruction: https://github.com/pratikchheda4/oura-sleep-ring
- Fitbit readiness TensorFlow: https://github.com/danielecursano/Fitbit-Readiness-Prediction-TF
- HeartPy: https://github.com/paulvangentcom/heartrate_analysis_python
- pyHRV: https://pyhrv.readthedocs.io

---

## 5. Respiratory Illness Early Warning

### What It Is
Detects early signs of respiratory infection 1-2 days before symptoms appear. Based on overnight vital sign deviations from personal baseline.

### Actual Algorithms + Code

#### Algorithm A: Stanford NightSignal (Best — 78% Sensitivity)

**GitHub repo with working code:**
- **StanfordBioinformatics/wearable-infection**: https://github.com/StanfordBioinformatics/wearable-infection
  - Contains THREE illness detection algorithms: NightSignal, RHRAD, CuSum
  - **NightSignal is the best**: 78% sensitivity, 86.9% specificity
  - Tested on 45 COVID-positive participants
  - Uses deterministic finite state machine (FSM) on overnight resting heart rate

**How NightSignal works:**
1. Establishes healthy baseline = median of average overnight resting HR
2. Monitors nightly RHR deviations from baseline using FSM state transitions
3. Filters out daytime confounders (stress, exercise) by using overnight data only
4. Generates yellow (warning) or red (serious) alerts when anomalies persist across 24-hour windows
5. Outputs JSON alerts + PDF visualization

**Actual usage:**
```bash
# For Fitbit data:
python3 nightsignal.py --device=Fitbit --restinghr=<RHR_FILE>

# For Apple Watch data:
python3 nightsignal.py --device=AppleWatch --heartrate=<HR_FILE> --step=<STEP_FILE>

# Output: JSON alerts + PDF plot showing RHR, baseline, and FSM alerts
```

**The algorithm:**
- Training: 744 hours (1 month) of baseline RHR data
- Testing: 1-hour sliding windows after baseline period
- Alert logic: if anomalies appear frequently within 24-hour periods → yellow/red alert
- Alert delivery: daily at 9 PM

#### Algorithm B: AnomalyDetect (Multi-Device Compatible)

**GitHub repo:**
- **gireeshkbogu/AnomalyDetect**: https://github.com/gireeshkbogu/AnomalyDetect
  - Works with Fitbit, Apple Watch, Garmin, Empatica
  - Uses both RHR and HROS (Heart Rate Over Steps) metrics
  - Offline mode (batch analysis) + online mode (real-time alerts)
  - 744-hour baseline → 1-hour sliding window anomaly detection
  - Outputs: anomaly CSV + alert CSV + PDF visualizations

**Actual usage:**
```bash
# Real-time alert mode
python rhrad_online_alerts.py \
  --heart_rate hr.csv \
  --steps steps.csv \
  --myphyd_id user_123 \
  --figure1 anomalies.pdf \
  --anomalies anomalies.csv \
  --outliers_fraction 0.1 \
  --random_seed 10 \
  --baseline_window 744 \
  --sliding_window 1 \
  --alerts alerts.csv \
  --figure2 alerts.pdf
```

#### Algorithm C: Respiratory Rate Anomaly Detection

**GitHub repo:**
- **science21/Anomaly-Detection-and-Prediction-of-Respiratory-Rate**: https://github.com/science21/Anomaly-Detection-and-Prediction-of-Respiratory-Rate
  - Detects respiratory rate anomalies from wearable sensor data
  - Two methods: seasonal-trend decomposition + K-means clustering
  - Tests 9 ML algorithms for classification
  - **AdaBoost performed best: 96% AUC**
  - ~99% overall accuracy across all algorithms

#### Algorithm D: Isolation Forest Anomaly Detection (Simplest Custom Build)

```python
from sklearn.ensemble import IsolationForest
import numpy as np

def detect_illness_anomaly(daily_metrics_df):
    """
    Input: DataFrame with columns: rmssd, resting_hr, spo2, respiratory_rate, sleep_efficiency
    Each row = one day of data
    
    Uses unsupervised anomaly detection — no labeled training data needed.
    """
    features = daily_metrics_df[['rmssd', 'resting_hr', 'spo2', 'respiratory_rate', 'sleep_efficiency']]
    
    # Need at least 14 days of baseline
    if len(features) < 14:
        return None, "Collecting baseline data..."
    
    # Isolation Forest: 5% contamination = expect ~5% of days to be anomalous
    model = IsolationForest(n_estimators=100, contamination=0.05, random_state=42)
    
    # Fit on all historical data
    predictions = model.fit_predict(features)
    # -1 = anomaly, 1 = normal
    
    # Check if today (last row) is flagged
    today_is_anomaly = predictions[-1] == -1
    
    # Check how many of last 3 days are anomalies (multi-day persistence)
    recent_anomalies = sum(predictions[-3:] == -1)
    
    if recent_anomalies >= 2:
        return "red", "Your vitals have been unusual for multiple days — consider extra rest"
    elif today_is_anomaly:
        return "yellow", "Some vital signs are outside your normal range today"
    else:
        return "green", None

def multi_signal_illness_check(today, baseline_14d):
    """
    Simpler threshold-based approach (no ML needed).
    Replicates Fitbit/Stanford methodology.
    """
    deviations = 0
    details = []
    
    # Resting HR: elevated?
    if today['resting_hr'] > baseline_14d['resting_hr'] + 2:
        deviations += 1
        details.append(f"Resting HR elevated ({today['resting_hr']} vs baseline {baseline_14d['resting_hr']:.0f})")
    
    # HRV: suppressed?
    if today['rmssd'] < baseline_14d['rmssd'] * 0.85:  # 15% below baseline
        deviations += 1
        details.append(f"HRV below baseline ({today['rmssd']:.0f}ms vs {baseline_14d['rmssd']:.0f}ms)")
    
    # SpO2: dropped?
    if today['spo2'] < baseline_14d['spo2'] - 1.0:
        deviations += 1
        details.append(f"SpO2 dropped ({today['spo2']:.1f}% vs baseline {baseline_14d['spo2']:.1f}%)")
    
    # Respiratory rate: elevated?
    if today['respiratory_rate'] > baseline_14d['respiratory_rate'] + 2:
        deviations += 1
        details.append(f"Breathing rate elevated ({today['respiratory_rate']:.0f} vs {baseline_14d['respiratory_rate']:.0f})")
    
    # Sleep efficiency: dropped?
    if today['sleep_efficiency'] < baseline_14d['sleep_efficiency'] - 10:
        deviations += 1
        details.append("Sleep quality declined")
    
    if deviations >= 3:
        return "red", "Multiple vital signs shifted — your body may be fighting something", details
    elif deviations >= 2:
        return "yellow", "Some vital signs are outside your normal range", details
    else:
        return "green", None, []
```

### Integration Steps

```
STEP 1: Collect 30 days of overnight baseline data
  Store nightly: resting HR, RMSSD, SpO2, respiratory rate, sleep efficiency
  This is the "learning your body" phase
  NightSignal needs 744 hours (31 days) for its FSM baseline

STEP 2: Choose algorithm
  OPTION A: Deploy Stanford NightSignal (proven, published, 78% sensitivity)
    - Adapt input format to match HLTH band's data export
    - RHR + step data → FSM → alerts
  
  OPTION B: Deploy multi-signal threshold check (simpler, more signals)
    - Use the multi_signal_illness_check() function above
    - Leverages ALL sensors (RHR + HRV + SpO2 + RR + sleep)
    - More signals = potentially higher sensitivity than RHR-only

  OPTION C: Both — NightSignal as primary, multi-signal as confirmation

STEP 3: Alert logic
  Don't alert on single-day anomalies (too many false positives)
  Require 2+ consecutive days of deviation
  Alert at morning (after overnight data processed)

STEP 4: Notification
  "Your overnight vitals have shifted from your normal pattern.
   Consider extra rest and monitor for symptoms."
  Show which specific metrics are elevated
```

### Key References
- Stanford NightSignal (78% sensitivity): https://github.com/StanfordBioinformatics/wearable-infection
- AnomalyDetect (multi-device): https://github.com/gireeshkbogu/AnomalyDetect
- Respiratory rate anomaly (96% AUC): https://github.com/science21/Anomaly-Detection-and-Prediction-of-Respiratory-Rate
- Isolation Forest tutorial for HRV: https://dev.to/wellallytech (building HRV anomaly detector)
- Stanford COVID wearable study: 67% pre-symptomatic detection validated prospectively
- Prospective validation study: 92.4% sensitivity, 89.7% specificity for respiratory infections

---

## Shared Infrastructure Across All Features

| Component | Used By | Tool |
|-----------|---------|------|
| PPG signal acquisition + BLE | All | Existing |
| R-R interval extraction | All | hrvanalysis, HeartPy |
| HRV computation (RMSSD, SDNN, LF/HF) | Recovery, Illness, VO2 | hrvanalysis |
| PPG morphology features | BP Calibration | PhysioZoo PPG |
| SpO2 extraction | Recovery, Illness | Existing |
| Sleep staging | Recovery, Illness | Existing |
| Respiratory rate extraction | RR, Illness | NeuroKit2 or correncoder |
| Accelerometer activity intensity | VO2 Max | Freedson equation |
| 14-day rolling baselines | Recovery, Illness | Custom (simple rolling avg) |
| Anomaly detection | Illness Warning | NightSignal or Isolation Forest |

---

## What the Engineer Needs to Start

### Information to provide:
- [ ] **PPG raw data format** — sample rate, bit depth, how it's currently exposed to the app
- [ ] **Current BP algorithm** — what features/model are used? Determines calibration integration path
- [ ] **R-R interval availability** — does the app already extract these from PPG? If not, hrvanalysis handles it
- [ ] **Data storage** — does the app store daily resting HR, HRV, SpO2 history? How far back?
- [ ] **User profile fields** — age, sex, weight currently collected?
- [ ] **Sleep staging output** — what metrics are available? (duration, deep%, REM%, efficiency, latency)
- [ ] **Exercise session detection** — does the app already detect exercise start/stop events?

### Priority Order:
1. **Respiratory Rate** — NeuroKit2 one-liner, ship in days
2. **Recovery Score** — hrvanalysis + composite function, ship in 1-2 weeks
3. **BP Calibration** — PhysioZoo features + personalized regression, ship in 2-3 weeks
4. **VO2 Max** — Åstrand formula + HR recovery, ship in 2-3 weeks
5. **Illness Warning** — NightSignal needs 30 days baseline, start collecting day 1

---

## Cost Summary

| Item | Cost |
|------|------|
| Datasets | Free |
| Libraries (hrvanalysis, NeuroKit2, etc.) | Free (open-source) |
| GitHub algorithm repos | Free |
| Stanford NightSignal | Free (open-source) |
| New sensors required | None |
| Model training compute | Minimal (<$50) |
| FDA submission | $0 (all wellness features) |
| **Total** | **~$0-50** |
