import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// The nap itself. This view does as little as possible: no sensors, a mostly
// black AMOLED screen, and a 1 Hz timer that just watches the clock. That is
// what keeps a full nap down to ~1-2% battery.
class NappingView extends WatchUi.View {

    var _durationSec as Number;
    var _difficulty as Number;

    var _startMs as Number = 0;
    var _timer as Timer.Timer?;
    var _peekUntilMs as Number = 0;   // show the countdown briefly after a button press
    var _finished as Boolean = false;

    function initialize(durationSec as Number, difficulty as Number) {
        View.initialize();
        _durationSec = durationSec;
        _difficulty = difficulty;
    }

    function onShow() as Void {
        _startMs = System.getTimer();
        // Peek for a few seconds at the start so the user sees it armed.
        _peekUntilMs = _startMs + 4000;
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 1000, true);
        }
    }

    function onHide() as Void {
        _stopTimer();
    }

    function _stopTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function remainingSec() as Number {
        var elapsed = (System.getTimer() - _startMs) / 1000;
        var rem = _durationSec - elapsed;
        if (rem < 0) { rem = 0; }
        return rem;
    }

    function peek() as Void {
        _peekUntilMs = System.getTimer() + 4000;
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        if (_finished) {
            return;
        }
        if (remainingSec() <= 0) {
            _finished = true;
            _stopTimer();
            _goToAlarm();
            return;
        }
        // Only bother redrawing while peeking; otherwise keep pixels off.
        if (System.getTimer() < _peekUntilMs) {
            WatchUi.requestUpdate();
        }
    }

    function _goToAlarm() as Void {
        var view = new AlarmView(_difficulty);
        WatchUi.switchToView(view, new AlarmDelegate(view), WatchUi.SLIDE_UP);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var showCountdown = System.getTimer() < _peekUntilMs;
        if (!showCountdown) {
            // Fully dark to save battery; nothing drawn.
            return;
        }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.20, Graphics.FONT_XTINY, "napping", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.36, Graphics.FONT_NUMBER_MEDIUM,
            _formatRemaining(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.70, Graphics.FONT_XTINY, "BACK to cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _formatRemaining() as String {
        var rem = remainingSec();
        var m = rem / 60;
        var s = rem % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }
}
