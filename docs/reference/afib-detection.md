---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: afib detection
status: draft
created: 2026-04-26
---

# AFib Detection Build Guide — HLTH Smartband

## Executive Summary

We're building an irregular rhythm detection feature for the HLTH smartband using entirely free, open-source tools and publicly available datasets. No licensing fees. No FDA submission required. No clinical validation study needed — as long as we label it **"irregular rhythm notification"** and make **zero atrial fibrillation medical claims**.

The entire pipeline can be built in-house using Python, free research datasets from MIT/PhysioNet, and the PPG sensor + accelerometer/gyroscope already inside the band. Total out-of-pocket cost: effectively **$0**. Just engineering time.

---

## What We're Building

A software pipeline that:

1. Reads raw PPG (photoplethysmography) data from the smartband's optical heart rate sensor
2. Removes motion noise using the onboard accelerometer and gyroscope
3. Detects pulse peaks and extracts beat-to-beat (R-R) intervals
4. Classifies rhythm as regular or irregular using a trained ML model
5. Fires a push notification: **"Irregular rhythm detected — consult your doctor"**

**What we are NOT doing:**
- No "atrial fibrillation" claims (that requires FDA 510(k) clearance)
- No medical device classification
- No clinical trials
- No licensed SDKs or third-party algorithm fees

---

## Regulatory Position

| Approach | Regulatory Requirement | Example |
|----------|----------------------|---------|
| "Irregular rhythm notification" | **None** — wellness feature | What we're doing |
| "Atrial fibrillation detection" | FDA 510(k) — 12-18 months, $50-150K+ | Apple, Samsung, Fitbit |

By avoiding the word "atrial fibrillation" in all user-facing copy, marketing, and app UI, we sidestep FDA medical device classification entirely. The feature is positioned as a wellness notification, not a diagnostic tool.

---

## Architecture

```
LAYER 1: HARDWARE (already exists)
  PPG optical sensor → raw pulse waveform
  Accelerometer → 3-axis motion data
  Gyroscope → rotational motion data
      ↓ BLE to companion app

LAYER 2: SIGNAL PROCESSING (Python)
  Bandpass filter: 0.5–5 Hz (Butterworth 2nd order)
  Motion artifact removal using accelerometer/gyro reference
  Signal quality scoring — auto-reject bad segments
      ↓ clean PPG signal

LAYER 3: PEAK DETECTION + INTERVAL EXTRACTION
  Detect pulse peaks in cleaned PPG waveform
  Extract R-R intervals (beat-to-beat timing, ms precision)
      ↓ R-R interval time series

LAYER 4: FEATURE EXTRACTION
  Time-domain HRV: SDNN, RMSSD, pNN50
  Frequency-domain HRV: LF/HF ratio
  Irregularity metrics: Shannon entropy
  PPG morphology features
      ↓ feature vector

LAYER 5: CLASSIFICATION
  Trained ML model (Random Forest or BiGRU)
  Outputs: regular / irregular / inconclusive
      ↓ classification result

LAYER 6: DECISION LOGIC
  Single irregular reading ≠ alert
  Require 5+ irregular episodes across 65+ minutes
  Confidence threshold before notifying user
      ↓ push notification (or silence)
```

---

## Free Datasets for Training

All publicly available. No licensing.

| Dataset                      | Source                 | Contents                                            | Size                                   |
| ---------------------------- | ---------------------- | --------------------------------------------------- | -------------------------------------- |
| **PulseDB**                  | MIT/PhysioNet          | ECG + PPG + ABP from 5,361 subjects                 | 5.2M 10-sec segments, 14,570 hours     |
| **MIMIC-III-Ext-PPG**        | MIT/PhysioNet          | PPG across sinus rhythm, afib, flutter, heart block | Multi-rhythm benchmark                 |
| **Pulsewatch**               | Clinical trial dataset | Smartwatch PPG + accelerometer + ECG reference      | 166,904 labeled 30-sec segments        |
| **PhysioNet Challenge 2015** | MIT/PhysioNet          | ICU waveforms with arrhythmia labels                | 750+ recordings                        |
| **BUT PPG**                  | Brno University        | Smartphone PPG + ECG + accelerometer                | 3,888 recordings                       |
| **VitalDB Arrhythmia**       | Open source            | 482 patients, 5-annotator validated                 | 734,528 seconds, 660K+ annotated beats |
| **PPGSynth**                 | Open source            | Generate synthetic irregular PPG for testing        | Unlimited synthetic data               |

**Start with PulseDB** — largest cleaned dataset. Use Pulsewatch as secondary validation since it's real smartwatch data with motion artifacts.

---

## Free Open-Source Libraries

| Library       | Purpose                                                                      | Language | Install                       |
| ------------- | ---------------------------------------------------------------------------- | -------- | ----------------------------- |
| **pyPPG**     | Full PPG processing — filtering, beat detection, fiducial points, biomarkers | Python   | `pip install pyPPG`           |
| **NeuroKit2** | Multi-signal processing, auto-pipeline, visualization                        | Python   | `pip install neurokit2`       |
| **BioSPPy**   | Biosignal processing primitives                                              | Python   | `pip install biosppy`         |
| **pyHRV**     | HRV parameter extraction (time + frequency domain)                           | Python   | `pip install pyhrv`           |
| **E2E-PPG**   | End-to-end: quality assessment → artifact removal → peak detection → HRV     | Python   | GitHub: HealthSciTech/E2E-PPG |
| **PPG-beats** | Beat detection benchmarking (15 algorithms tested, MSPTD + qppg best)        | MATLAB   | GitHub: ppg-beats             |
| **PPGSynth**  | Generate synthetic PPG with configurable arrhythmia patterns                 | Python   | GitHub                        |

