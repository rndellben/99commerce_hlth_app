---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: sleep apnea detection
status: draft
created: 2026-04-26
---

# Sleep Apnea Detection Build Guide — HLTH Smartband

## Executive Summary

We're building a sleep breathing disruption detection feature for the HLTH smartband using entirely free, open-source tools and publicly available datasets. No licensing fees. No FDA submission required. No clinical validation study needed — as long as we label it **"breathing disruption notification"** and make **zero sleep apnea medical claims**.

The pipeline uses the PPG sensor (for SpO2 and heart rate variability), accelerometer (for breathing movement patterns and pauses), and gyroscope (for sleep position tracking) — all already inside the band. Unlike the afib feature where accelerometer/gyroscope only clean noise, here they are **active detection sensors** for breathing patterns and body position.

Total out-of-pocket cost: effectively **$0**. Just engineering time.

---

## What We're Building

A software pipeline that:

1. Detects when the user is asleep (sleep staging from PPG)
2. Monitors SpO2 for oxygen desaturation events during sleep
3. Tracks breathing movement patterns via accelerometer for pauses
4. Identifies body position via gyroscope (supine = higher risk)
5. Correlates SpO2 drops + HRV spikes + breathing pauses into disruption events
6. Counts events per hour to estimate a disruption index
7. Fires a notification: **"Frequent breathing disruptions detected during sleep — consider consulting a doctor"**

**What we are NOT doing:**
- No "sleep apnea" claims (that requires FDA De Novo or 510(k) clearance)
- No Apnea-Hypopnea Index (AHI) medical scoring claims
- No medical device classification
- No clinical trials
- No licensed SDKs or third-party algorithm fees

---

## Regulatory Position

| Approach | Regulatory Requirement | Example |
|----------|----------------------|---------|
| "Breathing disruption notifications" | **None** — wellness feature | What we're doing |
| "Sleep apnea detection" | FDA Class II — De Novo or 510(k) | Samsung Galaxy Watch |

By avoiding the terms "sleep apnea," "apnea-hypopnea index," and "AHI" in all user-facing copy, marketing, and app UI, we sidestep FDA medical device classification entirely. The feature is positioned as a wellness notification, not a diagnostic tool.

---

## How It Differs from AFib Detection

| | AFib Feature | Sleep Apnea Feature |
|--|-------------|---------------------|
| Primary signal | R-R interval irregularity | SpO2 drops + breathing pauses |
| Secondary signals | PPG morphology | HRV changes, body position |
| Accelerometer role | Noise removal only | **Active detection** — breathing patterns |
| Gyroscope role | Noise removal only | **Active detection** — sleep position |
| Detection window | Anytime (best at rest) | Sleep hours only |
| Needs sleep staging? | No | Yes — stages improve accuracy |
| Signal quality | Best at night (~94% clean) | Night-only by design |

The accelerometer and gyroscope do more work here. They are primary detection sensors, not just noise filters.

---

## Architecture

```
LAYER 1: HARDWARE (already exists)
  PPG optical sensor → raw pulse waveform + SpO2 readings
  Accelerometer → 3-axis breathing movement + vibration data
  Gyroscope → rotational data for body position
      ↓ BLE to companion app

LAYER 2: SLEEP STAGING (PPG-based)
  Classify epochs into: Wake / NREM / REM
  Uses PPG waveform + HRV features
  Tools: YASA library or SleepPPG-Net model
  Accuracy: ~83% from PPG alone (κ=0.745)
      ↓ sleep state per 30-sec epoch

LAYER 3: SIGNAL PROCESSING (during sleep epochs only)
  PPG → bandpass filter 0.5–5 Hz, SpO2 extraction
  Accelerometer → breathing rate estimation, pause detection
  Gyroscope → body position classification (supine/lateral/prone)
  Motion artifact removal (same methods as afib pipeline)
      ↓ clean signals + derived metrics

LAYER 4: EVENT DETECTION
  SpO2 desaturation: drop ≥3–4% from rolling baseline
  HRV anomaly: sympathetic spike pattern (LF/HF ratio shift)
  Breathing pause: accelerometer flat-line >10 seconds
  Correlate all three → candidate disruption event
      ↓ timestamped events with confidence scores

LAYER 5: SCORING
  Count events per hour = estimated disruption index
  Clinical reference ranges (internal only, not shown to user):
    Mild: 5–15 events/hr
    Moderate: 15–30 events/hr
    Severe: 30+ events/hr
      ↓ nightly disruption score

LAYER 6: DECISION LOGIC + NOTIFICATION
  Single night ≠ alert
  Require consistent pattern across 2+ nights
  Confidence threshold before notifying
  Show trend graph: disruptions per night over time
      ↓ push notification or in-app insight
```

