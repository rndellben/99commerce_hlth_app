---
name: metric-validation
description: >-
  Validate a health metric value or a scoring engine in hlth_app against the
  provided algorithm, the clinical literature, and population data. Use
  whenever a metric number is reported, questioned, or evaluated — HRV, RMSSD,
  SDNN, resting HR, respiratory rate, SpO2, blood pressure, VO2 max, recovery,
  readiness, stability, cardio load, vascular load, mental wellness, stress,
  sleep score, sleep stages, longevity, phenotypic age, irregular rhythm, AFib,
  fall detection — or when asked whether a value is correct, accurate,
  plausible, physiologically possible, or "looks right".
---

# Metric Validation — hlth_app

A number that computes is not a number that means something. This skill is the
protocol for deciding whether a metric value is real, and the map of what
evidence exists to decide it with.

**Announce at start:** "Using metric-validation to check this against the
reference corpus."

## The Iron Law

```
NEVER call a metric value correct, accurate, plausible, or "looks right"
without naming, in the same message:
  1. the algorithm it was checked against,
  2. the clinical reference for the metric's validity,
  3. the population data or physiologic bound it was compared to.
```

If you cannot name all three, the honest output is **"unvalidated"** plus what
specifically is missing. "Unvalidated" is a legitimate, useful answer. A
confident guess is not.

Reading the engine source and finding it self-consistent is **not** validation.
The code can faithfully implement something that measures nothing (see LF/HF
below).

## The six checks, in order

Run these in order; stop and report if one fails.

### 1. Base metrics before composites
Recovery, Cardio Load, Wellness, Longevity and any Health Score are built from
base metrics. If HRV or respiratory rate is wrong, the composite is meaningless
**and still looks plausible.** Never validate a composite while its inputs are
unvalidated — say which input is unproven and validate that first.

### 2. Cross-reference the output against the provided algorithm
Not "does the code run." Take the actual input, compute what the spec in
`docs/reference/` says the output should be, and compare numbers. A mismatch is
the finding. If the spec is ambiguous, say so rather than picking a reading.

### 3. Is it physiologically possible?
Check the value against hard bounds, and check it against the *other* metrics
from the same window. The canonical failure: respiratory rate 12 while HR
spiked to 130. Not unlikely — impossible. That is a quality-gate bug, not a bad
reading. Cross-metric contradiction is the highest-yield check available and the
one most often skipped.

Bounds already enforced in code, for reference:
- `lib/core/processing/ectopic_adaptive.dart` — R-R hard floor 300 ms / ceiling
  2000 ms (200–30 bpm)
- `lib/core/processing/frequency_domain_hrv.dart` — rejects sub-physiological
  respiratory rates
- `lib/core/services/ppg_analysis_service.dart` — cross-checks PPG-derived HR
  against band-reported HR

### 4. Cross-reference population data
The value must sit somewhere sane in a distribution of real humans, not merely
inside this user's own few weeks. Use the dataset named for that metric in the
map below. Population data is the only source of "reality" available when there
is no ground-truth label.

