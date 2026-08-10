---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: longevity score
status: draft
created: 2026-04-26
---

# Longevity / Biological Age Score Build Guide — HLTH Smartband

## Executive Summary

We're building a biological age score that tells users how old their body actually is versus their chronological age. This is a composite intelligence layer on top of all health metrics the HLTH band already collects. It requires no new sensors, no FDA clearance, and no licensed algorithms.

The score answers the single most compelling health question: **"Is my body aging faster or slower than my actual age?"**

This is the feature that ties every other metric together and gives them meaning. Heart rate, HRV, blood pressure, sleep, SpO2, activity — individually they're data points. Combined into a biological age score, they become a story about the user's health trajectory.

**Competitive reference**: Ultrahuman's longevity score, Oura's readiness trend, WHOOP's health monitor. But none of them do a true PPG-based biological age estimation with the research backing we can leverage.

**Published validation**: Apple's PpgAge study (213,593 participants) proved that PPG waveforms alone predict cardiovascular disease, metabolic disease, and mortality risk. The UK Biobank PPG Age study (212,231 participants) showed that a PPG age gap >9 years = **2.37x higher risk of major cardiovascular events**. This isn't speculative — it's validated at massive scale.

Total cost: **~$100-500** (GPU training compute). Everything else is free.

---

## What the User Sees

```
┌──────────────────────────────────────────┐
│                                          │
│   Your Body Age         34               │
│   Chronological Age     41               │
│                                          │
│   You're 7 years younger ↓              │
│                                          │
│   ─────────────────────────────────────  │
│                                          │
│   SYSTEM BREAKDOWN                       │
│                                          │
│   Cardiovascular    32  ████████████░░   │
│   Sleep Health      38  █████████░░░░░   │
│   Recovery          35  ██████████░░░░   │
│   Fitness           31  █████████████░   │
│   Respiratory       33  ████████████░░   │
│                                          │
│   ─────────────────────────────────────  │
│                                          │
│   TREND (last 90 days)                   │
│   Body Age: 36 → 34  Improving ↓        │
│                                          │
│   TOP FACTOR HOLDING YOU BACK:           │
│   Sleep — your deep sleep has declined   │
│   15% over the past 2 weeks             │
│                                          │
└──────────────────────────────────────────┘
```

### Why This Works Psychologically
- **Single number** — easy to understand, easy to track
- **Sub-scores** — actionable, tells the user what to improve
- **Trend over time** — creates long-term engagement
- **Relative to self** — not compared to population norms but personal trajectory
- **"Holding you back" insight** — turns data into a specific action

---

## What Goes Into the Score

### Inputs (All Already Collected by HLTH Band)

| Input | What It Reveals | Source Sensor | Sub-Score |
|-------|----------------|---------------|-----------|
| **PPG waveform morphology** | Vascular stiffness, arterial health — arteries visibly age in PPG shape | PPG | Cardiovascular |
| **Blood pressure** | Cardiovascular strain — you already have this feature | PPG | Cardiovascular |
| **Resting heart rate** | Cardiovascular efficiency | PPG | Cardiovascular |
| **Resting HRV (RMSSD)** | Autonomic nervous system health — declines with biological aging | PPG | Recovery |
| **HRV trend (7-14 day)** | Is autonomic health improving or declining? | PPG | Recovery |
| **SpO2 baseline** | Respiratory and circulatory efficiency | PPG | Respiratory |
| **Respiratory rate** | Resting RR correlates with health status | PPG | Respiratory |
| **Sleep quality** | Deep sleep %, REM %, efficiency, consistency | PPG + Accel | Sleep Health |
| **Sleep duration** | Total sleep and sleep debt | PPG + Accel | Sleep Health |
| **VO2 Max estimate** | Cardiorespiratory fitness — strongest single longevity predictor | PPG + Accel | Fitness |
| **Activity patterns** | Daily movement, step variability, sedentary time | Accelerometer | Fitness |
| **Recovery score** | How well the body bounces back from strain | Composite | Recovery |

