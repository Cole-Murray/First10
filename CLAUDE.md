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
