---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: advanced health features
status: draft
created: 2026-04-26
---

# Advanced Health Features Build Guide — HLTH Smartband

## Executive Summary

Five advanced features to add to the HLTH smartband, all using existing sensors (PPG + SpO2 + accelerometer + gyroscope). Ordered by implementation readiness — fall detection and mental wellness are the most mature; menstrual cycle tracking is the most proprietary.

| Feature | Build Effort | Maturity | Regulatory |
|---------|-------------|----------|-----------|
| Fall Detection | Low | Proven — Apple ships this | Wellness |
| Mental Wellness Trends | Medium | Research-validated | Wellness |
| Arterial Stiffness / Vascular Age | Medium | Research-validated | Wellness |
| Cardiac Output Trends | Medium | Research — relative trends only | Wellness |
| Menstrual Cycle Tracking | Medium | Proven concept, proprietary algos | Wellness |

No FDA clearance needed for any of these under wellness framing.

---

## 1. Fall Detection

### What It Is
Detects when the user falls, confirms they're not moving afterward, and triggers an alert or emergency call.

### How It Works

A fall has a very specific signature in accelerometer + gyroscope data:

```
NORMAL ACTIVITY:
  Acceleration: ~1g (gravity) with small variations
  
FALL EVENT (happens in <1 second):
  Phase 1: FREE FALL — acceleration drops toward 0g (0.3-0.5 seconds)
  Phase 2: IMPACT — sudden spike to 3-8g+ 
  Phase 3: POST-FALL — either movement resumes (caught themselves)
                        or stillness (lying on ground = emergency)
```

### The Algorithm

```python
import numpy as np

def detect_fall(accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z, sampling_rate):
    """
    Fall detection from wrist-worn IMU.
    Input: 3-axis accelerometer + 3-axis gyroscope time series
    Output: (fall_detected, severity, timestamp)
    """
    # Calculate acceleration magnitude
    accel_mag = np.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
    
    # Calculate angular velocity magnitude (rotation speed)
    gyro_mag = np.sqrt(gyro_x**2 + gyro_y**2 + gyro_z**2)
    
    # PHASE 1: Detect free-fall (acceleration drops below threshold)
    freefall_threshold = 0.4  # g (near-weightlessness)
    freefall_detected = accel_mag < freefall_threshold
    
    # PHASE 2: Detect impact (acceleration spike after free-fall)
    impact_threshold = 3.0  # g (hard impact)
    window_after_freefall = int(0.5 * sampling_rate)  # 0.5 seconds
    
    fall_candidates = []
    for i in range(len(accel_mag)):
        if freefall_detected[i]:
            # Look for impact spike within next 0.5 seconds
            window_end = min(i + window_after_freefall, len(accel_mag))
            impact_window = accel_mag[i:window_end]
            
            if np.max(impact_window) > impact_threshold:
                impact_time = i + np.argmax(impact_window)
                fall_candidates.append(impact_time)
    
    if not fall_candidates:
        return False, None, None
    
    # PHASE 3: Check post-fall immobility
    for impact_time in fall_candidates:
        # Check 10 seconds after impact for stillness
        post_window_start = impact_time
        post_window_end = min(impact_time + int(10 * sampling_rate), len(accel_mag))
        post_impact = accel_mag[post_window_start:post_window_end]
        
        # Standard deviation of acceleration — low = not moving
        post_impact_variability = np.std(post_impact)
        
        if post_impact_variability < 0.1:  # very still after impact
            return True, "severe", impact_time / sampling_rate
        elif post_impact_variability < 0.3:  # minimal movement
            return True, "moderate", impact_time / sampling_rate
    
    return False, None, None


def fall_alert_pipeline(fall_detected, severity):
    """
    Post-detection UX flow.
    """
    if not fall_detected:
        return
    
    if severity == "severe":
        # User hasn't moved for 10+ seconds after hard impact
        # Step 1: Vibrate band + loud alert on phone
        # Step 2: 30-second countdown on screen
        #         "It looks like you've fallen. Tap to cancel."
        # Step 3: If no response → call emergency contact
        #         Send GPS location via SMS
        pass
    
    elif severity == "moderate":
        # User moved slightly but may be hurt
        # Step 1: Vibrate band
        # Step 2: Phone notification
        #         "Did you fall? Tap 'I'm OK' or we'll check on you in 60 seconds"
        pass
```

