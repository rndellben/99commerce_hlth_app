## On the quality gate — it has a dangerous blind spot

The three checks (beat-coverage ≥60%, HR cross-check within 30%, ectopic ≤20%) are reasonable, but they share one critical flaw that directly explains your earlier 22 br/min artifact:

None of them gate on interpolated-sample fraction.

Look at what happens. Your earlier capture had 12% interpolated samples and it passed all three checks:

- Beat coverage: 117 of ~119 → ~98%, passes easily.
- HR cross-check: PPG-derived HR matched the band, passes.
- Ectopic: 0.9% ≪ 20%, passes.

So the gate said PASS on a capture that was 1-in-8 synthetic data, and the respiratory estimator then read modulation off those interpolated points. The bouncer is checking IDs but not noticing that an eighth of the crowd is mannequins.

The three existing checks all validate the cardiac/beat layer. They say nothing about whether the timing substrate underneath the beats is real — which is exactly what RSA-based respiration depends on.

## Proposed gate fix

Add a fourth check, and make it respiration-specific:

1. New check — real-sample density. Reject (or suppress respiratory output only) if interpolated fraction exceeds a threshold. I'd start at 8% and tune. Critically, check it in a sliding window, not just the whole-capture average — 12% spread evenly is survivable, but 12% clustered into a 10-second burst destroys any respiratory estimate landing in that window.
2. Decouple the verdict from a single PASS/REJECT. Right now it's all-or-nothing: pass and everything saves, fail and nothing saves. Better is per-metric gating. Cardiac/HRV metrics can tolerate more interpolation than RSA respiration can. So:
    
    - HR / HRV: save if the three existing checks pass.
    - Respiratory rate: save only if existing checks pass AND interpolated fraction is low AND the respiratory peak isn't co-located with the packet-loss cadence.
3. This way a moderately gappy capture still gives you a trustworthy recovery/HRV number without emitting a fabricated breathing rate.
4. Emit a confidence score, not just a boolean. Pass the interpolation fraction and contact-blank count through to the app so a borderline respiratory value renders as "—" or low-confidence rather than a falsely precise "22.0."

This is the highest-priority fix because it's the difference between rejecting junk and silently saving plausible-looking junk — which is worse.

## On the BLE loss — agree with the lever, disagree with the framing

Your Claude Code nailed the root cause: the SDK never calls `requestConnectionPriority` or `requestMtu`, so you're running at Android's default ~30–50 ms interval against a ~28 sample/sec stream. That's a genuine, high-leverage finding. Try HIGH connection priority first — correct call.

But I want to push back on one line, because it interacts badly with the gate problem above:

> "our counter-based timing already interpolates the gaps, so metrics survive moderate loss — getting under 7% mainly raises the capture pass-rate."

This undersells it. The interpolation that "saves" your metrics is the same interpolation that fabricated your 22 br/min. Reducing BLE loss isn't just about pass-rate — it directly improves respiratory accuracy by shrinking the synthetic fraction the RSA estimator has to swallow. The two issues are the same issue viewed from two ends of the pipeline. Framing BLE loss as merely a convenience win is what let the gate stay lenient.

## Suggested BLE sequence (cheapest → most invasive)

1. HIGH connection priority via reflection — the quick experiment. Worth doing today. Expect the biggest single drop in loss.
2. `requestMtu(247)` if you can reach the handle — fewer, larger packets means less per-packet overhead and queue pressure. Often pairs well with #1.
3. Free environmental wins in parallel — RSSI −77 is genuinely weak; getting to ~−60 (phone within 1 m, same side, foreground + screen on) is real and free. Bake the "phone foreground, keep close" guidance into the capture UI itself.
4. If reflection fails — ask the vendor to flip HIGH priority + MTU in the SDK. Low-cost ask, high payoff.
5. Acknowledged/windowed transfer or on-device buffering — this is the only thing that gets you near-zero, but it's firmware/vendor. Park it as the long-term ceiling-raiser, not the first move.

One caution on the reflection approach: reaching into the SDK's private BLE handle can break on SDK updates and on some Android OEM stacks. Wrap it in a try/catch that degrades gracefully to default behavior, and log whether HIGH priority actually got applied so you can measure the before/after loss delta cleanly.

## How I'd sequence the whole thing

1. Today: add the interpolation-fraction gate (sliding-window) and split respiratory gating from HRV gating. This stops fabricated respiratory values immediately, regardless of BLE progress.
2. Today, in parallel: try HIGH connection priority via reflection; measure loss before/after on a controlled capture.
3. This week: switch the respiratory estimator to a gap-aware method (Lomb-Scargle on real beats only) so it's robust to whatever loss remains. Add the packet-loss-cadence rejection check.
4. Ongoing: environmental guidance in the capture UI; vendor conversation for MTU/priority and eventually acknowledged transfer.

The mental model: BLE work reduces how much synthetic data enters the pipeline; the gate + Lomb-Scargle work make the pipeline honest about whatever synthetic data still gets through. You want both — fixing only one leaves you either rejecting too many captures or saving too many fake ones.