---

## Sensor Roles — Detailed Breakdown

### PPG Sensor (Optical)
- **SpO2 monitoring**: Oxygen saturation drops during apnea events. A ≥3-4% desaturation from baseline flags a candidate event.
- **Heart rate variability**: Apnea episodes cause characteristic HRV pattern — sympathetic nervous system spike (increased LF power) followed by parasympathetic recovery. Detectable via pyHRV.
- **Heart rate**: Bradycardia-tachycardia cycling during apnea (heart rate drops during the pause, spikes when breathing resumes).
- **Sleep staging**: Raw PPG waveform feeds into sleep staging model to determine Wake/NREM/REM.

### Accelerometer (3-axis)
- **Breathing rate estimation**: Chest/wrist micro-movements from breathing create a low-frequency signal (~0.15–0.5 Hz). Adaptive peak detection algorithms extract respiration rate with <2 breaths/min error for 83.6% of epochs.
- **Breathing pause detection**: Flat-line or dramatic amplitude drop in the breathing movement signal for >10 seconds = candidate apnea event.
- **Movement tracking**: Distinguish sleep from wake. High movement = awake. Micro-movements only = asleep.

### Gyroscope (Rotational)
- **Sleep position classification**: Supine (on back) vs lateral (on side) vs prone (face down). Supine position dramatically increases apnea severity.
- **Position change events**: Frequent position changes may indicate restless sleep from breathing disruptions.
- **Accuracy**: Studies show accelerometer + gyroscope distinguish supine vs left/right with AUC of 0.87–0.94.

---

## Free Datasets for Training

All publicly available. No licensing.

### Sleep Apnea Specific

| Dataset | Source | Contents | Size |
|---------|--------|----------|------|
| **Apnea-ECG Database** | PhysioNet/MIT | ECG + SpO2 + respiratory effort, expert-labeled apnea events | 70 recordings, 7–10 hrs each |
| **Sleep Heart Health Study (SHHS)** | PhysioNet/NSRR | Full PSG: EEG, ECG, PPG, SpO2, airflow, respiratory effort | 8,000+ overnight recordings |
| **MIT-BIH Polysomnographic** | PhysioNet/MIT | Multi-channel PSG with sleep staging + apnea annotations | 80+ hours, 18 records |
| **St. Vincent's University Hospital** | PhysioNet | ECG + SpO2 with apnea labels | Clinical recordings |

### Sleep Staging + General Sleep

| Dataset | Source | Contents | Size |
|---------|--------|----------|------|
| **MESA** | PhysioNet/NSRR | PPG + ECG + EEG + respiration, multi-ethnic cohort | Large-scale PSG |
| **Sleep-EDF** | PhysioNet | PSG from healthy subjects, European Data Format | Benchmark standard |
| **Wearanize+** | Public | 130 subjects — wristband + headband + PSG simultaneously | Wearable-specific validation |
| **VitalDB** | Public | 482 patients, multi-annotator validated | 734K seconds |

### PPG + Motion (Reusable from AFib Pipeline)

| Dataset | Source | Contents | Size |
|---------|--------|----------|------|
| **PulseDB** | Public | ECG + PPG + ABP from 5,361 subjects | 5.2M segments, 14,570 hours |
| **Pulsewatch** | Clinical trial | Smartwatch PPG + accelerometer + ECG reference | 166,904 labeled segments |
| **PPG-DaLiA** | Public | PPG + 3-axis accelerometer during daily living | 15 subjects |
| **BUT PPG** | Brno University | Smartphone PPG + ECG + accelerometer | 3,888 recordings |
| **CapnoBase** | Public | PPG + ECG + respiration signals, high quality | 42 recordings |