### ML Approach (Higher Accuracy)

```
STEP 1: Sliding window (1-2 seconds) over accelerometer + gyroscope
STEP 2: Extract features per window:
  - Peak acceleration magnitude
  - Minimum acceleration (freefall depth)
  - Angular velocity at impact
  - Post-impact variance
  - Jerk (rate of acceleration change)
  - Orientation change (pre vs post impact)
STEP 3: Classify: SVM (~90% accuracy) or LSTM (~95% accuracy)
```

### Free Datasets

| Dataset | Contents | Size |
|---------|----------|------|
| **SisFall** | 19 subjects, 15 fall types + 19 daily activities | Open access — https://github.com/sismovil/SisFall |
| **UniMiB SHAR** | Smartphone + smartwatch activity recognition including falls | ~15,000 samples — http://www.sal.disco.unimib.it/technologies/unimib-shar/ |
| **MobiFall** | Mobile device fall detection dataset | Multiple fall scenarios — https://bmi.hmu.gr/the-mobifall-and-mobiact-datasets-2/ |

### Free Tools
- **scikit-learn**: SVM / Random Forest classifiers — https://scikit-learn.org
- **TensorFlow Lite**: On-device CNN/LSTM models — https://www.tensorflow.org/lite
- **scipy.signal**: Bandpass filtering (0.5-25 Hz for fall events) — https://scipy.org

### Build Effort: Low
This is the most mature algorithm on this list. Well-documented, multiple public datasets, simple threshold-based approach works well. Ship in 1-2 weeks.

---

## 2. Mental Wellness Trends

### What It Is
A daily "mental wellness" insight based on HRV patterns, sleep quality, activity levels, and circadian rhythm consistency. NOT a depression/anxiety diagnosis — a wellness trend indicator.

### The Science

Depression and anxiety produce measurable physiological changes:

| Signal | What Happens | Detectable By |
|--------|-------------|---------------|
| **HRV** | Chronically suppressed (low RMSSD, low HF power) | PPG |
| **Resting HR** | Elevated above personal baseline | PPG |
| **Sleep architecture** | Less deep sleep, more awakenings, irregular timing | PPG + Accelerometer |
| **Activity patterns** | Reduced movement, less variability in daily activity | Accelerometer |
| **Circadian rhythm** | Irregular sleep/wake times, shifted sleep onset | Accelerometer |
| **Social rhythm** | Less going out, more sedentary time | Accelerometer |

None of these alone means anything. Together, over 7-14 days, they form a pattern.

### The Algorithm

