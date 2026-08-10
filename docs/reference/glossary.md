---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: engineering glossary
status: draft
created: 2026-04-26
---

# HLTH Smartband — Engineering Glossary

Plain-English definitions of every medical, signal processing, and sensor term used across all build guide documents. Organized alphabetically.

---

## A

**AC Component (PPG)**: The pulsating part of the PPG signal that changes with each heartbeat. This is the useful signal. Extracted by subtracting the DC component from the raw signal.

**Accelerometer**: Sensor that measures acceleration force in three directions (X, Y, Z). At rest it reads ~1g (Earth's gravity). Movement adds additional acceleration. Used for step counting, activity detection, fall detection, and breathing rate estimation.

**ADC (Analog-to-Digital Converter)**: The chip component that converts the analog light signal from the PPG photodetector into digital numbers. Higher bit depth = more precise readings. Typical: 16-18 bit.

**AFib (Atrial Fibrillation)**: An irregular heart rhythm where the upper chambers of the heart beat chaotically. Detectable from PPG because the time between heartbeats becomes "irregularly irregular" — no pattern to the randomness.

**AHI (Apnea-Hypopnea Index)**: The number of breathing pauses (apnea) or shallow breaths (hypopnea) per hour of sleep. Clinical measure for sleep apnea severity. We do NOT use this term in the app — we say "breathing disruptions per hour."

**Augmentation Index (AIx)**: A measure of arterial stiffness derived from the PPG waveform shape. Calculated as the difference between the augmented systolic peak and the initial systolic shoulder, divided by pulse pressure. Higher = stiffer arteries = older vascular age. Measured as a percentage.

**Autonomic Nervous System**: The part of the nervous system that controls involuntary functions (heart rate, digestion, breathing). Has two branches: sympathetic ("fight or flight") and parasympathetic ("rest and digest"). HRV reflects the balance between them.

---

## B

**Bandpass Filter**: A signal processing tool that keeps only frequencies within a specified range and removes everything else. For cardiac PPG: keep 0.5-5 Hz. For respiratory PPG: keep 0.1-0.5 Hz. Implemented using Butterworth or Chebyshev filter designs.

**Baseline (Personal)**: An individual's normal values for a given metric, calculated as a rolling average over 14 or 30 days. All anomaly detection and scoring compares today's values against this personal baseline — not population averages.

**BLE (Bluetooth Low Energy)**: The wireless protocol used to transmit data from the band to the companion phone app. Low power consumption, sufficient bandwidth for sensor data.

**BPM (Beats Per Minute)**: Heart rate measurement. Calculated from PPG as 60,000 ms divided by the average R-R interval in milliseconds.

---

## C

**Calibration (BP)**: The process of anchoring PPG-based blood pressure estimates to a known reference value. The user takes a reading with a standard arm cuff and enters it into the app. The algorithm uses this to create a personalized correction factor.

**Cardiac Output**: The volume of blood pumped by the heart per minute. Cardiac Output = Stroke Volume × Heart Rate. Typically 4-8 L/min at rest. Estimated from PPG using pulse area analysis (relative trends only — not absolute values).

**Chronological Age**: How old you actually are (years since birth). Distinguished from biological age, which estimates how old your body appears physiologically.

**Cold Start**: The period after a user first starts wearing the band when there isn't enough historical data to compute baselines, trends, or composite scores. Most features need 14-30 days of data before they're meaningful.

**Coefficient of Variation (CV)**: Standard deviation divided by the mean. Used to measure consistency. Lower CV = more consistent. For R-R intervals, CV < 0.1 = very regular heartbeat, CV > 0.3 = irregular/noisy.

---

## D

**DC Component (PPG)**: The steady-state (non-pulsating) part of the PPG signal. Represents average light absorption from tissue, bone, and venous blood. Removed during filtering to isolate the AC (cardiac) component.

**Dicrotic Notch**: A small dip in the PPG waveform that occurs after the systolic peak. Caused by the aortic valve closing. In young, elastic arteries, this notch is clearly visible. In stiff, older arteries, it merges with the main peak. Its position and clarity are used to calculate arterial stiffness.

**Desaturation (SpO2)**: A drop in blood oxygen saturation. During sleep apnea events, SpO2 may drop 3-10% from baseline. A desaturation event = SpO2 drop ≥3-4% from the rolling baseline.

---

## E

**Ectopic Beat**: An extra or premature heartbeat that doesn't follow the normal rhythm. Appears as an abnormally short R-R interval followed by an abnormally long one. Must be detected and removed before HRV calculation (the `hrvanalysis` package handles this automatically using the Malik method).

**Epoch**: A fixed-length time window used for analysis. Sleep staging uses 30-second epochs. Other analyses may use 5-second, 10-second, or 60-second epochs depending on the feature.

---

## F

**Fiducial Points**: Specific landmark points on a single PPG pulse waveform. Key fiducial points include: pulse onset, systolic peak, dicrotic notch, and diastolic minimum. These are needed for arterial stiffness, cardiac output, blood pressure, and vascular age calculations. PhysioZoo PPG automates their detection.

**filtfilt**: A scipy function that applies a digital filter forward and then backward across a signal. This eliminates phase distortion, meaning peaks stay in their correct time position after filtering. Always use `filtfilt` instead of `lfilter` for PPG processing.

**Follicular Phase**: The first half of the menstrual cycle (approximately days 1-14). Characterized by lower resting heart rate and higher HRV compared to the luteal phase.

**Freedson Equation**: A published formula that converts raw accelerometer data (counts per minute) into estimated METs (metabolic equivalents). Used for activity intensity classification and VO2 max estimation.

---

## G

**g (Gravitational Force)**: The unit of acceleration. 1g = 9.81 m/s² (Earth's gravity). At rest, the accelerometer reads ~1g. During a fall impact, it may spike to 3-8g.

**Gyroscope**: Sensor that measures rotational velocity in three axes (roll, pitch, yaw). Units: degrees per second (°/s). Used for sleep position detection, fall detection, and exercise type recognition.

---

## H

**HF (High Frequency) Power**: The power in the 0.15-0.40 Hz band of the HRV frequency spectrum. Primarily reflects parasympathetic (vagal) nervous system activity. Higher HF = more relaxed/recovered.

**HRV (Heart Rate Variability)**: The variation in time between consecutive heartbeats. Healthy hearts have HIGH variability (the time between beats fluctuates naturally). Low HRV indicates stress, fatigue, illness, or aging. Multiple metrics quantify HRV — see RMSSD, SDNN, pNN50.

**Hz (Hertz)**: Cycles per second. Used for: sample rates (75 Hz = 75 samples per second), filter frequencies (0.5 Hz = 0.5 cycles per second = 30 beats per minute), and spectral analysis.

---

## I

**IMU (Inertial Measurement Unit)**: Combined accelerometer + gyroscope sensor package. Most smartband chips integrate both sensors in one package. Provides 6 axes of motion data (3 acceleration + 3 rotation).

**Infrared LED (~940nm)**: One of the PPG light sources. Infrared light penetrates deeper into tissue than green light. Used alongside the red LED for SpO2 calculation. Oxygenated hemoglobin absorbs more infrared light.

**Isolation Forest**: A machine learning algorithm for anomaly detection. Works by randomly splitting data — anomalies are easier to isolate (require fewer splits). Used for illness warning and wellness anomaly detection. Does not require labeled training data.

---

## J

**Jerk**: The rate of change of acceleration (derivative of acceleration). Useful for fall detection — a fall produces high jerk (rapid change from freefall to impact).

---

## K

**Kappa (Cohen's)**: A statistical measure of agreement between two classifiers, accounting for chance agreement. Used to validate sleep staging (predicted stages vs reference PSG stages). κ > 0.7 = good agreement. κ > 0.8 = excellent.

---

## L

**LF (Low Frequency) Power**: The power in the 0.04-0.15 Hz band of the HRV frequency spectrum. Reflects both sympathetic and parasympathetic activity. The LF/HF ratio is used as a proxy for sympatho-vagal balance (higher ratio = more stress).

**Luteal Phase**: The second half of the menstrual cycle (approximately days 14-28). Characterized by elevated resting heart rate (~2-3 bpm above follicular baseline) and suppressed HRV (~10-15% lower RMSSD).

---

## M

**MAE (Mean Absolute Error)**: Average of the absolute differences between predicted and actual values. Used to evaluate algorithm accuracy. Example: "MAE of 5 mmHg" means predictions are off by 5 mmHg on average.

**METs (Metabolic Equivalents)**: A measure of exercise intensity. 1 MET = energy expenditure at rest. Walking = ~3-4 METs. Running = ~8-12 METs. Estimated from accelerometer data using the Freedson equation.

**MIMIC-III**: A large, publicly available ICU dataset from MIT containing synchronized PPG, ECG, blood pressure, and other physiological signals from thousands of patients. Primary training/validation data for many algorithms.

---

## N

**NREM (Non-Rapid Eye Movement) Sleep**: Sleep stages 1-3, including light sleep and deep sleep. Deep sleep (stage 3, also called "slow-wave sleep") is the most restorative phase.

**Nyquist Frequency**: Half the sampling rate. You can only reliably detect signal frequencies below the Nyquist frequency. At 75 Hz sampling, you can detect signals up to 37.5 Hz — more than enough for cardiac (0.5-5 Hz) and respiratory (0.1-0.5 Hz) signals.

---

## P

**PAT (Pulse Arrival Time)**: The time from the heart's electrical activation (ECG R-peak) to the arrival of the pulse at a peripheral site (PPG peak). Related to pulse wave velocity and blood pressure. Requires both ECG and PPG — if the band only has PPG, use PTT instead.

**Peak Detection**: The process of finding individual heartbeat peaks in the filtered PPG signal. Uses amplitude thresholds, minimum distance between peaks, and prominence (how much a peak stands out from surrounding signal). Implemented via scipy's `find_peaks()`.

**PhysioNet**: A repository of freely available physiological signal databases maintained by MIT. The primary source for training and validation data (MIMIC-III, Apnea-ECG, Sleep-EDF, PulseDB, etc.). https://physionet.org

**pNN50**: The percentage of consecutive R-R intervals that differ by more than 50 milliseconds. A time-domain HRV metric reflecting parasympathetic activity. Higher = more recovered. Typical resting values: 5-40%.

**PPG (Photoplethysmography)**: The optical sensing technology used in the band. An LED shines light into the skin, and a photodetector measures how much light is reflected back. Blood absorbs light, so the signal pulsates with each heartbeat. The waveform contains information about heart rate, rhythm, blood pressure, arterial stiffness, oxygen saturation, and respiratory rate.

**Prominence (Peak)**: How much a peak stands out from the surrounding signal. Used as a criterion in peak detection to distinguish real heartbeat peaks from noise. Measured as the height of the peak above the higher of the two nearest troughs.

**PSG (Polysomnography)**: The gold standard for sleep studies. Records EEG (brain waves), EOG (eye movement), EMG (muscle activity), ECG, airflow, and SpO2 simultaneously. Used as the reference standard for validating wearable sleep staging and sleep apnea algorithms.

**PTT (Pulse Transit Time)**: The time it takes for a pulse wave to travel between two points. Can be estimated from a single PPG site using the timing between different fiducial points within one pulse waveform. Inversely related to blood pressure — faster transit = stiffer arteries = higher BP.

**Pulse Wave Velocity (PWV)**: The speed at which the blood pressure pulse wave travels through the arterial system. Measured in m/s. The stiffness index is essentially a PWV estimate from PPG. Higher PWV = stiffer arteries = older vascular age.

---

## R

**R-R Interval**: The time between two consecutive heartbeat peaks, measured in milliseconds. In ECG, this is the time between R-peaks. In PPG, it's the time between systolic peaks (technically "peak-to-peak interval" but commonly called R-R by convention). The foundation for all HRV metrics.

**Red LED (~660nm)**: One of the PPG light sources. Deoxygenated hemoglobin absorbs more red light than oxygenated hemoglobin. Used alongside infrared for SpO2 calculation.

**REM (Rapid Eye Movement) Sleep**: The sleep stage associated with dreaming, memory consolidation, and emotional processing. Typically 20-25% of total sleep in healthy adults. Declines with age.

**RMSSD (Root Mean Square of Successive Differences)**: The PRIMARY short-term HRV metric. Calculated as the square root of the mean of squared differences between consecutive R-R intervals. Reflects parasympathetic (vagal) activity. Higher = more recovered. Most important single metric for recovery scoring. Typical resting values: 20-80 ms (varies hugely by individual — always compare against personal baseline).

**ROC AUC (Receiver Operating Characteristic Area Under Curve)**: A measure of how well a classifier distinguishes between two classes. 1.0 = perfect, 0.5 = random chance. Used to evaluate algorithms like AFib detection and illness warning.

---

## S

**Sampling Rate**: How many data points the sensor captures per second. Measured in Hz. PPG at 75 Hz = 75 light intensity measurements per second. Higher rates capture more detail but use more battery and storage.

**SDNN (Standard Deviation of NN Intervals)**: A time-domain HRV metric measuring overall variability of all R-R intervals. Reflects total autonomic nervous system activity (both sympathetic and parasympathetic). Requires at least 5 minutes of data for meaningful calculation. Higher = healthier.

**Signal-to-Noise Ratio (SNR)**: How much useful signal there is compared to noise. For PPG: the cardiac signal power compared to motion/noise power. Higher SNR = cleaner signal = more reliable metrics.

**SpO2 (Peripheral Oxygen Saturation)**: The percentage of hemoglobin molecules carrying oxygen. Normal: 95-100%. Below 90% is clinically concerning. Calculated from the ratio of red to infrared PPG signal absorption.

**Stiffness Index (SI)**: A PPG-derived measure of arterial stiffness. Calculated as body height divided by the time between the systolic peak and the diastolic peak of the PPG waveform. Units: m/s. Normal ranges: 6-7 m/s (age 20-30) to 12-15 m/s (age 80+).

**Stroke Volume**: The volume of blood pumped by the heart with each beat. Typically 60-100 mL at rest. Cannot be accurately measured in absolute terms from wrist PPG, but relative trends (going up or down) can be tracked using pulse area analysis.

**Sympathetic Nervous System**: The "fight or flight" branch of the autonomic nervous system. Increases heart rate, decreases HRV. Activated by stress, exercise, illness, or stimulants.

**Systolic Peak**: The highest point in a single PPG pulse waveform. Corresponds to the moment of maximum blood volume in the artery (peak of the heartbeat). The primary landmark for peak detection.

---

## T

**TFLite (TensorFlow Lite)**: A lightweight version of TensorFlow for deploying ML models on mobile devices or microcontrollers. Used for on-device inference (activity classification, fall detection).

---

## V

**Vagal Tone**: The activity level of the vagus nerve (main parasympathetic nerve). Higher vagal tone = slower resting heart rate, higher HRV, better recovery capacity. Reflected primarily by RMSSD and HF power.

**Vascular Age**: An estimate of how old the arterial system appears based on stiffness and elasticity measurements. A 40-year-old with very stiff arteries might have a vascular age of 55. Calculated from stiffness index, augmentation index, and optionally blood pressure.

**VO2 Max (Maximal Oxygen Uptake)**: The maximum rate at which the body can consume oxygen during exercise. Measured in mL/kg/min. The single strongest predictor of cardiovascular mortality and longevity. Estimated from heart rate response to exercise intensity.