### User-Provided Inputs (From Profile)

| Input | Why It's Needed |
|-------|----------------|
| **Date of birth** | Chronological age — the baseline to compare against |
| **Sex** | Physiological norms differ significantly |
| **Height / Weight** (optional) | Improves VO2 max and BP contextualization |
| **Smoking status** (optional) | Major confounder in biological age |

---

## Architecture

```
LAYER 1: DATA COLLECTION (continuous)
  PPG → HR, HRV, BP, SpO2, respiratory rate, waveform morphology
  Accelerometer → steps, activity intensity, sleep movement
  Gyroscope → sleep position
  All stored as daily summaries + raw waveforms for deep analysis
      ↓

LAYER 2: METRIC COMPUTATION (daily)
  Resting HR (morning, first 5 min post-wake)
  Resting HRV (RMSSD, SDNN from overnight PPG)
  Blood pressure (morning resting reading)
  SpO2 overnight average
  Respiratory rate (resting average)
  Sleep staging + quality metrics
  Activity load (step count, intensity minutes)
  VO2 max (updated after qualifying exercise sessions)
  Recovery score (from separate recovery pipeline)
      ↓

LAYER 3: PERSONAL BASELINES (rolling)
  14-day rolling averages for all metrics
  90-day trend lines for trajectory analysis
  Seasonal adjustment (optional — HRV varies by season)
      ↓

LAYER 4: SUB-SCORE COMPUTATION
  Each health system scored independently:
  
  Cardiovascular Sub-Score:
    f(PPG_morphology, BP, resting_HR, age, sex) → vascular age
  
  Sleep Health Sub-Score:
    f(deep_sleep%, REM%, efficiency, consistency, duration) → sleep age
  
  Recovery Sub-Score:
    f(HRV_rmssd, HRV_trend, recovery_score, HRV_baseline) → recovery age
  
  Fitness Sub-Score:
    f(VO2_max, step_count, step_variability, active_minutes) → fitness age
  
  Respiratory Sub-Score:
    f(SpO2_baseline, respiratory_rate, breathing_disruptions) → respiratory age
      ↓

LAYER 5: COMPOSITE BIOLOGICAL AGE
  biological_age = weighted_mean(sub_scores)
  
  Suggested starting weights:
    Cardiovascular: 30%  (strongest mortality predictor)
    Fitness:        25%  (VO2 max = strongest longevity predictor)
    Sleep Health:   20%  (sleep quality strongly correlates with aging)
    Recovery:       15%  (autonomic health reflects systemic aging)
    Respiratory:    10%  (supplementary signal)
  
  body_age_gap = biological_age - chronological_age
  Negative gap = younger than your age (good)
  Positive gap = older than your age (warning)
      ↓

LAYER 6: INSIGHT GENERATION
  Identify which sub-score is worst relative to others
  Generate actionable recommendation
  Track trajectory: is the gap improving or worsening?
      ↓

LAYER 7: DISPLAY
  Single body age number + gap
  Sub-score breakdown with visual bars
  90-day trend chart
  "Top factor holding you back" callout
```

---

## Two Approaches to Building This

### Approach A: Rule-Based Composite (Ship Faster)

Each sub-score uses published age-normative tables:

**Cardiovascular age example:**
- Look up expected resting HR for user's age and sex
- Look up expected BP for user's age and sex
- If user's resting HR is 58 bpm and the norm for their age (41) is 68 bpm → cardiovascular age estimated younger
- Map the deviation to years using published normative curves

**Pros**: Interpretable, fast to build, no training data needed
**Cons**: Less accurate, doesn't capture PPG waveform morphology

**Ship timeline**: 2-4 weeks

### Approach B: Deep Learning on PPG Waveforms (Higher Accuracy)

Train a model following Apple's PpgAge methodology:

