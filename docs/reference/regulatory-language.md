---
categories:
  - "[[Web-Tech]]"
subjects:
  - "[[HLTH]]"
focus_area: regulatory compliance
status: draft
created: 2026-04-26
---

# HLTH Smartband — Regulatory Language Guide

## The Rule

As of January 2026, FDA's revised General Wellness guidance allows wearables to measure physiological parameters (HR, HRV, SpO2, BP, etc.) as wellness products IF:

1. The device does NOT claim to diagnose, treat, cure, or prevent any disease
2. The device does NOT name specific medical conditions in user-facing content
3. The device does NOT characterize outputs as "abnormal" or "concerning"
4. The device does NOT guide clinical decision-making
5. Outputs are framed as wellness information, not medical data

One wrong word in the app UI, marketing copy, or App Store listing could reclassify the device as a medical device — triggering FDA 510(k) requirements ($50K-150K+ and 12-18 months).

---

## Feature-by-Feature Language Guide

### Irregular Rhythm Detection (AFib Feature)

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Atrial fibrillation | Irregular rhythm |
| AFib detected | Irregular rhythm notification |
| Arrhythmia detected | Unusual heart rhythm pattern |
| You may have AFib | Your heart rhythm appears irregular |
| Diagnosis | Notification / insight |
| Abnormal heart rhythm | Heart rhythm that differs from your usual pattern |
| AFib screening | Heart rhythm monitoring |
| Medical-grade ECG | Optical heart rhythm sensor |

**App notification (approved):**
> "Irregular heart rhythm detected. Multiple readings over the past hour show an unusual pattern. Consider consulting your healthcare provider."

**App notification (NOT approved):**
> ~~"Possible atrial fibrillation detected. This is a serious heart condition. Seek medical attention."~~

---

### Breathing Disruption Detection (Sleep Apnea Feature)

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Sleep apnea | Breathing disruptions during sleep |
| Apnea events | Breathing pauses |
| Apnea-Hypopnea Index (AHI) | Disruption count per hour |
| Hypopnea | Shallow breathing episode |
| Obstructive sleep apnea | Breathing irregularities during sleep |
| Sleep apnea screening | Sleep breathing analysis |
| Mild/moderate/severe apnea | Frequent / occasional breathing disruptions |
| Diagnosis of sleep disorder | Sleep breathing insight |

**App notification (approved):**
> "Your sleep breathing analysis detected frequent pauses last night — 18 disruptions per hour across 2 nights. Many people find it helpful to discuss sleep breathing patterns with their doctor."

**App notification (NOT approved):**
> ~~"You may have moderate sleep apnea (AHI: 18). This condition increases your risk of heart disease. See a sleep specialist."~~

---

### Blood Pressure

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Blood pressure diagnosis | Blood pressure reading / estimate |
| Hypertension detected | Elevated blood pressure trend |
| You have high blood pressure | Your blood pressure has been trending above your baseline |
| Pre-hypertensive | Higher range of your readings |
| Prescribe / adjust medication | Discuss with your healthcare provider |
| Clinically accurate | Validated for wellness use |
| Medical-grade BP monitor | Wellness blood pressure tracker |

**App display (approved):**
> "Blood Pressure Estimate: 138/88 mmHg — Calibrated reading. Your 7-day trend shows readings above your personal baseline. Consider discussing with your healthcare provider."

**App display (NOT approved):**
> ~~"WARNING: Stage 1 Hypertension Detected (138/88). You should consult a doctor immediately."~~

---

### Recovery / Readiness Score

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Medical recovery assessment | Readiness score |
| Clinically recommended rest | Your body signals suggest rest may be beneficial |
| Overtraining syndrome | Elevated strain pattern |
| Medical fatigue | Recovery indicators are low |

This feature has LOW regulatory risk — it's clearly wellness. Keep framing as fitness/performance guidance.

---

### Respiratory Rate

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Abnormal respiratory rate | Respiratory rate outside your usual range |
| Respiratory distress | Elevated breathing rate |
| Tachypnea / bradypnea | Faster / slower breathing than your baseline |

LOW regulatory risk. Just avoid clinical terminology.

---

### VO2 Max

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Clinical fitness assessment | Estimated cardio fitness level |
| Diagnostic fitness test | Fitness estimate |

VERY LOW regulatory risk. All competitors ship this freely.

---

### Respiratory Illness Warning

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| COVID detected | Body signals have shifted from your baseline |
| Flu detected | Signs of elevated physiological stress |
| You're getting sick | Your body may be responding to something |
| Infection warning | Wellness alert |
| Pre-symptomatic illness | Unusual vital sign pattern |
| Disease detection | Body stress indicator |
| Diagnose any illness | This is not a medical diagnosis |

**App notification (approved):**
> "Your overnight vitals have shifted from your personal baseline for 2 consecutive days — elevated resting heart rate and reduced HRV. Consider extra rest and monitor how you feel. This is a wellness observation, not a medical diagnosis."

**App notification (NOT approved):**
> ~~"Pre-symptomatic infection detected. Based on your vital signs, you may be developing a respiratory illness. Get tested."~~

