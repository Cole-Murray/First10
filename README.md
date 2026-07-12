# First10

**The power-nap alarm you can't cheat back to sleep.**

First10 is a Garmin Connect IQ app (built for the Forerunner 265) that runs a
short "power nap" or countdown and, when it goes off, makes you *prove you're
actually up* before it will turn off. You get a brief snooze, but to dismiss the
alarm you have to physically get out of bed and move: it scores your steps,
sustained motion, and heart-rate rise into a single **Awake Score** you must pass.

It is designed to eliminate the "20-minute nap that becomes a 2-hour oversleep."

---

## Why it's a nap/short-timer app (and not an overnight alarm)

This shape is a deliberate consequence of how Garmin Connect IQ works, not a
missing feature:

- Only a **foreground device app** can vibrate or play a tone (`Toybox.Attention`
  is unavailable to background services and watch faces).
- An app **cannot force itself to the foreground** unattended
  (`requestApplicationWake` only shows a prompt the user must tap).
- A device app always runs the CPU in high-power mode (~3-4%/hour), so an app that
  had to stay open all night to fire a morning alarm would cost ~15-30% battery
  per night.

A **nap/short timer only needs to stay open for minutes**, so the exact same
"guaranteed to vibrate you awake" behavior costs only ~1-2% battery for a 25-minute
nap. That's the whole reason First10 is nap-first.

> First10 is NOT a native Garmin alarm and does NOT create or modify the watch's
> built-in alarms. It is a foreground nap timer with an anti-snooze wake check.

**The watch must be worn** during the nap, because the wake check reads wrist
sensors (heart rate + motion). Charging on the nightstand is not the model; the
short duration makes that a non-issue.

---

## How it works

1. **Set up** – pick a nap length (10/20/25/30/45/60/90 min) and a difficulty
   (Easy / Medium / Hard), then press START.
2. **Nap** – the screen goes black (AMOLED pixels off) and only a 1 Hz timer runs.
   No sensors, minimal battery. Press any button to peek at the time left; BACK
   cancels.
3. **Alarm** – at zero, escalating vibration + tone begins. Sensors switch on and
   the app measures your resting heart rate for a few seconds as a baseline.
4. **Prove you're up** – a live ring fills as your **Awake Score** climbs:
   - **Steps** – you must take real steps.
   - **Sustained motion** – accelerometer movement has to be continuous, not a
     single wrist shake.
   - **Heart-rate rise** – your HR must climb above the resting baseline. This is
     the anti-cheat: only actually standing up and walking raises it.
5. **Snooze (the "First10")** – START gives you a short snooze (default 10s), but
   it comes back *louder*, and snoozes are capped.
6. **Done** – pass the score and you get a "You're up!" summary (time to get up,
   steps, snoozes, HR change).

**Safety valve:** pressing BACK five times within three seconds force-dismisses
the alarm, and there is a configurable hard-cap auto-dismiss, so no one is ever
trapped.

### Difficulty presets

| Level  | Steps | Sustained motion | HR rise | Notes |
|--------|-------|------------------|---------|-------|
| Easy   | 15    | 6 s              | none    | HR not required; good for testing / a gentle nudge |
| Medium | 30    | 10 s             | +8 bpm  | Default balance |
| Hard   | 45    | 15 s             | +12 bpm | HR rise is a mandatory gate; can't be faked in bed |

All of these are tunable in `source/Difficulty.mc`.

---

## Project structure

```
manifest.xml            Device app, FR265/FR265S, Sensor permission
monkey.jungle           Build config
resources/
  drawables/            Launcher icon
  strings/              App name + settings labels
  settings/             User-configurable properties (Garmin Connect)
source/
  First10App.mc         App entry point (no glance view, so it won't time out)
  Settings.mc           Properties + persisted last-used choices
  Difficulty.mc         Easy/Medium/Hard threshold presets
  AwakeScore.mc         Multi-sensor scoring + pass/hold logic
  SensorManager.mc      Capability-checked HR + accel/gyro access
  Alerter.mc            Capability-checked Attention (vibrate/tone) wrapper
  SetupView / Delegate      Nap length + difficulty picker
  NappingView / Delegate    Black low-power countdown
  AlarmView / Delegate      Escalating alarm + live Awake Score ring
  SummaryView / Delegate    Post-wake stats
```

---

## Building

Requires the [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
and a developer signing key.

```sh
# Compile for the Forerunner 265
monkeyc -f monkey.jungle -d fr265 -o bin/First10.prg -y developer_key.der

# Run in the simulator
connectiq                       # start the simulator first
monkeydo bin/First10.prg fr265
```

Package for the store (all products in the manifest):

```sh
monkeyc -f monkey.jungle -e -o bin/First10.iq -y developer_key.der
```

### Testing notes

- In the simulator, trigger sensor values under **Simulation** to exercise the
  Awake Score, and set the accelerometer/heart-rate inputs to test pass/fail.
- Some behaviors (real optical HR, on-wrist vibration, the app-not-timing-out
  behavior) only manifest on hardware. Sideload to a real FR265 by copying
  `bin/First10.prg` to `GARMIN/APPS/` and launching it from the **apps menu**
  (not a glance).

---

## Connect IQ Store listing (draft)

**Name:** First10 - Nap Alarm That Makes You Get Up

**Short description:**
The power-nap alarm you can't snooze your way out of. First10 wakes you with
vibration and sound, then makes you actually stand up and move to turn it off -
verified with your steps, motion, and heart rate.

**Full description:**
Set a nap (10-90 minutes), lie down, and let First10 watch the clock with the
screen off. When it fires, you can snooze - but only for a few seconds, and it
comes back louder. To truly dismiss it you have to pass the Awake Score: take
real steps, keep moving, and let your heart rate climb above your resting
baseline. Shaking your wrist won't work; you have to get up.

Pick Easy, Medium, or Hard depending on how hard you need to be pushed. A safety
combo and auto-dismiss make sure you're never trapped.

**Please note:**
- First10 is a foreground nap/short-timer app, not a native Garmin alarm, and it
  is not intended as an all-night overnight alarm (Connect IQ can't wake a closed
  app). It's built for naps and short rests.
- Wear the watch during your nap - the wake check needs wrist sensors.
- A nap keeps the app open for only a few minutes, so battery impact is small
  (roughly 1-2% for a 25-minute nap).

**Permissions:** Sensors (heart rate + accelerometer/gyroscope for the wake check).

---

## Roadmap

- **v1 (this):** nap/short-timer + multi-sensor Awake Score + summary.
- **v1.1:** smart-wake within the nap (wake at a lighter moment near the end),
  difficulty tuning, tone/vibration customization, nap stats.
- **v2 (exploration):** an overnight morning mode - only if the battery tradeoff
  is made explicit and opt-in, or a viable companion-phone assist is found.