**Start with**: Sleep Heart Health Study (largest clinical sleep dataset) + MESA (multi-ethnic diversity) for apnea detection. Use Wearanize+ for wearable-specific validation.

---

## Free Open-Source Libraries

### Shared with AFib Pipeline

| Library | Purpose | Install |
|---------|---------|---------|
| **pyPPG** | PPG processing — filtering, beat detection, SpO2 extraction | `pip install pyPPG` |
| **NeuroKit2** | Multi-signal processing, auto-pipeline, visualization | `pip install neurokit2` |
| **BioSPPy** | Biosignal processing primitives | `pip install biosppy` |
| **pyHRV** | HRV parameter extraction (time + frequency domain) | `pip install pyhrv` |
| **E2E-PPG** | End-to-end: quality → artifact removal → peaks → HRV | GitHub: HealthSciTech/E2E-PPG |

### New — Sleep-Specific

| Library | Purpose | Install |
|---------|---------|---------|
| **YASA** | Sleep staging, spindle/slow-wave detection, sleep analysis toolbox | `pip install yasa` |
| **SLEEPYLAND** | Multi-model automated sleep staging platform (web app included) | GitHub: biomedical-signal-processing/sleepyland |
| **MNE-Python** | PSG data handling, neurophysiological signal processing | `pip install mne` |
| **sleepecg** | ECG-based sleep staging with dataset loaders | `pip install sleepecg` |

---

## Free Algorithm Implementations (GitHub)

### Sleep Apnea Detection

| Repository | Approach | Performance |
|------------|----------|-------------|
| **iobt-vistec/apsense** | Deep learning (ApSense) on fingertip PPG for apnea events | State-of-the-art, outperforms baselines |
| **mahsaabahrami/Sleep-Apnea** | 12 ML models + 4 deep learning architectures (AlexNet, VGG16, LSTM, BiLSTM) | Comprehensive benchmark |
| **ChiQiao/Apnea-ECG** | Heart rate-only apnea detection — wearable compatible | ~80% accuracy |
| **arlenejohn/Sleep_apnea_SpO2** | SpO2-based deep learning with model pruning for smartwatches | On-device optimized |
| **mabartcz/ApnoeDetectRaw** | CNN on airflow + SpO2 numpy arrays | Minimal deps (scipy, numpy, keras) |
| **JackAndCole/Sleep-apnea-detection-through-a-modified-LeNet-5** | LeNet-5 on raw signals, pre-trained model included | Plug-and-play |

### Sleep Staging (Required for Apnea Pipeline)

| Repository | Approach | Performance |
|------------|----------|-------------|
| **DavyWJW/sleep-staging-models** | PPG-based, dual-stream cross-attention | 83.3% accuracy, κ=0.745 on MESA |
| **raphaelvallat/yasa** | Full sleep analysis toolbox — staging, spindles, slow waves | Production-grade |
| **biomedical-signal-processing/sleepyland** | Multi-model platform (YASA + U-Sleep + DeepResNet) | Benchmark-ready |
| **perslev/U-Time** | Resilient high-frequency sleep staging CNN | Cross-dataset generalization |
| **akaraspt/deepsleepnet** | Deep learning automatic sleep scoring | Reference implementation |
| **emadeldeen24/AttnSleep** | Attention-based, multi-resolution CNN + temporal context | State-of-the-art EEG staging |

### PPG Foundation Models (Transfer Learning)

| Repository | What | Scale |
|------------|------|-------|
| **maxxu05/Pulse-PPG** | First open-source PPG foundation model | 21 billion data points, 120 participants |
| **PaPaGei** | PPG foundation model, 57K+ hours pre-training | 20M unlabeled segments |

These foundation models let you fine-tune for sleep apnea detection without training from scratch. Transfer learning from Pulse-PPG is the fastest path to high accuracy on limited labeled data.

---

## Motion Artifact Removal (Same as AFib)

Same four methods apply — the pipeline is shared:

1. **Adaptive Noise Cancellation** — accelerometer as motion reference
2. **Independent Component Analysis (ICA)** — 99% sensitivity walking, 96% fast walking
3. **SpaMA Algorithm** — spectral comparison of PPG vs accelerometer
4. **Deep Learning Artifact Removal** — neural net separation

