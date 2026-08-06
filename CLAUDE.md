# First10

A Garmin Connect IQ nap-alarm app for the Forerunner 265 / 265S. See `README.md` for the
full product pitch, difficulty presets, and store listing copy — this file is oriented at
whoever (human or Claude) is writing code in this repo next.

## What it does

A power-nap timer that will not let you sleep through it. When the alarm fires, the only way
to dismiss it is to pass an **Awake Score** (0–100) built from live sensor signals — steps,
sustained accelerometer motion, and heart-rate rise above a measured resting baseline. A brief
snooze is allowed but re-arms louder, snoozes are capped, and a rapid-BACK-press safety valve
plus a hard-cap timer guarantee the user is never trapped.

## Architecture

Four-view state machine, wired via `WatchUi.switchToView`:

```
SetupView   -> NappingView   -> AlarmView   -> SummaryView
(pick nap)     (screen off,      (escalating     (post-wake
                1Hz timer)        alarm +          stats)
                                  Awake Score)
```

| File | Role |
|---|---|
| `source/First10App.mc` | App entry point (`getInitialView` -> SetupView). No glance view — intentional, see README. |
| `source/Settings.mc` | Reads Connect-IQ `Application.Properties` (nap length, difficulty, snooze/hard-cap config) with clamped fallbacks; persists last-used choices via `Application.Storage`. |
| `source/Difficulty.mc` | Easy/Medium/Hard threshold presets (steps, motion, HR rise, hold time, pass mark, score weights). Tuning lives entirely here. |
| `source/AwakeScore.mc` | Turns live sensor updates into the 0–100 score + pass/hold logic. Hard mode makes HR rise a mandatory gate, not just a weighted input. |
| `source/SensorManager.mc` | Capability-guarded (`has`) HR + high-frequency accel/gyro access; computes a motion metric as an EMA of accelerometer-magnitude std-dev. Only runs during the alarm phase (battery). |
| `source/Alerter.mc` | Capability-guarded vibrate/tone escalation wrapper. |
| `source/Theme.mc` | Shared design system — palette (raw `0xRRGGBB`, not the limited named `Graphics.COLOR_*` set), ring/difficulty color ramps, and layout helpers (`ringPenWidth`, `bigNumberFont`) so FR265 (416×416) and FR265S (360×360) share one set of proportional layouts. **Every view should read colors/fonts from here, not inline `Graphics.COLOR_*`.** |
| `source/SetupView(.mc)` / `SetupDelegate.mc` | Pick nap length (10/20/25/30/45/60/90 min) + difficulty; shows difficulty as a label + 3 pips. |
| `source/NappingView(.mc)` / `NappingDelegate.mc` | Screen fully off except a brief "peek" after a button press. This is the entire battery-saving design — do not add persistent chrome here. |
| `source/AlarmView(.mc)` / `AlarmDelegate.mc` | The core screen: bold animated progress ring (`_displayedProgress` eases toward `_score.progress()` each 250ms tick), escalating alerts, snooze, 5×BACK-in-3s emergency dismiss. |
| `source/SummaryView(.mc)` / `SummaryDelegate.mc` | Post-wake stats with a drawn (no image asset) check/exclamation icon and a two-column label/value stat list. |

No logic file currently has stubs or TODOs — the full flow is written end-to-end. UI work is
layered on top of that logic without touching `AwakeScore`/`SensorManager`/`Alerter`/`Difficulty`.

## Build & run

Requires the Connect IQ SDK + a developer signing key. On this machine both are already set up:
- SDK 9.2.0 at `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-...`
- Temurin JDK 17 at `%USERPROFILE%\tools\jdk-17.0.19+10` (user-level `JAVA_HOME`/PATH, no admin)
- VS Code + the Monkey C extension (`garmin.monkey-c-1.1.3`)

```powershell
monkeyc -f monkey.jungle -d fr265  -o bin/First10.prg  -y developer_key.der
monkeyc -f monkey.jungle -d fr265s -o bin/First10s.prg -y developer_key.der
connectiq                              # start the simulator
monkeydo bin/First10.prg fr265
```

