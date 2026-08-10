# Recovery / Stability — Validation Report (v2)

This document validates the rebuilt **Recovery / Stability** metric. Every number
below is produced by a script in this directory and is reproducible from scratch:

| What | How to reproduce |
|---|---|
| Headline real-night score + knob sweep + maturity + confidence | `python3 _run_validation.py` |
| Cross-language (Python ↔ Dart) parity, 6 scenarios | `python3 _parity_check.py` |
| Holistic activity-context proof | `python3 ../../holistic_proof.py` |
| Reference model on the real night | `python3 recovery_stability_reference.py` |

> All scripts must be run **from this directory** (relative import of
> `recovery_stability_reference`). There is no Dart toolchain in this environment;
> cross-language parity is verified by `_parity_check.py`, a faithful Python twin
> of `recovery_stability.dart`, field-by-field.

---

## 1. What changed vs. the prior (superseded) design

The previous version scored Recovery from a **single night** against a baseline.
That was wrong on two counts that the project owner corrected explicitly:

1. **Architecture.** Recovery / Stability is derived from **4 nights of sleep**,
   with the night before the score is revealed weighted highest, read against the
   **last ≤14 worn-valid sleeps** as a rolling baseline — *not* 14 calendar days,
   and *not* a single night. This mirrors the shipped **Vascular Load**
   architecture (`vascular_load-1.dart`: `_windowN=4`, `_lastNightWeight=0.40`,
   `_baselineMax=14`, robust-z floors, ±3 z-clamp, cold-start hard-lock).
2. **Holism.** Prior-day activity is *not* a gate that simply discards data — it is
   **necessary context** for interpreting autonomic signals. A drop in HRV after a
   hard training day is expected and should be *forgiven*; the same drop with no
   training load is a genuine red flag. The metric is a holistic measurement, not a
   siloed one.

The v2 model (`recovery_stability_reference.py`, ported line-for-line to
`recovery_stability.dart`) implements both corrections.

---

## 2. The three locked design decisions

### Q1 — Last-night weight = **0.50**, with tuning knobs 0.40 / 0.60

Recovery answers *"how ready am I on waking today?"* — a state dominated by the
night you just had — whereas Vascular Load measures cumulative strain and is
deliberately calmer (0.40). So Recovery weights last night more heavily.

Responsiveness scales with the weight. From the per-night impact analysis
(points moved per robust-z of the latest night, all else equal):

| last-night weight | responsiveness (pts / robust-z) | character |
|---|---|---|
| 0.25 | 3.75 | all four nights equal — most stable |
| **0.40** | 6.0 | Vascular-Load default (calm) — **low knob** |
| **0.50** | 7.5 | Recovery default — **locked** |
| **0.60** | 9.0 | nearly single-night — **high knob** |

Config: `last_night_weight=0.50`, `last_night_weight_low=0.40`,
`last_night_weight_high=0.60`. Sweep on the real night (from `_run_validation.py`):

```
last_night_weight=0.40 -> raw=45.3  score=64.6
last_night_weight=0.50 -> raw=44.6  score=64.4   (locked default)
last_night_weight=0.60 -> raw=43.8  score=64.2
```

(The spread is small on *this* night because tonight's composite, 40.97, sits close
to the 4-night window mean; the sweep widens on nights that diverge from the window.)

### Q2 — RMSSD drives the score; everything else is confidence / artifact-rejection

This is the clinically-grounded division of labor:

