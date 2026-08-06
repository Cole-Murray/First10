# First10 — Improvement Ideas (Post-v1 Research)

Researched after the first code review closed out (see `CLAUDE.md` Known Issues and
`docs/solutions/`). Every technical claim below was checked against the **installed
Connect IQ SDK 9.2.0 docs** on this machine (`%APPDATA%\Garmin\ConnectIQ\Sdks\...\doc\`) —
not just web sources — because the SDK docs are ground truth for what actually exists at the
API level this project targets (`minApiLevel 3.4.0`, FR265/FR265S). Web research (Garmin forums,
DC Rainmaker, peer-reviewed sleep-actigraphy literature) supplied real-world behavior, hardware
specs, and user-demand signals that the API reference alone can't tell you.

**Framing insight worth stating up front:** the research turned up no other Connect IQ nap/alarm
app that gates dismissal on live biometric proof (steps + sustained motion + HR rise). Every
comparable app found (Power Napp, Nap till rested, several "SmartAlarm" clones) is a passive
timer or a phase-timing guess — none require you to *prove* you're up. First10's anti-cheat core
is the genuinely differentiated part already. The ideas below are chosen to sharpen that core or
extend it into adjacent, validated user demand — not to bolt on unrelated "smart watch" features.

---

## Tier 1 — strengthens the existing core, low effort, high confidence

### 1. Use `UserProfile` resting HR as a cross-check for the on-wrist baseline

**What:** `AlarmView`'s `PHASE_BASELINE` currently measures resting HR from a noisy 4-second
on-wrist sample taken the moment the alarm fires — exactly the least reliable window for optical
HR (per this session's own `docs/solutions/architecture-patterns/sensor-degraded-mode-fallback.md`
finding). `Toybox.UserProfile.Profile` exposes `restingHeartRate` (user-configured, API 1.0.0) and
`averageRestingHeartRate` (Garmin's own 7-day rolling calculation, API 3.2.0, may be `null`).
Either is a statistically sturdier baseline than a 4-second sample taken right after waking.

**How it'd fit:** if `averageRestingHeartRate` is available and the live 4s baseline seems
implausible (e.g. HR count too low, or wildly different from the profile value), prefer the
profile value — or simply blend them. Doesn't replace the live measurement (which still matters
for the moment-of-wake state); supplements it.

**Feasibility — verified:**
- Both fields confirmed present in the local SDK doc, at API levels below this project's
  `minApiLevel 3.4.0` — always available, no `has()` gate strictly required (though this
  codebase already uses defensive `has` checks pervasively in `SensorManager.mc`, so match that
  convention anyway).
- **Requires a new manifest permission: `UserProfile`** (confirmed from `Toybox/UserProfile.html`
  — not currently declared in `manifest.xml`, which only lists `Sensor` today). Small, honest
  cost — one more permission line, one more thing a user/reviewer sees.
- `averageRestingHeartRate` can be `null` (insufficient data) — must null-check, same pattern
  `AwakeScore.mc` already uses everywhere.

**Effort:** low (one API call + a manifest line + a null check). **Risk:** low.

---

### 2. Persisted nap history (no gamification)

**What:** Garmin's own wellness features don't track naps as a distinct thing — Body Battery
and Training Readiness are keyed off one configured overnight sleep window, and multiple Garmin
forum/community threads (surfaced independently, not just anecdote) name this as a known,
recurring complaint: naps don't count toward recovery, and nothing tracks how many you take.
First10's `SummaryView` already computes per-nap stats (time-to-wake, steps, HR rise,
safety-dismiss flag) and then discards them. Persisting a rolling history turns First10 into the
one place that *does* track naps distinctly — a real, validated gap, not a guess.

**How it'd fit:** append each `SummaryView` session's stats to a small rolling buffer in
`Application.Storage`. Show a simple aggregate on the Summary screen or a new small view: naps
this week, average time-to-wake, pass-vs-safety-dismiss ratio. **Deliberately no streaks, badges,
or "don't break your streak" mechanics** — the research here was explicit: streak mechanics have
a well-documented "abandon and never come back" failure mode (industry data: ~1% of users who
break a 2-3 day streak resume it), and that evidence base is drawn almost entirely from
*daily-habit* apps (meditation, steps). A nap alarm is inherently occasional/situational — the
opposite usage pattern — so streak-guilt is a plausible net negative here, not a proven positive.
Simple stats, no punishment mechanic.

**Feasibility — verified:** `Application.Storage` needs no new permission (already used by
`Settings.mc`). SDK 2.4+ raised the budget to roughly 100KB total / 8KB per item — a rolling
buffer of, say, the last 20-30 nap records is trivially within that.

**Effort:** low-moderate (a small struct/array in Storage, one aggregation function, minor
SummaryView addition). **Risk:** low.

---

## Tier 2 — genuinely differentiating, real demand, higher effort, honest caveats

### 3. Body-Battery-aware nap-length suggestion at Setup

**What:** at `SetupView`, if Body Battery data is available, use it to pre-select a suggested nap
length instead of (or blended with) "last used" — e.g. lower Body Battery nudges toward a longer
suggested nap; well-rested nudges toward a short 20-minute refresher. The duration bands
themselves (10-20 min avoids sleep-inertia grogginess; ~90 min completes a full sleep cycle) are
uncontroversial, widely-cited general sleep-hygiene facts, not a novel claim — the app is just
using a real signal to pick a smarter default. The user can always override on the same screen
they already use today.

**Feasibility — verified:**
- `Toybox.SensorHistory.getBodyBatteryHistory()` confirmed present, API 3.3.0 (below
  `minApiLevel`), and confirmed by real developer forum reports to actually populate on real
  hardware (not simulator-only).
- **Two real gotchas found in Garmin's own developer forums, both must be defended against:**
  devices commonly return the sentinel value `127` to mean "not currently measurable" rather than
  raising an error — treat it as "unavailable," not a real reading. Separately, the iterator's
  `getOldestSampleTime()`/`getNewestSampleTime()` are reported unreliable — don't trust them to
  bound a scan; just iterate and take the newest valid (non-sentinel) sample.
- **Requires a new manifest permission: `SensorHistory`** (confirmed — not currently declared).
- Degrades gracefully to today's "last used" default if the API/data isn't available — this is
  an enhancement layered on the existing default, not a replacement that can fail hard.

**Effort:** moderate (new permission, defensive iterator handling per the gotchas above, a
suggestion-blend function on `SetupView`). **Risk:** low-moderate — mostly around correctly
handling the documented data-quality issues; the underlying idea itself is low-risk since it only
ever changes a *pre-selected default*, never gates the anti-cheat logic.

---

### 4. "Wake at first stirring" early-wake window — biggest payoff, biggest architecture change

**What:** a smart/light-sleep alarm is, per independent research, the single most-requested
Garmin feature historically (surfaced from Garmin's own community feature-request tracking, not
just this session's assumption). The honest version First10 could plausibly build: within the
last N minutes of a nap (a configurable "wake window," same concept Sleep Cycle/Alarmy use on
phones), start low-frequency accelerometer sampling; if sustained motion crosses a threshold
during that window (a sign of natural stirring — lightening sleep or already waking), trigger the
alarm early instead of waiting for the fixed end time.

**This must be honestly scoped, and this is the most important caveat in this whole document:**
peer-reviewed validation of wrist-actigraphy sleep classifiers shows roughly 86% *overall*
accuracy for the binary asleep/awake call, but only ~33% *specificity* for distinguishing sleep
stages. On-device Monkey C, with no PPG-derived HRV, no respiration signal, and no cloud ML, is
working with strictly less signal than even those validated classifiers. **The feature must be
marketed and coded as "wakes you at the first sign of stirring in a window," never as "detects
your light sleep phase"** — the latter claim isn't supportable by what this hardware/API
combination can actually distinguish, and overclaiming it would be a credibility risk if a user
ever compares it against a real sleep lab or even Garmin's own sleep-stage algorithm (which uses
signals this app doesn't have access to at all — see below).

**Feasibility — verified, and this is the real cost:**
- `NappingView.mc`'s own header comment states the current design outright: "This view does as
  little as possible: no sensors... That is what keeps a full nap down to ~1-2% battery." Adding
  even low-rate accelerometer polling during a trailing window is a genuine reversal of that
  invariant for part of the nap, not a free add-on. It needs its own battery budget and
  on-device measurement before shipping, not just a simulator check.
- Confirmed no Connect IQ API exposes sleep-stage data to third-party apps at all — a Garmin
  forum thread states this plainly, and it's independent of this app's own capabilities; nothing
  about this project can "unlock" real stage detection, only approximate a coarse motion signal.
- `Toybox.System.DeviceSettings.doNotDisturb`/sleep-mode fields exist but are poll-only, no
  change-notification callback, and the sleep-mode boolean is marked deprecated (though still
  present in SDK 9.2.0/System 9 years after that deprecation notice) — not a reliable foundation
  to build on, just a "nice to know" data point at most.

**Effort:** high — new sensor lifecycle during the nap, new tuning (motion threshold, window
length), on-device battery validation, and careful product copy so the feature doesn't overclaim.
**Risk:** moderate-high, concentrated entirely in the battery-cost validation and the
overclaiming risk, not in whether the motion heuristic itself is achievable (it is).

---

## Tier 3 — smaller polish, lower stakes, lower confidence

### 5. Optional complication (opt-in only, not a default glance)

**What:** Connect IQ's `Toybox.Complications` API lets a device app publish a small data value
(e.g. "naps today," or a quick-launch shortcut) that a user can *choose* to add to their own
watch face — this is opt-in per-user, unlike a glance view, so it doesn't reverse this project's
deliberate "no glance view" decision (`CLAUDE.md`: "intentional"). Confirmed API exists (since
4.2.0), confirmed FR265/FR265S are supported devices, confirmed no manifest permission requirement
found in the docs.

**The honest caveat:** Garmin does not publish a battery/CPU cost model for complication update
frequency anywhere in the API reference. The only real-world data point found was a single
developer's anecdotal "no noticeable drain" report for an unrelated complication — not a
guarantee. **Recommendation: prototype with the cheapest possible update cadence (update only
when nap data actually changes, never polled), and measure battery impact on-device before
treating this as shippable** — don't take this one on faith the way the higher-confidence ideas
above can be.

**Effort:** low-moderate to prototype. **Risk:** unknown/undocumented — the only item on this
list where the real risk is "Garmin doesn't tell you," not a specific known gotcha.

---

## Considered and ruled out (with the specific evidence)

Listed so this doesn't get silently re-proposed later — each of these was checked, not assumed:

- **Ambient-light-based "is the room actually dark" gating.** Confirmed the FR265/265S has a
  physical ambient light sensor (drives auto-brightness) — but `Toybox.Sensor.Info` exposes
  **no ambient-light field at all**, confirmed by reading the full field list directly from the
  local SDK doc (accel, altitude, cadence, heading, heartRate, mag, oxygenSaturation, power,
  pressure, speed, temperature — nothing else). The one "ambient" text hit in that doc is the
  word "ambient" inside the *barometric pressure* description, not a light reading. There is no
  public API path to this hardware capability.
- **Richer escalating haptic patterns (variable intensity, not just on/off timing).**
  `Toybox.Attention`'s own API documentation states plainly: "Forerunner devices do not support
  vibration patterns. Vibration may still be used, but the vibration will always run at the same
  duty cycle." The `VibeProfile.dutyCycle` parameter this app could pass is accepted but has no
  effect on this hardware — only on/off timing (which `AlarmView._maybeAlert`'s escalating
  interval already uses) is achievable, not true intensity escalation.
- **Marketing this as true sleep-stage-aware waking** (see idea #4's caveat) — ruled out as a
  *claim*, not as a mechanism; the coarse "stirring" heuristic survives, the "detects light
  sleep" framing does not, per the peer-reviewed accuracy data cited above.
- **Streaks/badges/gamification.** No Connect IQ-specific evidence found that this helps
  retention for a niche, occasional-use utility; general wellness-app data on streak-breaking
  actively argues against it for this usage pattern (see idea #2). Kept out of idea #2
  deliberately.
- **"Wake my partner too" / Do-Not-Disturb sync.** No evidence of actual demand for either found
  in community research (explicitly flagged as unvalidated speculation, not a sourced request) —
  and "wake my partner too" is arguably self-contradictory for an app whose whole design point is
  a personal, hard-to-cheat wake proof for the wearer specifically.
- **Logging completed naps as a `Toybox.ActivityRecording` FIT activity** (so they show up in
  Garmin Connect's activity feed). Technically possible, but confirmed there is **no dedicated
  Nap/Rest sport type** in the `SPORT_*` enum — the closest fits (`SPORT_GENERIC`,
  `SPORT_TRAINING`/`SUB_SPORT_CARDIO_TRAINING`) would make a 20-minute nap show up looking like a
  mislabeled workout in the user's activity history. Also requires a new `Fit` manifest
  permission. The real user demand here (naps should count toward recovery scoring) is genuine
  per research, but this specific mechanism is an imperfect fit for it — better served by idea
  #2's own in-app history than by forcing it into Garmin Connect's workout-shaped activity model.
  Kept as a low-priority footnote, not a top idea.

---

## Sources

Primary (ground truth, checked directly on this machine):
- Installed Connect IQ SDK 9.2.0 API docs — `Toybox.SensorHistory`, `Toybox.UserProfile`,
  `Toybox.UserProfile.Profile`, `Toybox.Sensor.Info`, `Toybox.Complications`, `Toybox.Background`,
  `Toybox.ActivityRecording`, `Toybox.Attention`, `Toybox.System.DeviceSettings`, and the
  `fr265`/`fr265s` device-reference memory tables.

Secondary (real-world behavior, hardware specs, user demand — via research pass):
- Garmin Developer Forums: Body Battery/stress iterator sentinel-value and timestamp bugs;
  SpO2 live-value regression report; sleep-mode/DND API gap discussion; background-service
  battery-drain reports; AMOLED backlight/burn-in behavior thread; `playTone`/vibration-pattern
  clarification thread.
- DC Rainmaker's Forerunner 265/265S in-depth review; Garmin's own FR265 owner's manual
  (sensors/altimeter/Pulse-Ox pages).
- `gadgetsandwearables.com` on Garmin's most-requested-features list (smart/light-sleep alarm);
  Garmin Connect IQ Store listings for Power Napp, Nap till rested, and several "SmartAlarm"-class
  apps.
- Peer-reviewed wrist-actigraphy sleep/wake classification accuracy data (*Journal of Sleep
  Research* systematic review; PMC validation study).
- Trophy.so and Sahha.ai on streak-mechanic retention data and its failure modes.

**Known gap in this research** (stated for honesty, not glossed over): direct Reddit
thread content (r/Garmin, r/connectiq) did not render through the search tooling used — that
community-sentiment angle leans more heavily on Garmin's own forums and a features-roundup
article than on raw Reddit discussion. Worth a manual pass if this doc is revisited before
committing significant effort to idea #4 specifically.
