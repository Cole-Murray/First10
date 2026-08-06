---
title: Idempotent state capture vs. view re-entrancy
module: AlarmView/NappingView
problem_type: logic_error
component: state-machine
tags: [state-machine, idempotency, view-lifecycle, connect-iq, re-entrancy, anti-cheat]
symptoms: anti-cheat bypass / timer resets silently on re-entry
severity: high
date: 2026-08-06
---

## Problem

State meant to be captured exactly once (a baseline reading, a start timestamp, a
"have I done X yet" flag) gets silently re-captured or skipped when a view is
re-entered through a path other than the "normal" one the original code assumed —
e.g. `onShow()` firing again on an already-active view instance, or a state-machine
transition that bypasses the step that was supposed to run first.

## Fixed instance

`source/AlarmView.mc`'s `snooze()` allowed a SELECT press during the 4-second
`PHASE_BASELINE` window (`_phase == PHASE_BASELINE`, set in `onShow()` around line 55)
to transition `PHASE_BASELINE -> PHASE_SNOOZE -> PHASE_ACTIVE` without ever reaching
the one-time baseline capture at line 129 (`_score.setBaseline(_baselineSteps, baseHr)`).
Because `_baselineSteps` defaults to 0, the anti-cheat step check then compared the
day's *cumulative* step count against a 0 baseline instead of steps-since-alarm,
trivially satisfying the requirement.

**Fix (commit `1d9ed9c`):** `snooze()` now also blocks during `PHASE_BASELINE`
(`source/AlarmView.mc:83`, condition extended to
`_phase == PHASE_DONE || _phase == PHASE_SNOOZE || _phase == PHASE_BASELINE`), forcing
the 4s capture window to always run to completion before any alternate transition is
reachable.

## Still-open instances of the same root cause (NOT fixed)

Both of these reset session state unconditionally in `onShow()`, with no guard
distinguishing "fresh session start" from "the OS re-showed an already-active view
instance" (e.g. a notification overlay hiding/re-showing the screen mid-alarm or
mid-nap without destroying the view object):

- `source/AlarmView.mc:51-56` — `onShow()` unconditionally sets
  `_alarmStartMs = now`, `_phase = PHASE_BASELINE`, and `_phaseEndMs = now + BASELINE_MS`
  every call. A re-entrant `onShow()` mid-alarm would silently rewind the phase back to
  baseline capture and reset the hard-cap start clock (`_alarmStartMs`, read at line 156
  for the hard-cap check), giving the user extra time or re-running baseline capture with
  stale sensor state.
- `source/NappingView.mc:26-29` — `onShow()` unconditionally sets
  `_startMs = System.getTimer()` (and the derived `_peekUntilMs`), which is read at
  line 48 to compute nap elapsed time. A re-entrant `onShow()` mid-nap would silently
  reset the elapsed-time clock, delaying the alarm.

These are confirmed open — not yet fixed as of this writing.

## The pattern

A guard on one incoming transition (blocking snooze during `PHASE_BASELINE`) closes
that specific path but doesn't generalize to every path that can reach the same view.
The more robust fix is making the *capture itself* idempotent, guarded at the point of
capture rather than at each call site that might skip it, e.g.:

```
if (_alarmStartMs == 0) {
    _alarmStartMs = now;
    _phase = PHASE_BASELINE;
    _phaseEndMs = now + BASELINE_MS;
}
```

## Prevention / application

- Whenever a lifecycle callback (`onShow`, `onStart`, `initialize`) sets state that is
  meant to happen exactly once per logical session, ask "can this callback fire more
  than once for the same session?" before writing an unconditional assignment.
- Prefer guarding the capture itself (`if (fieldStillAtSentinel) { capture() }`) over
  guarding every transition that could otherwise skip it — the latter requires finding
  and fixing every bypass path individually, as this bug demonstrates.
- On Connect IQ specifically, `onShow()` re-entrancy is plausible any time the OS can
  overlay another screen (notifications, incoming calls) on top of an active view
  without destroying it.