---

### Mental Wellness Trends

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Depression detected | Lower wellness balance this week |
| Anxiety indicators | Elevated stress signals |
| Mental health diagnosis | Body harmony / wellness balance |
| Psychiatric assessment | Wellness trend |
| You may be depressed | Your body signals suggest elevated stress |
| Mental illness | Wellness pattern |
| Clinical stress | Body stress indicators |

**HIGHEST REGULATORY SENSITIVITY.** Mental health claims are scrutinized heavily. Never imply the device can detect, diagnose, or screen for mental health conditions.

**App display (approved):**
> "Wellness Balance: 42/100. Your HRV has been below your baseline this week, and your sleep consistency has decreased. Small changes like a regular bedtime or a daily walk can support your body's natural balance."

**App display (NOT approved):**
> ~~"Depression Risk: Elevated. Your biometrics indicate possible depressive episode. Consider seeking professional help."~~

---

### Longevity / Biological Age Score

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Predicts disease risk | Reflects overall wellness trends |
| Medical age assessment | Body age estimate |
| Clinically validated age | Wellness-based body age |
| You will develop X disease | Your body signals suggest room for improvement in X |
| Mortality prediction | Longevity wellness indicator |
| Disease risk score | Vitality score |

**App display (approved):**
> "Your Body Age: 34 (Chronological: 41). Based on your heart health, sleep quality, fitness, and recovery patterns, your body signals reflect wellness patterns typically seen in someone 7 years younger. Keep it up!"

**App display (NOT approved):**
> ~~"Biological Age: 34. Your cardiovascular age predicts 2.3x lower risk of heart attack compared to someone with an accelerated aging profile."~~

---

### Arterial Stiffness / Vascular Age

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Arteriosclerosis detected | Arterial flexibility trend |
| Vascular disease risk | Vascular wellness indicator |
| Hardening of the arteries | Changes in arterial flexibility |
| Cardiovascular disease prediction | Heart and vessel wellness trend |

---

### Cardiac Output Trends

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Heart failure indicator | Heart efficiency trend |
| Cardiac insufficiency | Your heart's pumping efficiency |
| Reduced cardiac output | Lower heart efficiency readings |
| Clinical cardiac assessment | Heart performance trend |

---

### Fall Detection

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Injury detected | A possible fall was detected |
| Medical emergency | Fall alert |
| Fracture risk | N/A — don't assess injury type |

LOW regulatory risk. Apple, Samsung, and others ship this. Just don't assess injury severity.

---

### Menstrual Cycle Tracking

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Ovulation detected | Estimated mid-cycle window |
| Fertility window | Cycle phase estimate |
| Contraceptive tool | Cycle awareness feature |
| Pregnancy indicator | N/A — never imply pregnancy detection |
| Medical cycle tracking | Cycle wellness insights |

**Do NOT position as contraception or fertility planning.** Natural Cycles went through FDA clearance specifically to make contraceptive claims. We avoid this entirely.

---

### Sleep Staging

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Sleep disorder detected | Sleep pattern insight |
| Insomnia diagnosis | Sleep efficiency has been lower than your baseline |
| Clinically validated sleep score | Sleep wellness score |

LOW regulatory risk. All competitors ship this.

---

### SpO2

| NEVER Say | ALWAYS Say Instead |
|-----------|-------------------|
| Hypoxemia detected | Blood oxygen below your usual range |
| Diagnosing low oxygen | Blood oxygen wellness reading |
| Prescribe supplemental oxygen | Consider discussing with your healthcare provider |
| Clinical pulse oximetry | Wellness blood oxygen monitoring |

---

## App Store / Marketing Language

### App Store Description (Approved Template)

> "HLTH tracks your body's signals to help you understand your wellness trends. Monitor your heart rhythm, blood pressure, blood oxygen, sleep quality, recovery, fitness, and body age — all from your wrist.
>
> Features include heart rhythm monitoring, sleep breathing analysis, cardio fitness estimation, daily recovery scoring, body age tracking, cycle awareness, and wellness alerts.
>
> HLTH is a wellness product. It is not a medical device and is not intended to diagnose, treat, cure, or prevent any disease. Always consult your healthcare provider for medical advice."

### Required Disclaimers

**Every feature screen should include (in small text at bottom):**
> "This is a wellness feature, not a medical device. Not intended to diagnose, treat, or prevent any condition. Consult your healthcare provider for medical advice."

**App Store listing must include:**
> "HLTH is a general wellness product. It does not provide medical diagnoses."

**Marketing materials must NOT include:**
- "FDA-cleared" (unless you actually go through clearance)
- "Medical-grade"
- "Clinically proven" (unless you have a published clinical study)
- "Detects [any disease name]"
- "Screens for [any condition]"
- Testimonials claiming the device diagnosed anything

---

## Summary: The Three Rules

1. **Never name a disease** — say "pattern" or "trend" instead
2. **Never say "abnormal"** — say "different from your baseline" instead
3. **Always include the disclaimer** — "not a medical device, consult your provider"

If every notification, screen, and marketing line passes these three rules, you stay in the wellness lane.