**Key advantage for sleep apnea**: Detection runs during sleep only. Nighttime PPG achieves ~94% clean signal quality with minimal motion artifacts. This is the easiest detection window for clean data.

---

## Accelerometer-Specific: Breathing Rate Extraction

This is unique to the sleep apnea pipeline (not needed for afib).

**How it works**: When the user breathes, micro-movements propagate to the wrist. The accelerometer picks up a rhythmic low-frequency signal (0.15–0.5 Hz = 9–30 breaths/min).

**Algorithm**: Adaptive peak detection on filtered accelerometer data.
- Published accuracy: Mean absolute error < 2 breaths/min for 83.6% of 30-sec epochs
- Body position classification: AUC 0.87 (supine vs lateral), AUC 0.94 (left vs right)

**Reference paper**: "Estimation of Respiration Rate and Sleeping Position Using Accelerometer Data" — provides the algorithm for both breathing rate and position from a single accelerometer.

---

## Model Selection Recommendations

### For Sleep Staging

| Model | Input | Accuracy | Notes |
|-------|-------|----------|-------|
| **SleepPPG-Net** | Raw PPG | κ=0.75 (4-class) | Best PPG-only staging model |
| **SleepPPG-Net2** (dual-stream) | PPG + augmented PPG | κ=0.745, 83.3% | Improved generalization |
| **YASA** | EEG (or PPG with adaptation) | Production-grade | Full toolbox, not just staging |
| **U-Sleep** | Multi-channel PSG | Resilient across datasets | Overkill for wristband |

**Recommendation**: Start with SleepPPG-Net or the DavyWJW/sleep-staging-models repo. PPG-only input matches our hardware.

### For Apnea Event Detection

| Model | Input | Accuracy | Notes |
|-------|-------|----------|-------|
| **ApSense** | Fingertip PPG | State-of-the-art | Best dedicated apnea model |
| **Random Forest + HRV** | R-R intervals + SpO2 | AUC 0.98 | Simple, interpretable |
| **SpO2 deep learning** | SpO2 time series | 96% accuracy | Lightweight, on-device capable |
| **Heart rate only** | HR from PPG | ~80% | Minimum viable approach |
| **Multimodal (PPG + accel + SpO2)** | All sensors | Best overall | Most complex |

**Recommendation**: Two-tier approach:
1. **Fast screening**: SpO2 desaturation threshold + breathing pause from accelerometer (simple rules)
2. **Confirmation**: Random Forest on HRV features for flagged events (AUC 0.98)

This keeps compute low for normal nights and only runs the heavier model when something looks off.

---

## What the Engineer Needs to Start

### Information we need to provide:
- [ ] **PPG sensor chip model number** — determines SpO2 capability, sample rate, bit depth
- [ ] **Accelerometer chip model** — confirms 3-axis data, sample rate, sensitivity
- [ ] **Gyroscope chip model** — confirms availability for position tracking
- [ ] **BLE data protocol** — how raw sensor data gets to companion app
- [ ] **Companion app tech stack** — iOS (Swift), Android (Kotlin), React Native, Flutter?
- [ ] **Does the PPG chip output SpO2 natively?** — or do we need to calculate it from raw red/infrared channels?

### First Milestone — Sleep Staging Proof of Concept:
1. Capture one full night of raw PPG data from the HLTH band
2. Run through SleepPPG-Net or YASA for Wake/NREM/REM classification
3. Compare against user's self-reported sleep/wake times
4. Confirm sleep detection works on real sensor data

### Second Milestone — Breathing Disruption Detection:
1. During detected sleep epochs, extract SpO2 from PPG
2. Extract breathing rate from accelerometer signal
3. Extract body position from gyroscope
4. Implement event detection: SpO2 drop ≥3% + breathing pause >10 sec
5. Count events per hour
6. Test on Apnea-ECG database and SHHS data first, then real band data

### Third Milestone — Train Custom Models:
1. Download Sleep Heart Health Study + MESA datasets
2. Train sleep staging model on PPG data
3. Train apnea event classifier (Random Forest on HRV + SpO2 features)
4. Validate across Wearanize+ wearable dataset
5. Tune confidence thresholds