```python
import numpy as np

def calculate_mental_wellness_score(
    # 7-day rolling metrics
    rmssd_7day,           # list of 7 daily RMSSD values
    rmssd_baseline_30d,   # 30-day RMSSD baseline
    rhr_7day,             # list of 7 daily resting HR values
    rhr_baseline_30d,
    deep_sleep_pct_7day,  # list of 7 daily deep sleep %
    sleep_efficiency_7day,
    bedtime_variability,  # std dev of bedtime over 7 days (minutes)
    daily_steps_7day,     # list of 7 daily step counts
    steps_baseline_30d,
    active_minutes_7day   # list of 7 daily active minutes
):
    """
    Mental wellness trend score (0-100).
    Uses 7-day window compared against 30-day personal baseline.
    Higher = better mental wellness indicators.
    """
    
    # 1. HRV TREND (30% weight)
    # Chronic HRV suppression = autonomic stress
    avg_rmssd = np.mean(rmssd_7day)
    hrv_ratio = avg_rmssd / rmssd_baseline_30d
    # Below 0.85 = suppressed, above 1.0 = good
    hrv_score = np.clip((hrv_ratio - 0.7) / 0.6 * 100, 0, 100)
    
    # 2. RESTING HR TREND (15% weight)
    # Elevated RHR over baseline = physiological stress
    avg_rhr = np.mean(rhr_7day)
    rhr_deviation = rhr_baseline_30d - avg_rhr  # positive = lower than baseline = good
    rhr_score = np.clip(50 + (rhr_deviation * 10), 0, 100)
    
    # 3. SLEEP QUALITY (25% weight)
    # Poor sleep architecture = mental health impact
    avg_deep = np.mean(deep_sleep_pct_7day)
    avg_efficiency = np.mean(sleep_efficiency_7day)
    
    deep_score = np.clip(avg_deep / 25 * 100, 0, 100)  # 25% deep sleep = 100
    efficiency_score = np.clip((avg_efficiency - 70) / 25 * 100, 0, 100)  # 95% = 100
    
    # Bedtime consistency (irregular = worse)
    consistency_score = np.clip((60 - bedtime_variability) / 60 * 100, 0, 100)  # <60 min variability = good
    
    sleep_score = (deep_score * 0.3 + efficiency_score * 0.4 + consistency_score * 0.3)
    
    # 4. ACTIVITY PATTERNS (20% weight)
    # Reduced activity + low variability = withdrawal pattern
    avg_steps = np.mean(daily_steps_7day)
    steps_ratio = avg_steps / steps_baseline_30d
    activity_score = np.clip(steps_ratio * 80, 0, 100)  # at baseline = 80, above = bonus
    
    # Activity variability (doing different things = engagement)
    step_variability = np.std(daily_steps_7day) / (np.mean(daily_steps_7day) + 1)
    variability_bonus = np.clip(step_variability * 50, 0, 20)
    activity_score = np.clip(activity_score + variability_bonus, 0, 100)
    
    # 5. CIRCADIAN REGULARITY (10% weight)
    # Irregular rhythms correlate with mood disorders
    circadian_score = consistency_score  # reuse bedtime consistency
    
    # WEIGHTED COMPOSITE
    wellness_score = (
        0.30 * hrv_score +
        0.15 * rhr_score +
        0.25 * sleep_score +
        0.20 * activity_score +
        0.10 * circadian_score
    )
    
    return round(np.clip(wellness_score, 0, 100))


def wellness_insight(score, previous_7day_score):
    """
    Generate human-readable insight.
    Never diagnose. Always frame as trends and suggestions.
    """
    trend = score - previous_7day_score
    
    if score >= 70:
        status = "Your body signals look balanced this week."
    elif score >= 45:
        status = "Some of your wellness indicators have shifted this week."
    else:
        status = "Your body has been showing signs of elevated stress."
    
    suggestions = []
    # Add specific, actionable suggestions based on which sub-scores are low
    # "Your sleep timing has been inconsistent — try a regular bedtime"
    # "Your activity has been lower than usual — even a short walk can help"
    # "Your heart rate variability is below your baseline — consider a rest day"
    
    return status, suggestions
```

### What This Is NOT
- Not a depression diagnosis
- Not an anxiety detector
- Not a mental health screening tool
- It's a **"body stress and balance"** wellness trend

### Safe Framing for the App
- "Wellness Balance" or "Body Harmony Score"
- "Your body signals suggest elevated stress this week"
- "Trend: your sleep consistency and activity have improved"
- Never use words: depression, anxiety, mental illness, diagnosis

### Free Datasets
| Dataset | Contents | Link |
|---------|----------|------|
| **WESAD** | Wearable stress and affect detection — HRV + accelerometer + labeled stress/baseline | https://archive.ics.uci.edu/dataset/465/wesad+wearable+stress+and+affect+detection |
| **TILES** (USC) | Multimodal wearable data with stress/mood labels from smartwatches | https://tiles-data.isi.edu |
| **SWELL-KW** | Stress detection in knowledge workers — HRV + activity | https://www.kaggle.com/datasets/qiriro/swell-heart-rate-variability-hrv |

### Free Tools
- **hrvanalysis**: https://github.com/Aura-healthcare/hrv-analysis — production HRV features
- **NeuroKit2**: https://github.com/neuropsychology/NeuroKit — PPG processing + HRV + stress index computation
- **scikit-learn**: https://scikit-learn.org — Isolation Forest for anomaly detection on wellness metrics

### Build Effort: Medium
The algorithm itself is straightforward (composite score from existing metrics). The hard part is tuning the weights and making the insights feel helpful rather than alarming. Start with the formula above, iterate based on user feedback.

