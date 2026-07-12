import Toybox.Lang;

// Difficulty presets. These are the tuned thresholds the Awake Score is measured
// against. They intentionally scale ALL three axes together (steps, sustained
// motion, HR rise) plus the required hold time, so higher difficulty is both
// harder to satisfy and harder to fake.
module Difficulty {

    enum {
        EASY = 0,
        MEDIUM = 1,
        HARD = 2
    }

    // A single difficulty configuration. Motion threshold is in milli-g of the
    // accelerometer magnitude std-dev (see SensorManager); hrRiseBpm is how far
    // above the measured resting baseline the heart rate must climb.
    class Config {
        var level as Number;
        var requiredSteps as Number;
        var motionThreshold as Float;   // mg std-dev that counts as "moving"
        var motionSustainSec as Float;  // seconds of continuous motion for full credit
        var hrRiseBpm as Number;        // required HR rise above baseline
        var hrGate as Boolean;          // if true, cannot pass without the full HR rise
        var holdSec as Float;           // seconds the pass condition must hold
        var passMark as Number;         // 0..100 score needed
        var wSteps as Float;
        var wMotion as Float;
        var wHr as Float;

        function initialize(
            lvl as Number,
            steps as Number,
            motion as Float,
            motionSustain as Float,
            hrRise as Number,
            gate as Boolean,
            hold as Float,
            mark as Number,
            ws as Float,
            wm as Float,
            wh as Float
        ) {
            level = lvl;
            requiredSteps = steps;
            motionThreshold = motion;
            motionSustainSec = motionSustain;
            hrRiseBpm = hrRise;
            hrGate = gate;
            holdSec = hold;
            passMark = mark;
            wSteps = ws;
            wMotion = wm;
            wHr = wh;
        }
    }

    function forLevel(level as Number) as Config {
        if (level <= EASY) {
            // Easy: "just get moving". No HR requirement (weight 0) so it works
            // even before the optical sensor has settled. Good for testing and
            // for people who only need a nudge.
            return new Config(EASY, 15, 80.0, 6.0, 0, false, 1.0, 85, 0.6, 0.4, 0.0);
        } else if (level == MEDIUM) {
            // Medium (default): steps + sustained motion + a modest HR rise.
            return new Config(MEDIUM, 30, 150.0, 10.0, 8, false, 2.0, 90, 0.4, 0.35, 0.25);
        } else {
            // Hard: high thresholds and the HR rise is a hard gate, so shaking
            // the wrist in bed cannot satisfy it - only actually standing up and
            // walking raises the heart rate enough.
            return new Config(HARD, 45, 250.0, 15.0, 12, true, 3.0, 100, 0.34, 0.33, 0.33);
        }
    }

    function name(level as Number) as String {
        if (level <= EASY) {
            return "Easy";
        } else if (level == MEDIUM) {
            return "Medium";
        }
        return "Hard";
    }
}