### 5. Check the clinical literature for whether the metric is the right one
Some metrics are invalid regardless of implementation quality.
**Worked example:** LF/HF is invalid as a sympathovagal index
([Billman 2013, PMC3576706](https://pmc.ncbi.nlm.nih.gov/articles/PMC3576706/)).
Correct code, real number, no meaning. No test suite catches this class of
error — only the literature does. Check it before defending any HRV-derived
index.

### 6. A second model must attack the conclusion
One model cannot validate its own work; it agrees with its own errors. When a
validation is complete, state explicitly that it needs an adversarial second
pass by a **different** model, and what that pass should try to refute. Do not
mark a metric validated on a single pass.

## Reference map

Everything below is in `docs/reference/` (in-repo, offline). Read the row for
the metric under discussion before answering.

| Metric | Engine | Spec | Clinical / benchmark | Population data | Status |
|---|---|---|---|---|---|
| **Recovery / Stability** | `core/scoring/recovery_stability.dart` | `recovery-stability-validation.md` | PMC12787763 (RMSSD primary), PMC3576706 (LF/HF invalid), clawrxiv 2604.01619 | — | **validated** |
| **Respiratory rate** | `core/processing/respiratory_lombscargle.dart`, `respiratory_rate.dart` | `respiratory-audit.md`, `quality-gate.md` | RRest (15-algorithm benchmark), correncoder, BIOBSS | CapnoBase | **audited**, not benchmarked |
| **HRV (RMSSD)** | `core/processing/hrv_calculator.dart`, `ectopic_adaptive.dart`, `frequency_domain_hrv.dart` | `health-features.md` §4 | Kubios preprocessing, Giles 2016 artefact correction, hrvanalysis, pyHRV | SWELL-KW, WESAD | **partial** — no parity check |
| **Resting HR** | band-reported + daily aggregator | `health-features.md` §0 | BeliefPPG (0.7±0.8 bpm), RapidHRV, HeartPy | PPG-DaLiA, TROIKA, PulseDB, CAST | unvalidated |
| **Blood pressure** | `core/processing/bp_formula.dart` | `health-features.md` §1 | R-PTT (MAE 4.92/8.89 mmHg, n=30), cufflessbp_dann, PhysioZoo | MIMIC-III ext PPG | **see warning below** |
| **VO2 max** | `core/scoring/vo2max_estimation.dart`, `services/vo2max_service.dart` | `health-features.md` §3 | Åstrand-Ryhming, Cole HR-recovery, Freedson — all closed-form | NHANES | unvalidated |
| **Vascular load** | `core/scoring/vascular_load.dart` | `advanced-health-features.md` §3 | UK Biobank PPG methodology | UK Biobank (205k), PulseDB (5,361), MIMIC-III | unvalidated |
| **Mental wellness / stress** | `core/scoring/mental_wellness.dart`, `services/mental_wellness_service.dart` | `advanced-health-features.md` §2 | NeuroKit2, hrvanalysis. **Check for LF/HF dependence.** | WESAD (labelled), TILES, SWELL-KW | unvalidated |
| **Sleep staging / score** | `core/processing/sleep_scoring.dart`, `core/scoring/sleep_epochs_builder.dart`, `services/sleep_onset_detector.dart` | — | YASA, AttnSleep, U-Time, deepsleepnet | Sleep-EDF, SHHS, MESA (all PSG-labelled) | unvalidated |
| **Cardio load** | `core/services/cardio_load_service.dart` | `docs/plans/2026-06-26-cardio-load-plan.md` | none — no external ground truth exists | — | unvalidated; inherits HRV + respiratory |
| **Irregular rhythm / AF** | `core/services/ppg_analysis_service.dart`, `services/alerts/irregular_rhythm_rule.dart` | `afib-detection.md` | Awesome-PPG-AF-detection | — | unvalidated; sensitivity/specificity unknown |
| **Fall detection** | `core/processing/fall_detector.dart` | `advanced-health-features.md` §1 | scikit-learn / TFLite baselines | SisFall, MobiFall, UniMiB SHAR | unvalidated |
| **Longevity / phenotypic age** | `ScoreType.longevity` (2) | `longevity-score.md` | BioAge, phenotypic-age-calc | NHANES | unvalidated |
| **Sleep apnea** | not implemented | `sleep-apnea-detection.md` | Apnea-ECG, SHHS | PhysioNet | **not built** — don't discuss as shipping |

Also in `docs/reference/`: `glossary.md` (what each term means),
`ppg-resources.md` (raw PPG datasets + the awesome-ppg and Charlton indexes),
`regulatory-language.md` (**required** before writing any user-facing claim
about a metric).

## Standing warning — blood pressure

`bp_formula.dart` is a port of the vendor SDK's `CalcBloodPressureByHeart`.
Uncalibrated, systolic is:

```
midpoint(100,120) + age_bracket_offset + (hr − 65) × 0.45
diastolic = systolic − 40
```

There is no pressure sensor and no pulse-transit-time term. Uncalibrated BP is
a **deterministic function of heart rate and age** and carries no information
beyond them. Calibrated, it is `cuff_sbp + (hr − hr₀) × 0.45` — anchored to one
real measurement, but every subsequent movement is still only HR moving.

Never describe a BP value as a measurement, and never validate it as one.
Everything downstream inherits this, including the hypertension alert.

## Output format

```markdown
### Metric: <name> = <value>

**1. Base metrics** — <validated inputs / which are unproven>
**2. Algorithm** — spec says <x>, engine produced <y>. <match | mismatch>
**3. Physiologic** — bounds <pass/fail>; cross-metric check vs <other metric> <pass/fail>
**4. Population** — <dataset>: value sits at <where in the distribution>
**5. Literature** — <reference>: metric is <valid / invalid / unestablished> for this use
**6. Adversarial pass** — REQUIRED. A different model should try to refute: <specific claim>

**Verdict:** validated | partially validated | unvalidated | contradicted
**Missing to reach validated:** <list, or "nothing">
```

## Never do these

| Don't | Because |
|---|---|
| "That looks about right" | Not one of the six checks. This is the exact phrase Ryan flagged as non-QA |
| Validate a composite score first | It masks broken inputs and still reads fine |
| Treat "the code matches the spec" as done | Correct code can implement an invalid metric |
| Claim a range is normal from memory | Cite the dataset or don't claim it |
| Mark validated after one pass | Rule 6 is not optional |
| Discuss BP as a measurement | See the standing warning |