---

## 3. Arterial Stiffness / Vascular Age

### What It Is
A measure of how stiff or elastic your arteries are. Stiffer arteries = aging cardiovascular system. This feeds directly into the longevity/body age score as the cardiovascular sub-score.

### How PPG Detects It

Every PPG pulse has a specific shape that changes as arteries stiffen:

```
YOUNG / ELASTIC ARTERIES:
    ╱╲
   ╱  ╲
  ╱    ╲_╱╲    ← clear dicrotic notch (reflected wave is separate)
 ╱         ╲
  
OLD / STIFF ARTERIES:
    ╱╲
   ╱  ╲╱╲      ← reflected wave merges with systolic peak
  ╱       ╲    ← augmented systolic peak (wave comes back faster)
 ╱          ╲
```

Stiff arteries make the pulse wave travel faster, so the reflected wave arrives earlier and merges with the primary wave. This changes three measurable things:

### Three Metrics from One PPG Waveform

#### 1. Stiffness Index (SI)

```python
def calculate_stiffness_index(ppg_pulse, sampling_rate, subject_height_m):
    """
    Stiffness Index = subject height / time between systolic peak and diastolic peak.
    Units: m/s (like pulse wave velocity).
    Higher = stiffer arteries = older vascular age.
    
    Normal ranges:
      Age 20-30: ~6-7 m/s
      Age 40-50: ~8-9 m/s
      Age 60-70: ~10-12 m/s
      Age 80+:   ~12-15 m/s
    """
    # Find systolic peak (highest point)
    systolic_peak_idx = np.argmax(ppg_pulse)
    
    # Find diastolic peak (second peak / inflection point after systolic)
    # Search in the descending part of the pulse
    search_start = systolic_peak_idx + int(0.1 * sampling_rate)  # at least 100ms after
    search_end = min(systolic_peak_idx + int(0.5 * sampling_rate), len(ppg_pulse))
    
    descending = ppg_pulse[search_start:search_end]
    
    # Find second derivative zero crossing (inflection point) or local max
    second_deriv = np.diff(np.diff(descending))
    zero_crossings = np.where(np.diff(np.sign(second_deriv)))[0]
    
    if len(zero_crossings) > 0:
        diastolic_peak_idx = search_start + zero_crossings[0]
    else:
        # Fallback: use first derivative minimum (steepest descent point)
        first_deriv = np.diff(descending)
        diastolic_peak_idx = search_start + np.argmin(first_deriv)
    
    # Time between peaks
    delta_t = (diastolic_peak_idx - systolic_peak_idx) / sampling_rate  # seconds
    
    # Stiffness Index
    if delta_t > 0:
        si = subject_height_m / delta_t  # m/s
    else:
        si = None  # invalid pulse
    
    return si
```

#### 2. Augmentation Index (AIx)

```python
def calculate_augmentation_index(ppg_pulse, sampling_rate):
    """
    Augmentation Index = (P2 - P1) / pulse_pressure × 100
    Where P1 = first systolic shoulder, P2 = systolic peak
    
    Higher AIx = more wave reflection = stiffer arteries.
    
    Normal ranges:
      Age 20-30: ~5-10%
      Age 40-50: ~15-25%
      Age 60-70: ~25-35%
    """
    # Find systolic peak
    systolic_peak = np.max(ppg_pulse)
    systolic_idx = np.argmax(ppg_pulse)
    
    # Find first systolic shoulder (inflection point on upstroke)
    upstroke = ppg_pulse[:systolic_idx]
    second_deriv = np.diff(np.diff(upstroke))
    
    # First inflection on upstroke = P1
    inflection_points = np.where(np.diff(np.sign(second_deriv)))[0]
    
    if len(inflection_points) > 0:
        p1_idx = inflection_points[-1]  # last inflection before peak
        p1 = ppg_pulse[p1_idx]
    else:
        p1 = ppg_pulse[systolic_idx - int(0.05 * sampling_rate)]  # fallback
    
    # Pulse pressure
    diastolic = np.min(ppg_pulse)
    pulse_pressure = systolic_peak - diastolic
    
    # Augmentation
    augmentation = systolic_peak - p1
    
    if pulse_pressure > 0:
        aix = (augmentation / pulse_pressure) * 100  # percentage
    else:
        aix = None
    
    return aix
```