1. **Self-supervised pretraining** — model learns PPG waveform representations from unlabeled data
2. **Age prediction** — ridge regression predicts chronological age from PPG features (trained only on healthy individuals)
3. **Gap calculation** — difference between predicted age and real age = biological age offset

**Pros**: Captures subtle vascular aging signals, validated at 200K+ participant scale
**Cons**: Needs training data and GPU compute

**Ship timeline**: 4-8 weeks

### Recommendation: Ship A First, Then Upgrade to B

Launch with the rule-based composite score (Approach A) to get the feature in users' hands. Simultaneously train the deep learning model (Approach B) as a backend upgrade. The UX stays identical — only the accuracy improves.

---

## Free Datasets

### For PPG-Based Age Prediction

| Dataset | Source | Contents | Size |
|---------|--------|----------|------|
| **UK Biobank PPG** | UK Biobank | Single-finger PPG + BP from 205,000+ participants | Largest open PPG aging dataset |
| **PulseDB** | Public | ECG + PPG + ABP from 5,361 subjects with demographics | 5.2M segments |
| **MIMIC-III** | PhysioNet/MIT | ICU PPG with patient age and diagnoses | Multi-thousand patients |
| **NHANES** | CDC | Health surveys with fitness, BP, activity, demographics | Tens of thousands of participants |

### For Activity-Based Age Prediction

| Dataset | Source | Contents | Size |
|---------|--------|----------|------|
| **UK Biobank Accelerometer** | UK Biobank | 7-day accelerometer recordings + health outcomes | 100,000+ participants |
| **NHANES Accelerometer** | CDC/PhysioNet | Step data + mortality follow-up | 6,500+ participants |

### For Sleep-Based Age Components

| Dataset | Source | Contents |
|---------|--------|----------|
| **Sleep Heart Health Study** | PhysioNet/NSRR | Full PSG with demographics and follow-up |
| **MESA** | PhysioNet/NSRR | PPG sleep data + cardiovascular outcomes |

---

## Free Libraries and Tools

### Core Pipeline (Shared with Other Features)

| Library | Use in Longevity Score |
|---------|----------------------|
| **pyPPG** | PPG waveform morphology feature extraction |
| **NeuroKit2** | PPG processing, HRV extraction |
| **pyHRV** | HRV parameters (RMSSD, SDNN, LF/HF) |
| **scikit-learn** | Random forest / ridge regression for age prediction |

### Age-Specific Tools

| Library | Use |
|---------|-----|
| **Apple ml-ppg-age-analysis** | Official Apple PpgAge example pipeline — self-supervised PPG pretraining + ridge regression age prediction + health outcome analysis. GitHub: apple/ml-ppg-age-analysis |
| **pyaging** | 50+ aging clock implementations, GPU-optimized. Covers epigenetic, transcriptomic, and physiological clocks. `pip install pyaging` |
| **BioAge (R package)** | Klemera-Doubal biological age, phenotypic age, homeostatic dysregulation. GitHub: dayoonkwon/BioAge |
| **CosinorAge** | Biological age from circadian rhythm patterns in accelerometer data. Python package. |
| **Phenotypic Age Calculator** | Python implementation of Levine's phenotypic age algorithm. GitHub: KyteProject/phenotypic-age-calc |

### Published Models to Reference

| Model | Input | Scale | Key Finding |
|-------|-------|-------|-------------|
| **Apple PpgAge** | Resting PPG waveforms | 213,593 participants, 149M participant-days | PpgAge gap predicts CVD, metabolic disease, mortality |
| **UK Biobank AI-PPG Age** | PPG waveforms | 212,231 participants | >9 year gap = 2.37x cardiovascular event risk |
| **GeroSense** | Accelerometer step data | 103,000+ weekly samples | Step patterns predict biological age acceleration |
| **MoveAge / MoveIt! Age** | Step count max + variability | NHANES + UK Biobank | r=0.93 correlation with chronological age |

---

## Sub-Score Calculation Details