In VS Code, `F5` builds + launches the simulator for the selected device in one step.

**Simulator sensor testing:** use **Simulation → Heart Rate** and **Simulation → Sensors** to
inject HR/step/motion values and exercise the Awake Score pass/fail logic without moving.

**Sideloading to hardware:** copy the compiled `.prg` to `GARMIN/APPS/` on the watch and launch
it from the apps menu (not a glance — there isn't one).

## Conventions

- All drawing is code-only (no layout XML/`.mss` theme, no custom drawables besides the
  launcher icon) — positions are fractions of `dc.getWidth()/getHeight()` so both device sizes
  share layout code. Keep new screens consistent with this rather than introducing per-device
  constants.
- Colors and fonts come from `Theme.mc`. If a new screen needs a color not already in the
  palette, add it there rather than inlining `Graphics.COLOR_*`.
- `Theme.bigNumberFont(width)` picks between `FONT_NUMBER_HOT` and `FONT_NUMBER_MEDIUM` based on
  screen width — reuse it for any large numeral display rather than hardcoding a font.
- A true custom bitmap font (`.fnt` + `fonts.xml`) was deliberately deferred as a v1.1+ upgrade
  to avoid a fragile binary-asset build step; `Theme.bigNumberFont` is the interim "premium
  numeral" solution.
- `developer_key.der` and `bin/` are gitignored — never commit the signing key.

## Known issues from first code review

A full-codebase review has run once. Two findings are already fixed — don't rediscover these:

- Fixed (`1d9ed9c`): `AlarmView.snooze()` allowed a reflexive SELECT-press during the 4s
  `PHASE_BASELINE` window to skip step-baseline capture, trivializing the step anti-cheat check.
  Snooze is now also blocked during `PHASE_BASELINE`.
- Fixed (`81e3be5`): dead `SensorManager` API surface (`stop()`, `isRunning()`, `gyroPresent()`,
  zero call sites) removed.

Open findings, left unfixed deliberately — each involves product/design judgment on a
safety-critical anti-cheat flow, not a mechanical bug fix:

1. **`AlarmView.onShow()` unconditionally resets the hard-cap timer and Awake-Score baseline**
   on every show, with no guard for "fresh alarm start" vs. the OS re-showing an already-active
   view (e.g. a notification overlay). A mid-alarm re-entrancy silently resets both the hard-cap
   deadline and score progress — not a trap (BACK-press emergency valve still works), but the
   hard-cap guarantee is no longer actually bounded across an interruption.
2. **`NappingView.onShow()` unconditionally resets the nap start time** on every show — same
   class of bug as #1. An OS re-show mid-nap would silently extend the nap by the elapsed time.
3. **A swallowed `Sensor.enableSensorEvents` exception in `SensorManagerImpl.start()` leaves HR
   permanently null with no fallback.** The catch block only logs; nothing distinguishes "device
   supports HR" from "HR actually enabled," and nothing degrades score weights once HR is
   confirmed dead.
4. **Medium's `passMark` (90) in `Difficulty.forLevel()` mathematically requires some HR
   contribution even though `hrGate` is `false`** — maxing steps + motion with zero HR only
   reaches 75. This contradicts `AwakeScore.mc`'s own comment describing HR as an optional
   weighted contributor on Medium vs. a mandatory gate only on Hard. Compounds with #3: if HR
   never arrives, Medium becomes unpassable and Hard's gate becomes literally impossible, leaving
   only the hard-cap timer or emergency valve as an exit.
5. **No automated tests exist.** `AwakeScore.mc`'s pass/fail logic (`stepScore`, `motionScore`,
   `hrScore`, `total`, `_conditionMet`, `tick`) is pure and sensor/UI-free — the cheapest code
   here to unit test, and the exact mechanism that confirmed finding #1 (now fixed) was real.
   Connect IQ supports `(:test)`-annotated unit tests runnable via `monkeydo --test`; none exist.

Also open, cosmetic/non-blocking: `resources/drawables/launcher_icon.png` is 60×60; the FR265
launcher-icon spec is closer to 40×40.