#### 3. Vascular Age Mapping

```python
def estimate_vascular_age(stiffness_index, augmentation_index, resting_bp_systolic=None):
    """
    Map arterial stiffness metrics to estimated vascular age.
    Uses published normative tables.
    """
    # SI-based vascular age (primary)
    # Linear interpolation from normative data
    si_age_table = [
        (5.0, 15), (6.0, 20), (6.5, 25), (7.0, 30), (7.5, 35),
        (8.0, 40), (8.5, 45), (9.0, 50), (9.5, 55), (10.0, 60),
        (11.0, 65), (12.0, 70), (13.0, 75), (14.0, 80), (15.0, 85)
    ]
    
    si_age = np.interp(stiffness_index,
                       [x[0] for x in si_age_table],
                       [x[1] for x in si_age_table])
    
    # AIx-based vascular age (secondary)
    aix_age_table = [
        (0, 15), (5, 20), (10, 30), (15, 35), (20, 45),
        (25, 50), (30, 60), (35, 65), (40, 75)
    ]
    
    aix_age = np.interp(augmentation_index,
                        [x[0] for x in aix_age_table],
                        [x[1] for x in aix_age_table])
    
    # Weighted combination
    vascular_age = (si_age * 0.6) + (aix_age * 0.4)
    
    # Optional: incorporate blood pressure if available
    if resting_bp_systolic:
        bp_offset = (resting_bp_systolic - 120) * 0.3  # each 10mmHg above 120 = ~3 years
        vascular_age += bp_offset
    
    return round(vascular_age, 1)
```