### Cardiovascular Age

**Inputs**: PPG waveform, blood pressure, resting HR

**Rule-based approach:**
```
cv_age = chronological_age
  + bp_offset(systolic, diastolic, age, sex)     # higher BP = older
  + rhr_offset(resting_hr, age, sex)              # higher RHR = older
  + ppg_stiffness_offset(pulse_wave_features)     # stiffer arteries = older
```

**BP age offset reference** (simplified):
- Systolic <120: -2 years
- Systolic 120-130: 0
- Systolic 130-140: +2 years
- Systolic >140: +5 years
(Adjusted for age and sex using published normative tables)

**Deep learning approach:**
- Feed raw PPG waveform to CNN
- Predict cardiovascular age directly
- Apple's methodology: self-supervised pretraining on healthy individuals, then predict age

### Sleep Health Age

**Inputs**: Deep sleep %, REM %, sleep efficiency, consistency, total duration

**Rule-based approach:**
```
sleep_age = chronological_age
  + deep_sleep_offset(deep_pct, age)       # less deep sleep = older
  + rem_offset(rem_pct, age)               # less REM = older  
  + efficiency_offset(efficiency)          # lower efficiency = older
  + consistency_offset(bedtime_variability) # inconsistent = older
  + duration_offset(total_hours)           # too little or too much = older
```

**Key age-normative benchmarks:**
- Deep sleep naturally declines ~2% per decade after age 30
- A 40-year-old with 25% deep sleep has the sleep profile of a 25-year-old
- A 40-year-old with 10% deep sleep has the sleep profile of a 60-year-old

### Fitness Age

**Inputs**: VO2 max estimate, daily step count, step variability, active minutes

**Rule-based approach:**
```
fitness_age = chronological_age
  + vo2max_offset(vo2max, age, sex)        # higher VO2 max = younger
  + activity_offset(daily_steps, age)      # more active = younger
  + variability_offset(step_sd)            # consistent activity = younger
```

**VO2 max age mapping** (simplified, male):
- VO2 max 50+ at age 40: fitness age ~25
- VO2 max 40 at age 40: fitness age ~40 (age-appropriate)
- VO2 max 30 at age 40: fitness age ~55

### Recovery Age

**Inputs**: Resting HRV (RMSSD), HRV trend, recovery score

**Rule-based approach:**
```
recovery_age = chronological_age
  + hrv_offset(rmssd, age, sex)            # higher HRV = younger
  + hrv_trend_offset(7day_trend)           # improving = younger
  + recovery_rate_offset(post_exercise_hr_drop) # faster recovery = younger
```

**HRV age-normative benchmarks:**
- RMSSD naturally declines with age
- A 40-year-old with RMSSD of 60ms has recovery capacity typical of a 25-year-old
- A 40-year-old with RMSSD of 20ms has recovery capacity typical of a 65-year-old

### Respiratory Age

**Inputs**: SpO2 baseline, respiratory rate, breathing disruption count

**Rule-based approach:**
```
respiratory_age = chronological_age
  + spo2_offset(overnight_avg)             # lower SpO2 = older
  + rr_offset(resting_rr)                  # higher resting RR = older
  + disruption_offset(events_per_hour)     # more disruptions = older
```

---

## Calibration and Accuracy

### Cold Start Problem
The score needs ~14 days of data before it's meaningful. During onboarding:
- Day 1-7: "Collecting baseline data..."
- Day 7-14: "Building your profile..."
- Day 14+: First biological age score revealed

### Ongoing Calibration
- Score updates daily (morning, after sleep data processed)
- Sub-scores smooth over 7-14 day windows to avoid noise
- Major life events (illness, travel, injury) cause temporary spikes — the algorithm should detect and label these
- Long-term trend (90-day) is more meaningful than daily number

### Accuracy Expectations
- **Rule-based (Approach A)**: ±8-10 years MAE — directionally correct, good for trends
- **Deep learning (Approach B)**: ±5-6 years MAE — Apple's published accuracy, clinically meaningful
- Both improve with more data over time

