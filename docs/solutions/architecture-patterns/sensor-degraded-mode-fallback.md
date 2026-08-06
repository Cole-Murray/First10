---
title: Sensor-unavailable degraded mode has no fallback
module: SensorManager/AwakeScore/Difficulty
problem_type: architecture_pattern
component: anti-cheat-scoring
tags: [sensor-fallback, degraded-mode, threshold-tuning, connect-iq, heart-rate, weighted-scoring]
severity: medium
date: 2026-08-06
status: open
---

## Problem

`source/SensorManager.mc`'s `SensorManagerImpl.start()` wraps `Sensor.enableSensorEvents(...)`
in try/catch (`source/SensorManager.mc:57-58`), but the catch only logs — nothing
distinguishes three different situations that all currently look identical downstream:

1. the device doesn't support HR at all (a capability check, `heartRateSupported()`,
   `source/SensorManager.mc:36-37`)
2. HR enable was attempted and actually threw/failed
3. HR is supported and enabled but just hasn't produced a reading yet

`AwakeScore.hrScore()` (`source/AwakeScore.mc:96-104`) returns `0.0` whenever `_hr` or
`_baseHr` is `null`, with no time-based grace period and no distinction between "still
warming up" and "never going to arrive."

## Compounding gap: Medium's weights make the "optional" HR signal load-bearing

`source/Difficulty.mc`'s Medium preset sets `wSteps=0.4, wMotion=0.35, wHr=0.25` with
`passMark=90` (constructor around `source/Difficulty.mc:49-54`), and `hrGate=false` —
per its own design comment, HR is meant to be an optional weighted contributor at
Medium, unlike Hard's explicit mandatory gate. But the arithmetic doesn't match that
intent: maxing `stepScore()` and `motionScore()` alone yields
`0.4*100 + 0.35*100 = 75`, seven-eighths of the way but still below the 90 pass mark
required at `AwakeScore.total()` (`source/AwakeScore.mc:107-113`). So Medium requires
*some* nonzero HR contribution in practice despite `hrGate == false`.

If HR never arrives — sensor failure, or simply a wrist that hasn't optically locked on
yet, which is common in the seconds right after waking — both Medium and Hard become
"impossible until the hard-cap timer or the 5x-BACK emergency-dismiss valve fires"
rather than "hard but achievable."

## Status

This is an **open design gap**, not a fixed bug. No code change has been made for it.

## The pattern / lesson

When a system has an optional-vs-mandatory dependency (steps + motion + HR, weighted),
any path that makes the "optional" signal silently required in practice — via
point-weighting math, or via a failure mode with no fallback — defeats the design
intent as surely as a bug in the gate logic itself. The gate flag (`hrGate`) can say
"optional" while the score math says "mandatory," and nothing catches the disagreement
because they're validated independently, if at all.

## Prevention / application

- Whenever difficulty weights or pass marks change, threshold-check the arithmetic:
  compute the max score reachable from every subset of components (e.g. steps+motion
  only, motion+HR only) against the pass mark, not just the max reachable from all
  components combined.
- Decide a deliberate degraded-mode policy for sensor failure rather than letting it
  fall out implicitly from unrelated weighting code — e.g. renormalize the remaining
  weights when a sensor is confirmed dead (distinguish "confirmed dead" from "not yet
  reporting" using a grace period), or accept a soft floor and surface the degraded
  state in the UI so the user isn't stuck against an invisible wall.
- Distinguish, in `SensorManager`, "capability absent" vs. "enable failed" vs. "enabled,
  awaiting first reading" — collapsing these into one null/zero state is what let this
  gap go unnoticed.