### Fourth Milestone — Ship:
1. Integrate both pipelines (sleep staging + event detection) into companion app
2. Implement multi-night tracking (require 2+ nights before alerting)
3. Build notification UX: "Frequent breathing disruptions detected — consider consulting a doctor"
4. Show nightly trend: disruption count, SpO2 baseline, sleep position breakdown
5. QA across wrist positions, skin tones, sleeping positions

---

## Key Technical References

### Datasets
- Apnea-ECG Database: https://physionet.org/content/apnea-ecg/
- Sleep Heart Health Study: https://physionet.org/content/shhpsgdb/
- Sleep-EDF: https://www.physionet.org/physiobank/database/sleep-edf/
- MESA sleep data: https://arxiv.org/html/2404.06869v1
- Wearanize+ (wearable-specific): referenced in sleep staging literature

### Papers
- ApSense (PPG apnea detection): https://arxiv.org/html/2306.10863v3
- SleepPPG-Net (PPG sleep staging): https://arxiv.org/abs/2202.05735
- Deep learning PPG sleep staging: https://pmc.ncbi.nlm.nih.gov/articles/PMC7658638/
- HRV for apnea detection (AUC 0.98): https://pmc.ncbi.nlm.nih.gov/articles/PMC12457166/
- Real-time apnea from SpO2 (96%): https://pmc.ncbi.nlm.nih.gov/articles/PMC11141842/
- PPG watch apnea quantification: https://pmc.ncbi.nlm.nih.gov/articles/PMC7652322/
- Accelerometer breathing rate + position: https://pubmed.ncbi.nlm.nih.gov/33019035/
- Motion artifact removal survey: https://pmc.ncbi.nlm.nih.gov/articles/PMC7085621/
- Wearable AI sleep apnea meta-analysis: https://pmc.ncbi.nlm.nih.gov/articles/PMC11422752/
- SleepFM foundation model (Stanford): https://med.stanford.edu/news/all-news/2026/01/ai-sleep-disease.html

### GitHub Repos
- ApSense: https://github.com/iobt-vistec/apsense
- Sleep staging models: https://github.com/DavyWJW/sleep-staging-models
- Sleep-Apnea (12+ models): https://github.com/mahsaabahrami/Sleep-Apnea
- Apnea-ECG (heart rate only): https://github.com/ChiQiao/Apnea-ECG
- SpO2 smartwatch apnea: https://github.com/arlenejohn/Sleep_apnea_SpO2
- ApnoeDetectRaw: https://github.com/mabartcz/ApnoeDetectRaw
- LeNet-5 apnea: https://github.com/JackAndCole/Sleep-apnea-detection-through-a-modified-LeNet-5
- YASA: https://github.com/raphaelvallat/yasa
- SLEEPYLAND: https://github.com/biomedical-signal-processing/sleepyland
- U-Time/U-Sleep: https://github.com/perslev/U-Time
- DeepSleepNet: https://github.com/akaraspt/deepsleepnet
- AttnSleep: https://github.com/emadeldeen24/AttnSleep
- Pulse-PPG foundation model: https://github.com/maxxu05
- E2E-PPG pipeline: https://github.com/HealthSciTech/E2E-PPG

---

## Cost Summary

| Item | Cost |
|------|------|
| Datasets | Free (PhysioNet, NSRR, public repos) |
| Libraries | Free (open-source Python) |
| Algorithm code | Free (GitHub) |
| Foundation models | Free (Pulse-PPG, PaPaGei) |
| Model training compute | $100–500 (GPU cloud hours) |
| FDA submission | $0 (no medical claims) |
| Clinical validation | $0 (no medical claims) |
| Licensing fees | $0 (no third-party SDK) |
| **Total** | **~$100–500** |

---

## Shared Infrastructure with AFib Pipeline

These components are identical between both features and only need to be built once:

- PPG signal acquisition and BLE transport
- Bandpass filtering (0.5–5 Hz)
- Motion artifact removal (accelerometer reference)
- Peak detection and R-R interval extraction
- HRV feature extraction (pyHRV)
- Signal quality assessment
- App notification framework

The sleep apnea feature adds on top:
- Sleep staging model
- SpO2 extraction and desaturation tracking
- Breathing rate extraction from accelerometer
- Body position classification from gyroscope
- Multi-night tracking and trend visualization
