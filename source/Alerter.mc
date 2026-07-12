import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;

// Alerter wraps Toybox.Attention. Attention is ONLY available to a foreground
// device app (not background services or watch faces), which is exactly why
// First10 must run in the foreground until the alarm is dismissed.
//
// Every call is guarded by a `has` check because tone/vibration support varies
// by device. On Forerunners, vibration runs at a fixed duty cycle (no true
// patterns), so escalation is expressed through vibration length and tone choice.
module Alerter {

    function canVibrate() as Boolean {
        return (Attention has :vibrate);
    }

    function canPlayTone() as Boolean {
        return (Attention has :playTone);
    }

    // level escalates from 0 upward as the user keeps ignoring the alarm.
    function fire(level as Number) as Void {
        if (level < 0) { level = 0; }

        if (canVibrate()) {
            var duration = 700 + (level * 250);
            if (duration > 2500) { duration = 2500; }
            try {
                var profiles = [ new Attention.VibeProfile(100, duration) ] as Array<Attention.VibeProfile>;
                Attention.vibrate(profiles);
            } catch (e) {
                System.println("vibrate failed: " + e.getErrorMessage());
            }
        }

        if (Settings.toneEnabled() && canPlayTone()) {
            try {
                Attention.playTone({
                    :toneProfile => _toneForLevel(level),
                    :repeatCount => 1 + (level > 2 ? 2 : level)
                });
            } catch (e) {
                // Some devices reject custom profiles; fall back to the
                // built-in alarm tone.
                try { Attention.playTone(Attention.TONE_ALARM); } catch (e2) {}
            }
        }
    }

    function _toneForLevel(level as Number) as Array<Attention.ToneProfile> {
        var freq = 1200 + (level * 200);
        if (freq > 3000) { freq = 3000; }
        return [
            new Attention.ToneProfile(freq, 200),
            new Attention.ToneProfile(0, 80),
            new Attention.ToneProfile(freq, 200)
        ] as Array<Attention.ToneProfile>;
    }

    // A short confirmation buzz used when the user finally passes the score.
    function successBuzz() as Void {
        if (canVibrate()) {
            try {
                Attention.vibrate([ new Attention.VibeProfile(60, 250) ] as Array<Attention.VibeProfile>);
            } catch (e) {}
        }
    }
}
