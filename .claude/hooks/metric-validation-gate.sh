#!/usr/bin/env bash
# UserPromptSubmit hook — injects the metric-validation protocol when a prompt
# references a health metric or a measured value.
#
# Rationale: "the AI said it looks fine" is not QA (Ryan, Aug 1 call). This
# makes the evidence requirement arrive with the prompt instead of depending on
# the model remembering to look it up.
#
# Fires on: any metric name, OR a number immediately followed by a physiological
# unit (42 ms, 68 bpm, 118 mmHg). Deliberately NOT on bare numbers — "line 42"
# and "3 files" would fire on nearly every prompt, and a noisy hook gets turned
# off. Reads hook JSON on stdin; prints nothing when there is no match.
set -uo pipefail

prompt=$(jq -r '.prompt // empty' 2>/dev/null) || exit 0
[ -n "$prompt" ] || exit 0

METRIC='hrv|rmssd|sdnn|resting[ _-]?hr|heart[ _-]?rate|respirat|spo2|blood[ _-]?oxygen'
METRIC="$METRIC"'|blood[ _-]?pressure|systol|diastol|vo2|recovery[ _-]?score|readiness'
METRIC="$METRIC"'|stability[ _-]?score|cardio[ _-]?load|vascular[ _-]?load|mental[ _-]?wellness'
METRIC="$METRIC"'|stress[ _-]?score|sleep[ _-]?score|sleep[ _-]?stage|deep[ _-]?sleep|longevity'
METRIC="$METRIC"'|phenotypic|afib|a-fib|atrial|irregular[ _-]?rhythm|fall[ _-]?detect'
UNITNUM='[0-9]+(\.[0-9]+)?[[:space:]]?(bpm|ms|mmhg|br/min|breaths)'

printf '%s' "$prompt" | grep -qiE "($METRIC|$UNITNUM)" || exit 0

read -r -d '' CONTEXT <<'EOF'
METRIC VALIDATION REQUIRED — this prompt references a health metric or a measured value.

Before calling any metric value correct, accurate, normal, plausible, or "about right",
name in the SAME message:
  1. the algorithm it was checked against (specs are in docs/reference/)
  2. the clinical reference establishing the metric is valid for this use
  3. the population dataset or physiologic bound it was compared against

Cannot name all three? The answer is "unvalidated" plus what is missing. That is a
useful answer. Reading the engine and finding it self-consistent is NOT validation —
correct code can implement a metric that measures nothing (LF/HF, Billman 2013).

Also required:
  - Validate BASE metrics before composites. Recovery / Cardio Load / Wellness /
    Longevity read plausible while their inputs are broken.
  - Run the cross-metric possibility check (canonical bug: respiratory rate 12
    while HR is 130 — impossible, so it is a quality-gate failure).
  - State that a DIFFERENT model must try to refute the conclusion. One pass
    never marks something validated.

Full protocol and the per-metric reference map: invoke the `metric-validation` skill.
Blood pressure is a deterministic function of HR and age, not a measurement — see CLAUDE.md.
EOF

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