---

## What the Engineer Needs to Start

### Information to provide:
- [ ] **All metrics currently stored in the app database** — which daily summaries exist?
- [ ] **PPG raw waveform access** — can we save and process raw PPG segments (needed for Approach B)?
- [ ] **User profile fields** — date of birth, sex, height, weight currently collected?
- [ ] **Historical data depth** — how far back does the app retain daily metrics?
- [ ] **App charting library** — what's used for data visualization? (for trend charts)

### Milestone Plan:

**Phase 1 (Weeks 1-2): Foundation**
- Implement 14-day rolling baseline engine for all metrics
- Set up daily metric aggregation pipeline (morning resting values)
- Build sub-score computation using rule-based normative tables
- Start collecting PPG waveform samples for future deep learning

**Phase 2 (Weeks 3-4): Score Engine**
- Implement weighted composite scoring
- Build the body age gap calculation
- Create insight generation ("top factor holding you back")
- Design the score card UI (single number + sub-scores + trend)

**Phase 3 (Weeks 5-6): Polish and Ship**
- Implement cold start onboarding flow (14-day data collection)
- Add 90-day trend visualization
- QA across different user profiles (age, sex, fitness level)
- Ship as "Body Age (Beta)"

**Phase 4 (Weeks 7-12): Deep Learning Upgrade**
- Download UK Biobank PPG + PulseDB datasets
- Implement Apple's ml-ppg-age-analysis pipeline
- Train self-supervised PPG representation model
- Train age prediction model on healthy individuals
- Validate against rule-based scores
- Deploy as backend upgrade (UX unchanged)

---

## Regulatory Position

| Claim | Regulatory |
|-------|-----------|
| "Body Age" / "Wellness Age" / "Vitality Score" | **None** — wellness feature |
| "Biological Age" (with medical claims) | Potentially FDA-regulated |
| "Predicts disease risk" | FDA-regulated — avoid |

**Safe framing**: "Body Age" or "Vitality Score" — a wellness metric reflecting overall health trends. Never claim it predicts or diagnoses disease. The user sees a number and a trend, not a medical assessment.

---

## Key Technical References

### Apple PpgAge
- Official code: https://github.com/apple/ml-ppg-age-analysis
- Study: 213,593 participants, 149M participant-days
- Publication: European Society of Cardiology commentary
- Key finding: PpgAge gap predicts incident CVD and metabolic disease

### UK Biobank PPG Age
- 212,231 participants
- PpgAge gap >9 years = 2.37x cardiovascular event risk
- Deep learning with distribution-aware loss functions
- Publication: https://pubmed.ncbi.nlm.nih.gov/41258400

### GeroSense (Accelerometer-Based)
- Deep neural network on step-count data
- 103,000+ weekly samples from UK Biobank + NHANES
- Domain adaptation across device types
- Publication: https://pmc.ncbi.nlm.nih.gov/articles/PMC8034931

### MoveAge / MoveIt! Age
- Step count max + variability → biological age
- r=0.93 correlation with chronological age
- Validated for mortality prediction
- Open methodology available

### Aging Clock Libraries
- pyaging (50+ clocks): pip install pyaging
- BioAge R package: https://github.com/dayoonkwon/BioAge
- CosinorAge (circadian): Python package
- Phenotypic Age Calculator: https://github.com/KyteProject/phenotypic-age-calc

---

## Cost Summary

| Item | Cost |
|------|------|
| Datasets | Free (UK Biobank, PhysioNet, NHANES) |
| Libraries | Free (pyaging, pyPPG, scikit-learn) |
| Apple's example code | Free (GitHub) |
| Rule-based score (Phase 1-3) | $0 |
| Deep learning training (Phase 4) | $100-500 (GPU hours) |
| FDA submission | $0 (wellness framing) |
| **Total** | **~$100-500** |