- **RMSSD is the score-driving HRV field.** It is the preferred field-recovery HRV
  metric — short-window, parasympathetically dominated, the standard for overnight
  readiness ([*Sensors* 2025, PMC12787763](https://pmc.ncbi.nlm.nih.gov/articles/PMC12787763/)).
- **LF/HF is telemetry-only — never scored.** It is invalid as a "sympathovagal
  balance" index ([Billman, *Frontiers in Physiology* 2013, PMC3576706](https://pmc.ncbi.nlm.nih.gov/articles/PMC3576706/))
  and aliases catastrophically under slow sleep breathing, so feeding it into a
  recovery score would inject noise dressed up as signal.
- **SDNN, ectopic %, R-R irregularity (CoV %), the PPG quality gate, and BLE-loss %
  are confidence / artifact-rejection signals — not score inputs.** RMSSD is the
  most physiologically meaningful HRV field *and* the most fragile: ~10% ectopy
  inflates RMSSD ≈237% vs SDNN ≈96%, and consumer-PPG noise inflates RMSSD ≈26.5%
  vs SDNN ≈10.7%. So the robust fields *guard* RMSSD rather than competing with it.

This was vindicated by the project owner's own raw PPG capture: raw RMSSD read
**112 ms**, but after dropping 5 ectopic beats the true RMSSD was **30.1 ms** — a
~3.7× error that the confidence/artifact layer is specifically designed to catch.

In code: HRV scoring uses `hrv_rmssd_ms` only; SDNN/ectopic/R-R-CoV/quality-gate/
BLE-loss flow through `_nightly_confidence()` (PPG-aware) and never into the score.

### Q3 — Activity-adjusted expectations work in **both directions**

The activity modifier (`_activity_adjust_z`, `enable_activity_modifier=True`) shifts
the *expected* autonomic center by the prior day's activity load (a personal-relative
robust-z of active-minutes, steps fallback), in **both** directions:

- **Forgive dips.** When activity load is high, a below-expectation HRV/deep/HR
  signal is pulled back toward neutral — `forgive = min(signal_z + shift·activity_z, 0)`
  with `activity_expectation_shift=0.45`. A dip you'd expect after training is not
  punished as if it were spontaneous.
- **Cap euphoric highs.** When the day was genuinely hard
  (`activity_z ≥ activity_hard_z=0.75`), an *above*-expectation HRV/HR/deep spike is
  capped — `cap = signal_z · activity_euphoria_cap_frac (0.50)` — because
  post-exertion vagal rebound is **not** the same as being fully recovered.

Resp rate is deliberately **excluded** from activity adjustment: an elevated sleeping
respiratory rate is a clinical red flag (illness, strain, poor air) regardless of
training, so it is never "forgiven."

---

## 3. Headline result — the real night (2026-06-22)

Input is the device's **authoritative raw totals** from `Sleep-Data.md`
(deep 106 / light 372 / REM 80 / awake 8 min → **sleep = 558 min**), today's
aggregate row (resting HR 69, resp 16.9, efficiency 0.93, active-min 0, steps 54),
and the personal baseline (RMSSD mean 49.9 n=8; resting-HR 66.4 n=13; resp 11.1 n=4).
Tonight's **HRV reading is absent (`—`)** in the real pull.

```
status=produced  provisional=False  confidence=0.82
raw=44.6  score=64.4  label=Good
debug: windowed=44.57  window_n=4  baseline_n=13  last_night_weight=0.5
       tonight_composite=40.97  tonight_activity_z=-2.74
       night_scores=[40.8, 48.8, 54.9, 41.0]
component breakdown (tonight):
  deep  56.67  w_eff 0.3750   deep 106m vs baseline 98m  z=+0.44
  rem   43.32  w_eff 0.2500   REM 14.3% vs baseline 15.6%  z=-0.45
  hrv   50.00  w_eff 0.0000   [REDISTRIBUTED] RMSSD missing
  hr    33.40  w_eff 0.1875   HR 69 vs baseline 64  z=-1.11
  resp  14.00  w_eff 0.1875   RR 16.9 vs baseline 10.9  z=-3.00
```

**Honesty note (critical):** because tonight's HRV is genuinely absent, the HRV
component is dropped and its 0.20 weight is **redistributed** across the remaining
available components (deep, REM, HR, resp) — the effective weights shown above sum
to 1.0. **The HRV value is never fabricated.** A prior session's invented "62.2"
HRV-derived figure was a known failure mode; this build refuses to invent missing
physiology and instead lowers `confidence` to **0.82** to reflect the gap (one
missing core component → `1 − 0.18 = 0.82`, times the nightly PPG-aware confidence).

The score of **64.4 (Good)** is carried largely by an above-baseline deep-sleep night
(106 vs 98 min) inside the 4-night window, tempered by an elevated resting HR and a
notably elevated sleeping respiratory rate (16.9 vs 10.9 baseline → the floor of the
resp component). That is the correct, defensible reading of the data we actually have.

---

## 4. Maturity / cold-start (Vascular-Load parity)

Like Vascular Load, the score is hard-flagged **provisional** until the baseline
matures (`min_valid_nights_for_score=4`). From `_run_validation.py`:

```
banked=  1 -> status=calibrating  provisional=True   conf=0.66
banked=  2 -> status=calibrating  provisional=True   conf=0.66
banked=  4 -> status=produced     provisional=False  conf=0.82
banked= 13 -> status=produced     provisional=False  conf=0.82
```

Provisional confidence is additionally multiplied by 0.8, so the same night reads
conf 0.66 while calibrating and 0.82 once mature.

---

## 5. Cross-language parity (Python reference ↔ Dart port)

`_parity_check.py` runs six deliberately adversarial scenarios through the Python
reference and a faithful Python twin of the Dart implementation, comparing **17
fields** each (raw, score, label, confidence, override, provisional, all five
component scores + effective weights, activity-z, etc.):

```
[PASS] S1 normal mature          ref=57.2  dart=57.2   (17 fields)
[PASS] S2 suppressed+hard         ref=45.8  dart=45.8   (17 fields)
[PASS] S3 euphoric+hard           ref=53.8  dart=53.8   (17 fields)
[PASS] S4 cold-start+artifacts    ref=47.3  dart=47.3   (17 fields)
[PASS] S5 HRV-absent lowknob      ref=64.8  dart=64.8   (17 fields)
[PASS] S6 highknob+tachypnea      ref=20.9  dart=20.9   (17 fields)

PARITY: 6/6 scenarios match across all fields.
```

The scenarios exercise: the both-directional activity modifier (S2 forgiveness,
S3 euphoria cap), cold-start with PPG artifacts (S4), HRV-absent with the low knob
(S5), and the high knob + tachypnea override path (S6, resp > 20 forces the
multi-signal decline override and drops the score to 20.9).

---

## 6. Holistic proof — same physiology, divergent scores by activity context

`holistic_proof.py` holds the **overnight physiology identical** (HRV 35 ms vs ~50
baseline, deep 66 m vs 95, HR 62 vs 58) and varies **only the prior day's activity**:

```
scenario                                    | score | act_z |  hrv | deep |   hr
Sedentary day (5 active-min, 1,200 steps)   | 37.5  | -2.28 |  9.2 |  5.0 | 33.7
Normal day    (30 active-min, 8,000 steps)  | 38.1  | +0.22 | 10.7 |  6.5 | 35.2
Hard training (120 active-min, 18,000 steps)| 44.2  | +3.00 | 29.4 | 25.2 | 50.0

=> Same suppressed physiology -> sedentary 37.5 vs hard-training 44.2 (+6.7 pts).
   The hard-training day FORGIVES the autonomic dip; the sedentary day scores the
   SAME dip as a genuine red flag.
```

And the **euphoria cap** (an above-baseline HRV night, RMSSD 72 vs ~50):

```
euphoric HRV after a NORMAL day : score=56.8  hrv_comp=82.2  act_z=-0.78
euphoric HRV after a HARD  day  : score=53.7  hrv_comp=66.1  act_z=+3.00
=> the post-hard euphoric spike is CAPPED (-3.1 pts; hrv_comp 82.2 -> 66.1),
   so the metric does NOT flash "fully recovered" on a vagal-rebound night.
```

This is the holistic behavior the project owner required: identical sensor readings
produce *different, context-correct* recovery scores depending on what the body was
asked to do the day before — in both the forgiving and the cautionary direction.

---

## 7. What the device stores between sessions

Per the on-device constraint (aggregates only, all computation local, no cloud), the
persisted struct is the tiny `RecoveryNightlyRecord` (nightly aggregates +
PPG-derived confidence fields). **No raw PPG waveforms are stored.** Raw PPG is read
at capture time to compute the richer HRV / artifact-rejection fields and is then
reduced to the small record; the daily score reads tonight + the previous 3 valid
records against the rolling ≤14-night baseline.

---

## Clinical references

- HRV field-recovery metric selection (RMSSD primary): *Sensors* 2025 —
  [PMC12787763](https://pmc.ncbi.nlm.nih.gov/articles/PMC12787763/)
- LF/HF invalid as sympathovagal index: Billman, *Frontiers in Physiology* 2013 —
  [PMC3576706](https://pmc.ncbi.nlm.nih.gov/articles/PMC3576706/)
- HRV metric robustness under noise / slow-breathing aliasing benchmark (2026) —
  [clawrxiv.io/abs/2604.01619](https://clawrxiv.io/abs/2604.01619)