### Feature Extraction Tool
**PhysioZoo PPG** (https://github.com/physiozoo/PhysioZoo): Automated fiducial point detection + stiffness index + augmentation index extraction from PPG waveforms. Handles the hard part (finding pulse landmarks).

### Integration with Longevity Score
This becomes the **cardiovascular sub-score** in your body age calculation. Replace the rule-based BP lookup with actual arterial stiffness measurement — much more accurate and meaningful.

### Free Datasets
- **UK Biobank PPG**: 205,000+ participants with single-finger PPG + age + BP — https://biobank.ndph.ox.ac.uk/ukb/exinfo.cgi (requires research application)
- **PulseDB**: 5,361 subjects with PPG + demographics — https://www.frontiersin.org/articles/10.3389/fdgth.2022.1090854/full
- **MIMIC-III**: ICU PPG with patient ages for validation — https://physionet.org/content/mimiciii/
- **PhysioNet PPG datasets index**: https://physionet.org/about/database/

### Build Effort: Medium
The math is well-defined (stiffness index and augmentation index are published formulas). The challenge is reliable fiducial point detection from noisy wrist PPG — PhysioZoo handles this. Average over many pulses (30+ seconds) to reduce noise.

---

## 4. Cardiac Output Trends

### What It Is
An estimate of how much blood your heart pumps per minute, tracked as a trend over weeks and months. Shows whether the heart is becoming more or less efficient.

### How PPG Estimates It

```
Cardiac Output = Stroke Volume × Heart Rate

Stroke Volume ∝ Area under the PPG systolic waveform
```

The area under the systolic portion of each PPG pulse correlates with the volume of blood ejected per beat. More blood per beat = larger pulse area.

### The Algorithm

```python
import numpy as np
from scipy.signal import find_peaks

def estimate_relative_stroke_volume(ppg_signal, sampling_rate):
    """
    Estimates RELATIVE stroke volume from PPG pulse area.
    NOT absolute mL — use for trends only.
    
    Returns: relative stroke volume index (arbitrary units)
    """
    # Find individual pulse peaks
    peaks, _ = find_peaks(ppg_signal, distance=int(0.5 * sampling_rate), height=0)
    
    # Find pulse onsets (troughs before each peak)
    troughs = []
    for peak in peaks:
        search_start = max(0, peak - int(0.4 * sampling_rate))
        segment = ppg_signal[search_start:peak]
        if len(segment) > 0:
            trough_idx = search_start + np.argmin(segment)
            troughs.append(trough_idx)
    
    if len(troughs) < 2:
        return None
    
    # Calculate systolic area for each pulse
    pulse_areas = []
    for i in range(len(troughs) - 1):
        onset = troughs[i]
        peak = peaks[i] if i < len(peaks) else None
        
        if peak is None or peak <= onset:
            continue
        
        # Systolic area = area under curve from onset to peak
        # Subtract baseline (straight line from onset)
        pulse_segment = ppg_signal[onset:peak + 1]
        baseline = np.linspace(pulse_segment[0], pulse_segment[0], len(pulse_segment))
        area = np.trapz(pulse_segment - baseline) / sampling_rate
        
        if area > 0:
            pulse_areas.append(area)
    
    if not pulse_areas:
        return None
    
    # Average pulse area = relative stroke volume index
    return np.median(pulse_areas)


def estimate_cardiac_output_trend(ppg_signal, heart_rate, sampling_rate):
    """
    Relative cardiac output = relative SV × HR.
    Track this value daily at rest for trends.
    """
    sv_index = estimate_relative_stroke_volume(ppg_signal, sampling_rate)
    
    if sv_index is None:
        return None
    
    # Relative cardiac output (arbitrary units)
    co_index = sv_index * heart_rate
    
    return {
        'stroke_volume_index': sv_index,
        'heart_rate': heart_rate,
        'cardiac_output_index': co_index
    }


def cardiac_efficiency_score(sv_index_today, sv_baseline_30d, rhr_today, rhr_baseline_30d):
    """
    Heart efficiency = getting more blood per beat at a lower heart rate.
    Higher stroke volume + lower resting HR = more efficient heart.
    """
    sv_improvement = (sv_index_today - sv_baseline_30d) / sv_baseline_30d
    hr_improvement = (rhr_baseline_30d - rhr_today) / rhr_baseline_30d
    
    # Both improving = great, both declining = concerning
    efficiency_trend = (sv_improvement + hr_improvement) / 2
    
    return efficiency_trend  # positive = improving, negative = declining
```

### What to Show the User

```
"Heart Efficiency"

Your heart is pumping more blood per beat this month
compared to last month — a sign of improving fitness.

Stroke Volume Trend:  ↑ 8% (30 days)
Resting Heart Rate:   ↓ 3 bpm (30 days)

Your heart is doing more work with less effort.
```

### Important Caveats
- **Never show absolute numbers** (mL or L/min) — PPG can't measure these accurately
- **Only show trends** — "improving," "stable," or "declining" over 7-30 day windows
- **Measure at rest only** — morning resting readings give cleanest signal
- **Average over 30+ seconds** of clean PPG per reading to reduce noise
- **±15-30% error** on absolute values, but trends are reliable

### Free Tools
- **BioSPPy**: https://github.com/PIA-Group/BioSPPy — PPG signal processing, pulse detection
- **pyPPG**: https://pypi.org/project/pyPPG/ — Pulse wave analysis, fiducial point detection
- **NeuroKit2**: https://github.com/neuropsychology/NeuroKit — PPG processing pipeline
- **PhysioZoo PPG**: https://github.com/physiozoo/PhysioZoo — Fiducial points + morphological biomarkers (same tool as arterial stiffness section)

### Build Effort: Medium
The pulse area calculation is straightforward. The challenge is consistent measurement conditions — must be at rest, same time of day, clean signal. The trend smoothing (30-day rolling) handles day-to-day noise.

---

## 5. Menstrual Cycle Tracking

### What It Is
Predicts cycle phase (follicular, ovulation window, luteal, menstruation) from resting heart rate and HRV patterns — without any manual logging after initial setup.

### The Science

The menstrual cycle produces measurable cardiovascular changes:

```
FOLLICULAR PHASE (Day 1-14):
  - Resting HR: lower (baseline)
  - HRV (RMSSD): higher (more parasympathetic)
  - Body temp: lower
  
OVULATION (~Day 14):
  - RHR begins rising (~1-2 bpm)
  - HRV begins dropping
  
LUTEAL PHASE (Day 14-28):
  - Resting HR: elevated ~2-3 bpm above follicular baseline
  - HRV (RMSSD): suppressed ~10-15%
  - Body temp: elevated ~0.3-0.5°C
  
MENSTRUATION:
  - RHR drops back to baseline
  - HRV recovers
```

### The Algorithm

```python
import numpy as np
from scipy.signal import savgol_filter

def detect_cycle_phase(
    daily_rhr,          # list of daily resting HR values (30+ days)
    daily_rmssd,        # list of daily RMSSD values (30+ days)
    last_period_start,  # date of last known period start (user input)
    typical_cycle_length=28  # user's typical cycle length (default 28)
):
    """
    Menstrual cycle phase detection from HR + HRV patterns.
    
    Requires: initial user input of last period date + typical cycle length.
    After 2-3 cycles of data, can predict independently.
    
    Returns: current phase, confidence, predicted next period
    """
    if len(daily_rhr) < 14:
        return None, 0, None  # need at least 2 weeks of data
    
    # Smooth daily values (reduce noise)
    rhr_smooth = savgol_filter(daily_rhr, window_length=7, polyorder=2)
    rmssd_smooth = savgol_filter(daily_rmssd, window_length=7, polyorder=2)
    
    # Calculate personal baselines
    rhr_baseline = np.percentile(rhr_smooth, 25)  # lower quartile = follicular baseline
    rhr_elevated = np.percentile(rhr_smooth, 75)   # upper quartile = luteal level
    
    rmssd_baseline = np.percentile(rmssd_smooth, 75)  # higher = follicular
    rmssd_suppressed = np.percentile(rmssd_smooth, 25) # lower = luteal
    
    # Current values
    current_rhr = rhr_smooth[-1]
    current_rmssd = rmssd_smooth[-1]
    
    # RHR trend (last 5 days)
    rhr_trend = np.polyfit(range(5), rhr_smooth[-5:], 1)[0]  # slope
    
    # Phase detection logic
    rhr_is_low = current_rhr < (rhr_baseline + (rhr_elevated - rhr_baseline) * 0.3)
    rhr_is_high = current_rhr > (rhr_baseline + (rhr_elevated - rhr_baseline) * 0.7)
    rhr_is_rising = rhr_trend > 0.2  # bpm per day
    rhr_is_falling = rhr_trend < -0.2
    
    rmssd_is_high = current_rmssd > (rmssd_suppressed + (rmssd_baseline - rmssd_suppressed) * 0.7)
    rmssd_is_low = current_rmssd < (rmssd_suppressed + (rmssd_baseline - rmssd_suppressed) * 0.3)
    
    # Phase classification
    if rhr_is_low and rmssd_is_high:
        phase = "follicular"
        confidence = 0.8
    elif rhr_is_rising and not rhr_is_high:
        phase = "ovulation_window"
        confidence = 0.5  # hardest to pinpoint
    elif rhr_is_high and rmssd_is_low:
        phase = "luteal"
        confidence = 0.7
    elif rhr_is_falling and rhr_is_low:
        phase = "menstruation"
        confidence = 0.6
    else:
        phase = "transitional"
        confidence = 0.3
    
    # Predicted next period (simple calendar + RHR confirmation)
    from datetime import datetime, timedelta
    days_since_last = (datetime.now() - last_period_start).days
    days_remaining = typical_cycle_length - (days_since_last % typical_cycle_length)
    predicted_next = datetime.now() + timedelta(days=days_remaining)
    
    return phase, confidence, predicted_next


def cycle_insight(phase, confidence):
    """
    User-facing insight. Never claim medical-grade fertility tracking.
    """
    insights = {
        "follicular": {
            "label": "Follicular Phase",
            "description": "Your body signals suggest you're in the first half of your cycle. Energy and recovery tend to be higher during this phase.",
            "suggestion": "Great time for high-intensity workouts"
        },
        "ovulation_window": {
            "label": "Mid-Cycle",
            "description": "Your resting heart rate is beginning to shift, suggesting mid-cycle transition.",
            "suggestion": "Peak energy window for most people"
        },
        "luteal": {
            "label": "Luteal Phase", 
            "description": "Your resting heart rate is elevated and HRV is lower than your baseline — typical for the second half of the cycle.",
            "suggestion": "Your body may benefit from moderate activity and extra sleep"
        },
        "menstruation": {
            "label": "Menstrual Phase",
            "description": "Your vitals are returning to baseline, consistent with the start of a new cycle.",
            "suggestion": "Listen to your body — rest if needed, gentle movement is beneficial"
        }
    }
    
    return insights.get(phase, {"label": "Tracking", "description": "Collecting more data to identify your pattern."})
```

### User Onboarding

1. User enters: date of last period + typical cycle length
2. Band starts collecting daily resting HR + HRV
3. After 1 cycle (~28 days): basic phase detection begins
4. After 2-3 cycles: algorithm calibrates to user's personal patterns
5. Eventually: predict upcoming period ±2-3 days accuracy

### What This Is NOT
- Not an ovulation predictor (not accurate enough for fertility planning)
- Not a pregnancy test
- Not a contraception tool
- It's a **cycle-aware wellness feature** that contextualizes other metrics

### Why It Matters
Recovery scores, sleep quality, and activity patterns all shift across the cycle. Knowing the phase means the app can say "your HRV is lower this week, but that's normal for your cycle phase" instead of flagging a false alarm.

### Free Datasets and References
- No open datasets with raw PPG + cycle labels exist publicly — build from your own user base (opt-in) after shipping with manual period logging
- **Natural Cycles algorithm paper**: Symul et al., Science Advances (2021) — Kalman filtering on RHR + LH surge — https://www.science.org/doi/10.1126/sciadv.abf3686
- **Oura cycle tracking methodology**: https://ouraring.com/blog/period-prediction
- **Apple Women's Health Study**: Ongoing — data restricted but methodology published
- **Clue app research**: Published cycle data patterns but raw data not released — https://helloclue.com/articles/cycle-a-z/the-cycle-science-behind-clue
- **HRV + menstrual cycle review**: Qian et al. — physiological basis for cycle detection from wearables

### Build Effort: Medium
The algorithm is implementable (above), but accuracy improves significantly with 2-3 months of per-user data. Ship with manual period logging first, then graduate to prediction as the algorithm learns each user's pattern.

---

## Integration with Existing Features

### How These Connect to Your Longevity Score

| New Feature | Longevity Score Impact |
|-------------|----------------------|
| **Arterial Stiffness** | Replaces rule-based cardiovascular sub-score with actual vascular measurement |
| **Cardiac Output Trends** | Enhances fitness sub-score with heart efficiency data |
| **Mental Wellness** | New sub-score: "Mental Balance" — or weights into recovery |
| **Fall Detection** | Safety feature, doesn't feed into longevity math |
| **Menstrual Cycle** | Contextualizes all other scores — "adjusted for cycle phase" |

### Menstrual Cycle as Context Layer

This is subtle but powerful. When the user is in luteal phase:
- Recovery score adjusts expectations (lower HRV is normal)
- Wellness score doesn't flag the cyclical HRV dip as concerning
- Sleep insights account for expected disruption
- Activity recommendations soften appropriately

Without cycle awareness, the app would generate false "your recovery is declining" alerts for ~2 weeks every month for half your users.

---

## Priority Order

| # | Feature | Ship Timeline | Why This Order |
|---|---------|---------------|----------------|
| 1 | **Fall Detection** | 1-2 weeks | Simplest, most mature, immediate safety value |
| 2 | **Arterial Stiffness / Vascular Age** | 2-3 weeks | Directly upgrades longevity score |
| 3 | **Mental Wellness Trends** | 3-4 weeks | High engagement for ADHD audience |
| 4 | **Cardiac Output Trends** | 3-4 weeks | Parallel with mental wellness |
| 5 | **Menstrual Cycle Tracking** | 4-6 weeks | Needs onboarding flow + 1 cycle of data before useful |

---

## Cost Summary

| Item | Cost |
|------|------|
| Datasets (SisFall, WESAD, UK Biobank, PulseDB) | Free |
| Libraries (hrvanalysis, NeuroKit2, scikit-learn, scipy) | Free |
| Algorithm code | All provided above or in linked repos |
| New sensors required | None |
| FDA submission | $0 (all wellness features) |
| **Total** | **$0** |
