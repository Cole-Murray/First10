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

        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        // Running top-anchored cursor: every line below advances past the
        // previous line's *actual* rendered height (Theme.stackY) instead of
        // an independently-guessed height fraction, so nothing overlaps
        // regardless of font metrics or screen size.
        var y = h * 0.08;

        // Nap length (the big number)
        var bigFont = Theme.bigNumberFont(w);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, bigFont, durationMinutes().toString(), Graphics.TEXT_JUSTIFY_CENTER);
        y = Theme.stackY(dc, y, bigFont, 0);

        dc.setColor(Theme.TXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, "minute nap", Graphics.TEXT_JUSTIFY_CENTER);
        y = Theme.stackY(dc, y, Graphics.FONT_TINY, 2);

        // Difficulty label + pips
        dc.setColor(Theme.difficultyColor(_difficulty), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, Difficulty.name(_difficulty), Graphics.TEXT_JUSTIFY_CENTER);
        y = Theme.stackY(dc, y, Graphics.FONT_SMALL, 0);

        // Pips are short (a few px tall, not a full text line), so they get a
        // fixed pixel offset off the cursor rather than another stackY hop.
        var pipRadius = 4;
        var pipsY = (y + pipRadius).toNumber();
        _drawPips(dc, cx, pipsY, _difficulty);
        y = pipsY + pipRadius + 4;

        // Hints
        dc.setColor(Theme.TXT_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "UP/DOWN length", Graphics.TEXT_JUSTIFY_CENTER);
        y = Theme.stackY(dc, y, Graphics.FONT_XTINY, 2);

        dc.drawText(cx, y, Graphics.FONT_XTINY, "MENU difficulty", Graphics.TEXT_JUSTIFY_CENTER);
        y = Theme.stackY(dc, y, Graphics.FONT_XTINY, 2);

        dc.setColor(Theme.GO, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "START to nap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Three small dots showing difficulty at a glance: (level + 1) filled in
    // the difficulty color, the rest drawn as dim outlines.
    function _drawPips(dc as Graphics.Dc, cx as Number, y as Number, level as Number) as Void {
        var count = 3;
        var filled = level + 1;
        var spacing = 20;
        var r = 4;
        var startX = cx - (((count - 1) * spacing) / 2);
        var color = Theme.difficultyColor(level);

        for (var i = 0; i < count; i++) {
            var x = startX + (i * spacing);
            if (i < filled) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, r);
            } else {
                dc.setColor(Theme.TXT_HINT, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, r);
            }
        }
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
