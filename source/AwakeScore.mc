import Toybox.Lang;

// AwakeScore turns live sensor signals into a single 0-100 "are you actually up?"
// score, and decides when the alarm may be dismissed.
//
// Design intent (the anti-cheat core of the product):
//   - steps  : you have to take real steps, not just wave your arm.
//   - motion : the movement has to be SUSTAINED (rolling EMA + a continuous
//              timer), so a single shake does nothing.
//   - hr     : your heart rate has to rise above the resting baseline measured
//              at wake time. Only real exertion (standing, walking) does this,
//              which is what defeats "shake the wrist and go back to sleep".
//
// On Hard, the HR rise is a mandatory gate; on Easy/Medium it is a weighted
// contributor. Passing additionally requires the condition to hold for holdSec
// so you cannot flick past 100 for a single instant.
class AwakeScore {

    var _cfg as Difficulty.Config;

    var _baseSteps as Number = 0;
    var _baseHr as Number? = null;

    var _steps as Number = 0;        // current cumulative steps
    var _hr as Number? = null;       // current HR
    var _motion as Float = 0.0;      // current motion metric (mg)

    var _motionSustain as Float = 0.0; // seconds of continuous qualifying motion
    var _holdAccum as Float = 0.0;     // seconds the pass condition has held
    var _passed as Boolean = false;

    var _hrDisabled as Boolean = false; // true once HR has been given up on for this session

    function initialize(cfg as Difficulty.Config) {
        _cfg = cfg;
    }

    // Give up on HR for the rest of this session: renormalize wSteps/wMotion
    // to fill the weight HR used to carry, zero out wHr, and lift Hard's
    // mandatory gate. Called once HR is confirmed unavailable (sensor
    // disabled/unsupported, or never produced a reading within the grace
    // period) so a dead HR sensor can't make the alarm harder than intended
    // -- or, on Hard, impossible -- instead of just not helping. Idempotent.
    function disableHr() as Void {
        if (_hrDisabled) {
            return;
        }
        _hrDisabled = true;
        var remaining = _cfg.wSteps + _cfg.wMotion;
        if (remaining > 0.0) {
            _cfg.wSteps = _cfg.wSteps / remaining;
            _cfg.wMotion = _cfg.wMotion / remaining;
        } else {
            // No difficulty preset actually zeroes both today, but fall back
            // to an even split rather than leaving both weights at 0.
            _cfg.wSteps = 0.5;
            _cfg.wMotion = 0.5;
        }
        _cfg.wHr = 0.0;
        _cfg.hrGate = false;
    }

    function hrDisabled() as Boolean {
        return _hrDisabled;
    }

    // Capture the resting baseline at the moment the wake phase begins (user is
    // typically still lying still for the first few seconds of the alarm).
    function setBaseline(steps as Number, hr as Number?) as Void {
        _baseSteps = steps;
        _baseHr = hr;
    }

    function updateSteps(steps as Number) as Void {
        _steps = steps;
    }

    function updateHeartRate(hr as Number?) as Void {
        _hr = hr;
        // If we never captured a resting HR, adopt the first reading as baseline.
        if (_baseHr == null && hr != null) {
            _baseHr = hr;
        }
    }

    function updateMotion(motion as Float) as Void {
        _motion = motion;
    }

    // Advance the sustained-motion and hold timers. Call once per tick with the
    // elapsed seconds since the previous tick.
    function tick(dtSec as Float) as Void {
        if (_motion >= _cfg.motionThreshold) {
            _motionSustain += dtSec;
        } else {
            _motionSustain = 0.0;
        }

        if (_conditionMet()) {
            _holdAccum += dtSec;
            if (_holdAccum >= _cfg.holdSec) {
                _passed = true;
            }
        } else {
            _holdAccum = 0.0;
        }
    }

    // ---- component scores, each 0.0 .. 1.0 ----

    function stepScore() as Float {
        if (_cfg.requiredSteps <= 0) {
            return 1.0;
        }
        var delta = _steps - _baseSteps;
        if (delta < 0) { delta = 0; }
        return _clamp01(delta.toFloat() / _cfg.requiredSteps.toFloat());
    }

    function motionScore() as Float {
        if (_cfg.motionSustainSec <= 0) {
            return 1.0;
        }
        return _clamp01(_motionSustain / _cfg.motionSustainSec);
    }

    function hrScore() as Float {
        if (_cfg.hrRiseBpm <= 0) {
            return 1.0;
        }
        if (_hr == null || _baseHr == null) {
            return 0.0;
        }
        var rise = _hr - _baseHr;
        if (rise < 0) { rise = 0; }
        return _clamp01(rise.toFloat() / _cfg.hrRiseBpm.toFloat());
    }

    // Weighted 0..100 score for display and threshold comparison.
    function total() as Number {
        var t = (_cfg.wSteps * stepScore())
              + (_cfg.wMotion * motionScore())
              + (_cfg.wHr * hrScore());
        return (t * 100.0).toNumber();
    }

    // Progress for the ring: blends how close the score is to the pass mark with
    // how much of the required hold has accumulated.
    function progress() as Float {
        var scoreFrac = _clamp01(total().toFloat() / _cfg.passMark.toFloat());
        if (scoreFrac < 1.0 || _cfg.holdSec <= 0) {
            return scoreFrac;
        }
        var holdFrac = _clamp01(_holdAccum / _cfg.holdSec);
        return _clamp01(0.9 + (0.1 * holdFrac));
    }

    function passed() as Boolean {
        return _passed;
    }

    function stepsRemaining() as Number {
        var r = _cfg.requiredSteps - (_steps - _baseSteps);
        if (r < 0) { r = 0; }
        return r;
    }

    function hrRise() as Number {
        if (_hr == null || _baseHr == null) {
            return 0;
        }
        var rise = _hr - _baseHr;
        if (rise < 0) { rise = 0; }
        return rise;
    }

    function baselineHr() as Number? {
        return _baseHr;
    }

    // ---- internals ----

    function _conditionMet() as Boolean {
        if (total() < _cfg.passMark) {
            return false;
        }
        // Anti-cheat gate: on Hard the full HR rise is mandatory regardless of
        // how many steps/motion were produced.
        if (_cfg.hrGate && hrScore() < 1.0) {
            return false;
        }
        return true;
    }

    function _clamp01(v as Float) as Float {
        if (v < 0.0) { return 0.0; }
        if (v > 1.0) { return 1.0; }
        return v;
    }
}
