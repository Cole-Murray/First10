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

        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        // Running cursor, same approach as SetupView's fix for the same class
        // of bug: advance `y` by each element's *actual* rendered height
        // (Theme.stackY for top-anchored text) instead of independently
        // guessed screen-height fractions, so nothing overlaps regardless of
        // font metrics or screen size.
        var headlineFont = Graphics.FONT_SMALL;
        var statFont = Graphics.FONT_XTINY;
        var hintFont = Graphics.FONT_XTINY;

        // Icon (not text - sized/positioned in raw pixels off its radius).
        var iconY = h * 0.13;
        var iconR = ((w < h ? w : h) * 0.055).toNumber();
        _drawWakeIcon(dc, cx, iconY.toNumber(), iconR, !_safetyDismiss);
        var y = iconY + iconR + 10; // top edge for the headline below the icon

        // Headline
        if (_safetyDismiss) {
            dc.setColor(Theme.WARN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, headlineFont, "Auto-dismissed", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Theme.GO, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, headlineFont, "You're up!", Graphics.TEXT_JUSTIFY_CENTER);
        }
        y = Theme.stackY(dc, y, headlineFont, 16);

        // Stat rows. _drawStat is TEXT_JUSTIFY_VCENTER (its y is the row's
        // *center*, not its top), so convert the top-anchored cursor to a
        // center once, then step center-to-center by the row's full measured
        // height plus a gap - that reproduces stackY's "no overlap" guarantee
        // for vertically-centered lines instead of its top-anchored formula.
        var statH = dc.getFontHeight(statFont);
        var statRowGap = 12; // a little extra breathing room between stat rows
        var rowY = y + (statH / 2.0);
        _drawStat(dc, cx, rowY, "Time to get up", _formatDuration(_timeToWakeSec));
        rowY += statH + statRowGap;
        _drawStat(dc, cx, rowY, "Steps taken", _steps.format("%d"));
        rowY += statH + statRowGap;
        _drawStat(dc, cx, rowY, "Snoozes", _snoozes.format("%d"));
        rowY += statH + statRowGap;
        _drawStat(dc, cx, rowY, "Heart rate", _hrText(_restingHr) + " to " + _hrText(_wakeHr));

        // Back to a top-anchored cursor: bottom edge of the last (centered)
        // stat row is its center plus half its height.
        y = rowY + (statH / 2.0) + 14;

        // Hints
        dc.setColor(Theme.TXT_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, hintFont, "START new nap", Graphics.TEXT_JUSTIFY_CENTER);
        y = Theme.stackY(dc, y, hintFont, 8);

        dc.drawText(cx, y, hintFont, "BACK to exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A small circular icon above the headline: a check for a real wake, an
    // exclamation for a safety auto-dismiss. Drawn with primitives so no image
    // asset is needed.
    function _drawWakeIcon(dc as Graphics.Dc, cx as Number, y as Number, r as Number, success as Boolean) as Void {
        if (success) {
            dc.setColor(Theme.GO_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, y, r);
            dc.setPenWidth(4);
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            var x1 = cx - (r * 0.5).toNumber();
            var y1 = y + (r * 0.05).toNumber();
            var x2 = cx - (r * 0.1).toNumber();
            var y2 = y + (r * 0.4).toNumber();
            var x3 = cx + (r * 0.55).toNumber();
            var y3 = y - (r * 0.35).toNumber();
            dc.drawLine(x1, y1, x2, y2);
            dc.drawLine(x2, y2, x3, y3);
        } else {
            dc.setColor(Theme.WARN_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, y, r);
            dc.setColor(Theme.WARN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y - (r * 0.65).toNumber(), Graphics.FONT_MEDIUM, "!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Two-column "label   value" row: label right-justified, value
    // left-justified, split at a fixed midline so rows line up regardless of
    // text length.
    function _drawStat(dc as Graphics.Dc, cx as Number, y as Number or Float, label as String, value as String) as Void {
        var gap = 6;
        dc.setColor(Theme.TXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - gap, y, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + gap, y, Graphics.FONT_XTINY, value,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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
