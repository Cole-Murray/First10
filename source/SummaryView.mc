import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Post-wake summary. Confirms the user is up and shows how the wake-up went.
class SummaryView extends WatchUi.View {

    var _timeToWakeSec as Number;
    var _snoozes as Number;
    var _restingHr as Number?;
    var _wakeHr as Number?;
    var _steps as Number;
    var _difficulty as Number;
    var _safetyDismiss as Boolean;

    function initialize(
        timeToWakeSec as Number,
        snoozes as Number,
        restingHr as Number?,
        wakeHr as Number?,
        steps as Number,
        difficulty as Number,
        safetyDismiss as Boolean
    ) {
        View.initialize();
        _timeToWakeSec = timeToWakeSec;
        _snoozes = snoozes;
        _restingHr = restingHr;
        _wakeHr = wakeHr;
        _steps = steps;
        _difficulty = difficulty;
        _safetyDismiss = safetyDismiss;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_safetyDismiss) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.12, Graphics.FONT_SMALL, "Auto-dismissed", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.12, Graphics.FONT_SMALL, "You're up!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.30, Graphics.FONT_XTINY,
            "Time to get up: " + _formatDuration(_timeToWakeSec), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.40, Graphics.FONT_XTINY,
            "Steps taken: " + _steps.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.50, Graphics.FONT_XTINY,
            "Snoozes: " + _snoozes.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.60, Graphics.FONT_XTINY,
            "HR " + _hrText(_restingHr) + " to " + _hrText(_wakeHr), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "START new nap", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.85, Graphics.FONT_XTINY, "BACK to exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _hrText(hr as Number?) as String {
        if (hr == null) {
            return "--";
        }
        return hr.format("%d");
    }

    function _formatDuration(sec as Number) as String {
        var m = sec / 60;
        var s = sec % 60;
        if (m > 0) {
            return m.format("%d") + "m " + s.format("%02d") + "s";
        }
        return s.format("%d") + "s";
    }
}
