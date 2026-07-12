import Toybox.Application;
import Toybox.Lang;

// Thin wrapper over Application.Properties with hard-coded fallbacks, so the app
// works even if a property has not been synced yet from Garmin Connect.
module Settings {

    function _num(key as String, def as Number) as Number {
        try {
            var v = Application.Properties.getValue(key);
            if (v == null) {
                return def;
            }
            return v as Number;
        } catch (e) {
            return def;
        }
    }

    function _bool(key as String, def as Boolean) as Boolean {
        try {
            var v = Application.Properties.getValue(key);
            if (v == null) {
                return def;
            }
            return v as Boolean;
        } catch (e) {
            return def;
        }
    }

    function durationMin() as Number {
        var m = _num("durationMin", 25);
        if (m < 1) { m = 1; }
        if (m > 180) { m = 180; }
        return m;
    }

    function difficulty() as Number {
        var d = _num("difficulty", 1);
        if (d < 0) { d = 0; }
        if (d > 2) { d = 2; }
        return d;
    }

    function snoozeSeconds() as Number {
        return _num("snoozeSeconds", 10);
    }

    function maxSnoozes() as Number {
        return _num("maxSnoozes", 5);
    }

    function hardCapMin() as Number {
        return _num("hardCapMin", 5);
    }

    function toneEnabled() as Boolean {
        return _bool("enableTone", true);
    }

    // Runtime (per-session) last choices persisted in Storage so the setup
    // screen remembers the user's most recent pick between launches.
    function lastDurationMin() as Number {
        try {
            var v = Application.Storage.getValue("lastDurationMin");
            if (v != null) { return v as Number; }
        } catch (e) {}
        return durationMin();
    }

    function setLastDurationMin(m as Number) as Void {
        try { Application.Storage.setValue("lastDurationMin", m); } catch (e) {}
    }

    function lastDifficulty() as Number {
        try {
            var v = Application.Storage.getValue("lastDifficulty");
            if (v != null) { return v as Number; }
        } catch (e) {}
        return difficulty();
    }

    function setLastDifficulty(d as Number) as Void {
        try { Application.Storage.setValue("lastDifficulty", d); } catch (e) {}
    }
}
