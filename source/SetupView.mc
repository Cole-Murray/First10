import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// First screen: choose nap length + difficulty, then START to begin.
class SetupView extends WatchUi.View {

    // Nap-length presets in minutes. These are the "power nap" sweet spots.
    static const DURATIONS = [10, 20, 25, 30, 45, 60, 90] as Array<Number>;

    var _durIndex as Number = 2;   // default 25 min
    var _difficulty as Number = Difficulty.MEDIUM;

    function initialize() {
        View.initialize();
        _durIndex = _indexForMinutes(Settings.lastDurationMin());
        _difficulty = Settings.lastDifficulty();
    }

    function durationMinutes() as Number {
        return DURATIONS[_durIndex];
    }

    function difficulty() as Number {
        return _difficulty;
    }

    function nextDuration() as Void {
        _durIndex = (_durIndex + 1) % DURATIONS.size();
        Settings.setLastDurationMin(durationMinutes());
        WatchUi.requestUpdate();
    }

    function prevDuration() as Void {
        _durIndex = (_durIndex - 1 + DURATIONS.size()) % DURATIONS.size();
        Settings.setLastDurationMin(durationMinutes());
        WatchUi.requestUpdate();
    }

    function cycleDifficulty() as Void {
        _difficulty = (_difficulty + 1) % 3;
        Settings.setLastDifficulty(_difficulty);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.12, Graphics.FONT_SMALL, "First10", Graphics.TEXT_JUSTIFY_CENTER);

        // Nap length (the big number)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.28, Graphics.FONT_NUMBER_MEDIUM,
            durationMinutes().toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.50, Graphics.FONT_TINY, "minute nap", Graphics.TEXT_JUSTIFY_CENTER);

        // Difficulty
        dc.setColor(_difficultyColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.60, Graphics.FONT_SMALL,
            "Difficulty: " + Difficulty.name(_difficulty), Graphics.TEXT_JUSTIFY_CENTER);

        // Hints
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.76, Graphics.FONT_XTINY, "UP/DOWN length", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.83, Graphics.FONT_XTINY, "MENU difficulty", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.90, Graphics.FONT_XTINY, "START to nap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _difficultyColor() {
        if (_difficulty <= Difficulty.EASY) {
            return Graphics.COLOR_GREEN;
        } else if (_difficulty == Difficulty.MEDIUM) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_RED;
    }

    function _indexForMinutes(m as Number) as Number {
        for (var i = 0; i < DURATIONS.size(); i++) {
            if (DURATIONS[i] == m) {
                return i;
            }
        }
        return 2; // default 25
    }
}
