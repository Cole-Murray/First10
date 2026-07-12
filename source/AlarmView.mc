import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// The alarm + wake-verification screen. This is where First10 earns its name:
// you can snooze, but only briefly, and the ONLY way to dismiss is to pass the
// Awake Score by actually getting up and moving.
class AlarmView extends WatchUi.View {

    enum {
        PHASE_BASELINE = 0,   // measuring resting HR before the user moves
        PHASE_ACTIVE = 1,     // scoring; alarm escalating
        PHASE_SNOOZE = 2,     // brief quiet period
        PHASE_DONE = 3        // passed or safety-dismissed
    }

    const BASELINE_MS = 4000;

    var _cfg as Difficulty.Config;
    var _score as AwakeScore;

    var _timer as Timer.Timer?;
    var _phase as Number = PHASE_BASELINE;

    var _alarmStartMs as Number = 0;
    var _lastTickMs as Number = 0;
    var _phaseEndMs as Number = 0;      // used for baseline + snooze windows

    var _baselineSteps as Number = 0;
    var _hrSum as Number = 0;
    var _hrCount as Number = 0;

    var _alertLevel as Number = 0;
    var _nextAlertMs as Number = 0;

    var _snoozesUsed as Number = 0;
    var _safetyDismiss as Boolean = false;

    function initialize(difficulty as Number) {
        View.initialize();
        _cfg = Difficulty.forLevel(difficulty);
        _score = new AwakeScore(_cfg);
    }

    function onShow() as Void {
        var now = System.getTimer();
        _alarmStartMs = now;
        _lastTickMs = now;
        _phase = PHASE_BASELINE;
        _phaseEndMs = now + BASELINE_MS;
        _nextAlertMs = now;

        SensorManager.start();
        _baselineSteps = SensorManager.getSteps();

        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 250, true);
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // Called by the delegate when the user hits SELECT/START.
    function snooze() as Void {
        if (_phase == PHASE_DONE || _phase == PHASE_SNOOZE) {
            return;
        }
        if (_snoozesUsed >= Settings.maxSnoozes()) {
            return; // out of snoozes; alarm keeps going
        }
        _snoozesUsed++;
        _phase = PHASE_SNOOZE;
        _phaseEndMs = System.getTimer() + (Settings.snoozeSeconds() * 1000);
        WatchUi.requestUpdate();
    }

    function snoozesRemaining() as Number {
        var r = Settings.maxSnoozes() - _snoozesUsed;
        if (r < 0) { r = 0; }
        return r;
    }

    // Safety valve invoked by the delegate (rapid BACK presses).
    function emergencyDismiss() as Void {
        _safetyDismiss = true;
        _finish();
    }

    function onTick() as Void {
        var now = System.getTimer();
        var dt = (now - _lastTickMs) / 1000.0;
        _lastTickMs = now;
        if (dt <= 0.0) { dt = 0.25; }

        var hr = SensorManager.getHeartRate();
        var steps = SensorManager.getSteps();
        var motion = SensorManager.getMotion();

        if (_phase == PHASE_BASELINE) {
            if (hr != null) {
                _hrSum += hr;
                _hrCount++;
            }
            _maybeAlert(now);
            if (now >= _phaseEndMs) {
                var baseHr = (_hrCount > 0) ? (_hrSum / _hrCount) : hr;
                _score.setBaseline(_baselineSteps, baseHr);
                _phase = PHASE_ACTIVE;
            }
            WatchUi.requestUpdate();
            return;
        }

        if (_phase == PHASE_SNOOZE) {
            if (now >= _phaseEndMs) {
                // Reactivate LOUDER than before - snoozing makes it worse.
                _phase = PHASE_ACTIVE;
                _alertLevel += 1;
                _nextAlertMs = now;
            }
            WatchUi.requestUpdate();
            return;
        }

        if (_phase == PHASE_ACTIVE) {
            _score.updateSteps(steps);
            _score.updateHeartRate(hr);
            _score.updateMotion(motion);
            _score.tick(dt);
            _maybeAlert(now);

            // Safety: never trap someone. Auto-dismiss after the hard cap.
            var capMs = Settings.hardCapMin() * 60 * 1000;
            if ((now - _alarmStartMs) >= capMs) {
                _safetyDismiss = true;
                _finish();
                return;
            }

            if (_score.passed()) {
                _finish();
                return;
            }
            WatchUi.requestUpdate();
        }
    }

    function _maybeAlert(now as Number) as Void {
        if (now < _nextAlertMs) {
            return;
        }
        Alerter.fire(_alertLevel);
        // Escalate over time, capped.
        if (_alertLevel < 8) {
            _alertLevel++;
        }
        var interval = 1800 - (_alertLevel * 100);
        if (interval < 1000) { interval = 1000; }
        _nextAlertMs = now + interval;
    }

    function _finish() as Void {
        _phase = PHASE_DONE;
        if (!_safetyDismiss) {
            Alerter.successBuzz();
        }
        var timeToWake = (System.getTimer() - _alarmStartMs) / 1000;
        var wakeHr = SensorManager.getHeartRate();
        var stepsTaken = SensorManager.getSteps() - _baselineSteps;
        if (stepsTaken < 0) { stepsTaken = 0; }

        SensorManager.shutdown();

        var summary = new SummaryView(
            timeToWake,
            _snoozesUsed,
            _score.baselineHr(),
            wakeHr,
            stepsTaken,
            _cfg.level,
            _safetyDismiss
        );
        WatchUi.switchToView(summary, new SummaryDelegate(summary), WatchUi.SLIDE_UP);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_phase == PHASE_SNOOZE) {
            _drawSnooze(dc, cx, h);
            return;
        }

        // Progress ring
        var progress = _score.progress();
        var radius = (w < h ? w : h) / 2 - 8;
        dc.setPenWidth(10);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius); // faint full track
        if (progress > 0.0) {
            dc.setColor(_ringColor(progress), Graphics.COLOR_TRANSPARENT);
            var endDeg = (90.0 - (progress * 360.0)).toNumber();
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, endDeg);
        }

        // Headline
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.16, Graphics.FONT_MEDIUM, "GET UP!", Graphics.TEXT_JUSTIFY_CENTER);

        // Center: score percent
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 24, Graphics.FONT_NUMBER_MEDIUM,
            _score.total().toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 18, Graphics.FONT_XTINY, "awake score", Graphics.TEXT_JUSTIFY_CENTER);

        // Component readouts
        var line = "steps " + _score.stepsRemaining().format("%d") + " to go";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.70, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);

        if (_cfg.hrRiseBpm > 0) {
            var hrLine = "HR +" + _score.hrRise().format("%d") + "/" + _cfg.hrRiseBpm.format("%d");
            dc.drawText(cx, h * 0.77, Graphics.FONT_XTINY, hrLine, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Snooze hint
        if (snoozesRemaining() > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY,
                "START snooze (" + snoozesRemaining().format("%d") + ")", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY, "no snoozes left", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function _drawSnooze(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        var remMs = _phaseEndMs - System.getTimer();
        if (remMs < 0) { remMs = 0; }
        var remSec = (remMs / 1000) + 1;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.28, Graphics.FONT_SMALL, "Snoozing", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.42, Graphics.FONT_NUMBER_MEDIUM,
            remSec.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.68, Graphics.FONT_XTINY, "get ready to move", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _ringColor(progress as Float) {
        if (progress >= 0.9) {
            return Graphics.COLOR_GREEN;
        } else if (progress >= 0.5) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_ORANGE;
    }
}