---

## Free Algorithm Implementations (GitHub)

| Repository                                                | Approach                                          | Performance       |
| --------------------------------------------------------- | ------------------------------------------------- | ----------------- |
| **Nakul-Hari/Cardiac_Arrhytmia_Classification_using_RNN** | LSTM + BiLSTM on raw PPG waveforms                | Published results |
| **ShivamShrivastava18/Arrhythmia-detection-using-PPG**    | Decision tree classifier on MIMIC data            | 94.4% accuracy    |
| **chengding0713/Awesome-PPG-AF-detection**                | Curated master list of all afib-PPG papers + code | Meta-repository   |
| **HealthSciTech/E2E-PPG**                                 | Production-grade end-to-end pipeline              | Full pipeline     |

---

## Motion Artifact Removal (Using Onboard Accelerometer + Gyroscope)

The band already has an IMU (accelerometer + gyroscope). These sensors provide the motion reference signal needed to clean PPG data. Four proven methods:

1. **Adaptive Noise Cancellation** — accelerometer signal = motion reference, subtract from PPG. Simplest approach.
2. **Independent Component Analysis (ICA)** — separate cardiac signal from motion across multi-wavelength PPG channels. Results: 99% sensitivity (walking), 96% (fast walking), 82% (running).
3. **SpaMA Algorithm** — compare PPG and accelerometer frequency spectra, remove matching frequencies. 5-stage pipeline. Well-documented.
4. **Deep Learning Artifact Removal** — train a neural net to distinguish cardiac vs motion signal. Most sophisticated, best results.

**Key insight from research**: Nighttime monitoring achieves ~94% clean signal quality (minimal motion). Prioritize sleep-hour screening for irregular rhythm detection — this is when afib episodes are most detectable and motion artifacts are lowest.

---

## Model Selection Recommendations

| Model | Accuracy | Pros | Cons |
|-------|----------|------|------|
| **Random Forest** on R-R intervals | 99.1% | Fast inference, interpretable, lightweight | Needs engineered features |
| **BiGRU (Bidirectional GRU)** | 96.2% AUC | Works on raw waveforms, multimodal input | Heavier compute |
| **Decision Tree** | 94.4% | Simplest, runs anywhere | Lower ceiling |
| **Transfer Learning from ECG** | Varies | Leverages massive ECG datasets | Requires fine-tuning on PPG |

**Recommendation**: Start with Random Forest on R-R interval features. It's the fastest to ship, runs on-device, and 99.1% accuracy is hard to beat. Graduate to deep learning later if needed.

---

## What the Engineer Needs to Start

### Information we need to provide:
- [ ] **PPG sensor chip model number** — determines sample rate, bit depth, raw output format
- [ ] **Accelerometer/gyroscope chip model** — confirms IMU data availability and format
- [ ] **BLE data protocol** — how raw sensor data currently gets to the companion app
- [ ] **Companion app tech stack** — iOS (Swift), Android (Kotlin), React Native, Flutter?

### First milestone — Proof of Concept:
1. Capture 5 minutes of raw PPG + accelerometer data from the HLTH band
2. Run it through pyPPG for filtering + peak detection
3. Extract R-R intervals using pyHRV
4. Feed into pre-trained model from Nakul-Hari or ShivamShrivastava18 repo
5. Confirm it can distinguish regular vs irregular rhythm on real sensor data

### Second milestone — Train Custom Model:
1. Download PulseDB dataset
2. Train Random Forest classifier on R-R interval features
3. Validate against Pulsewatch smartwatch dataset (closest to our use case)
4. Tune confidence thresholds and alert logic

### Third milestone — Ship:
1. Integrate pipeline into companion app
2. Implement decision logic (5+ episodes across 65+ minutes)
3. Build notification UX: "Irregular rhythm detected — consult your doctor"
4. QA across skin tones, wrist positions, activity levels

---

## Key Technical References

- PulseDB dataset: https://www.frontiersin.org/articles/10.3389/fdgth.2022.1090854/full
- MIMIC-III-Ext-PPG: https://physionet.org/content/mimic-iii-ext-ppg/
- Pulsewatch multiclass study: https://pmc.ncbi.nlm.nih.gov/articles/PMC11661413/
- Deep learning on raw PPG for afib: https://pmc.ncbi.nlm.nih.gov/articles/PMC8183963/
- Motion artifact removal survey: https://pmc.ncbi.nlm.nih.gov/articles/PMC7085621/
- SpaMA algorithm: https://pmc.ncbi.nlm.nih.gov/articles/PMC4732043/
- R-R interval classification (99.1%): https://pmc.ncbi.nlm.nih.gov/articles/PMC8391893/
- PPG beat detector benchmarking: https://pmc.ncbi.nlm.nih.gov/articles/PMC9393905/
- E2E-PPG pipeline: https://github.com/HealthSciTech/E2E-PPG
- Awesome PPG-AF detection repo: https://github.com/chengding0713/Awesome-PPG-AF-detection

---

## Cost Summary

| Item | Cost |
|------|------|
| Datasets | Free (PhysioNet, public repos) |
| Libraries | Free (open-source Python) |
| Algorithm code | Free (GitHub) |
| Model training compute | $100-500 (GPU cloud hours) |
| FDA submission | $0 (no medical claims) |
| Clinical validation | $0 (no medical claims) |
| Licensing fees | $0 (no third-party SDK) |
| **Total** | **~$100-500** |
