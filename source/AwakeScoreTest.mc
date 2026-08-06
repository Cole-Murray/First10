import Toybox.Lang;
import Toybox.Test;

// Unit tests for AwakeScore -- the anti-cheat pass/fail gate the whole app is
// built around. Pure logic, no sensor/UI dependency, so it needs no mocking.
//
// (:test)-annotated functions are compiled and run only when the project is
// built with the unit-test flag; they are stripped from normal debug/release
// builds automatically. Build and run:
//   monkeyc -f monkey.jungle -d fr265 -o bin/First10-test.prg -y developer_key.der --unit-test
//   connectiq
//   monkeydo bin/First10-test.prg fr265 -t
// (append a test function name after -t to run a single test).
//
// Difficulty presets are read live from Difficulty.forLevel() rather than
// hardcoded, so these tests fail loudly if a future retuning changes the
// weights/thresholds in a way that breaks the anti-cheat invariants they
// pin -- e.g. the Medium passMark bug these tests were written to guard
// against (see docs/solutions/architecture-patterns/sensor-degraded-mode-fallback.md).

(:test)
function testStepScoreZeroWhenNoStepsTaken(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);
    score.setBaseline(0, null);
    Test.assertEqual(score.stepScore(), 0.0);
    return true;
}

(:test)
function testStepScoreClampsAtFullCreditAndNeverNegative(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);

    score.setBaseline(0, null);
    score.updateSteps(cfg.requiredSteps * 2); // double the requirement
    Test.assertEqual(score.stepScore(), 1.0); // clamped to 1.0, not 2.0

    score.setBaseline(100, null);
    score.updateSteps(50); // "behind" the baseline -- delta would be negative
    Test.assertEqual(score.stepScore(), 0.0);
    return true;
}

(:test)
function testMotionScoreRequiresFullSustainAndResetsImmediately(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);

    score.updateMotion(cfg.motionThreshold);
    score.tick(cfg.motionSustainSec / 2.0);
    Test.assertEqual(score.motionScore(), 0.5);

    score.tick(cfg.motionSustainSec / 2.0); // sustain now complete
    Test.assertEqual(score.motionScore(), 1.0);

    score.updateMotion(0.0); // motion drops below threshold
    score.tick(0.1);
    Test.assertEqualMessage(score.motionScore(), 0.0,
        "motion sustain must reset immediately on drop, not decay gradually");
    return true;
}

(:test)
function testHrScoreZeroWithoutBaselineOrLiveReading(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);

    Test.assertEqual(score.hrScore(), 0.0); // neither baseline nor reading set

    score.setBaseline(0, 60);
    Test.assertEqual(score.hrScore(), 0.0); // baseline known, but no live reading yet
    return true;
}

(:test)
function testHrScoreClampsNegativeRiseToZero(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);

    score.setBaseline(0, 60);
    score.updateHeartRate(50); // dropped below the resting baseline
    Test.assertEqual(score.hrScore(), 0.0);
    return true;
}

(:test)
function testTotalMatchesHandComputedWeightedSum(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM); // wSteps=0.4, wMotion=0.35, wHr=0.25
    var score = new AwakeScore(cfg);

    score.setBaseline(0, 60);
    score.updateSteps(cfg.requiredSteps / 2);       // stepScore  = 0.5
    score.updateHeartRate(60 + (cfg.hrRiseBpm / 2)); // hrScore    = 0.5
    score.updateMotion(cfg.motionThreshold);
    score.tick(cfg.motionSustainSec / 2.0);          // motionScore = 0.5

    // 0.4*0.5 + 0.35*0.5 + 0.25*0.5 == 0.5 -> total() == 50
    logger.debug("total=" + score.total());
    Test.assertEqual(score.total(), 50);
    return true;
}

(:test)
function testHardRequiresARealHrRiseToPass(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.HARD);
    var score = new AwakeScore(cfg);

    score.setBaseline(0, 60);
    score.updateSteps(cfg.requiredSteps);
    score.updateHeartRate(60); // no rise at all -- still at resting baseline
    score.updateMotion(cfg.motionThreshold);

    var dt = cfg.motionSustainSec;
    if (cfg.holdSec > dt) { dt = cfg.holdSec; }
    score.tick(dt);

    Test.assertMessage(!score.passed(),
        "Hard must not pass with steps+motion maxed but zero HR rise");
    return true;
}

(:test)
function testHardPassesWhenAllThreeComponentsAreMaxed(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.HARD);
    var score = new AwakeScore(cfg);

    score.setBaseline(0, 60);
    score.updateSteps(cfg.requiredSteps);
    score.updateHeartRate(60 + cfg.hrRiseBpm); // full required rise
    score.updateMotion(cfg.motionThreshold);

    var dt = cfg.motionSustainSec;
    if (cfg.holdSec > dt) { dt = cfg.holdSec; }
    score.tick(dt);

    Test.assert(score.passed());
    return true;
}

// Hard's own weights happen to sum to exactly passMark, so total() alone
// already blocks a below-target HR rise (see the two tests above) -- this
// test isolates hrGate itself with a synthetic config where the weighted
// total is reachable via steps+motion ALONE (wHr=0.0), so a future retuning
// of Hard's real weights can't silently make the "mandatory" gate a no-op.
(:test)
function testMandatoryHrGateBlocksEvenWhenTotalAloneWouldPass(logger as Test.Logger) as Boolean {
    var cfg = new Difficulty.Config(
        Difficulty.HARD, 10, 100.0, 1.0, 10, true, 1.0, 50, 0.5, 0.5, 0.0
    );
    var score = new AwakeScore(cfg);

    score.setBaseline(0, null); // no HR baseline ever captured
    score.updateSteps(cfg.requiredSteps);
    score.updateMotion(cfg.motionThreshold);
    score.tick(cfg.motionSustainSec); // steps+motion alone: total() == 100 >= passMark(50)

    Test.assertMessage(!score.passed(),
        "hrGate must block passing even when total() clears passMark without any HR contribution");
    return true;
}

(:test)
function testHoldResetsWhenConditionDropsBeforeCompletion(logger as Test.Logger) as Boolean {
    // Single-axis synthetic config (wSteps=1.0, motion/HR weightless) isolates
    // the hold-timer state machine from difficulty-specific tuning: driving
    // steps down after they've already met the requirement isn't a realistic
    // sensor reading (real step counts never decrease), but it is the cleanest
    // way to exercise tick()'s "condition dropped -> holdAccum resets" branch.
    var cfg = new Difficulty.Config(
        Difficulty.MEDIUM, 10, 100.0, 0.0, 0, false, 2.0, 50, 1.0, 0.0, 0.0
    );
    var score = new AwakeScore(cfg);
    score.setBaseline(0, null);

    score.updateSteps(10); // condition met (total=100 >= passMark=50)
    score.tick(1.0);       // holdAccum = 1.0, short of holdSec(2.0)
    Test.assertMessage(!score.passed(), "must not pass before holdSec elapses");

    score.updateSteps(0); // condition drops (total=0 < passMark)
    score.tick(1.0);       // holdAccum must reset to 0, not keep accumulating to 2.0
    Test.assertMessage(!score.passed(),
        "a brief drop below the pass condition must reset the hold timer");

    score.updateSteps(10); // condition met again, hold restarts from 0
    score.tick(2.0);        // 0 + 2.0 >= holdSec(2.0)
    Test.assert(score.passed());
    return true;
}

(:test)
function testDisableHrRenormalizesMediumToFullyAchievableWithoutHr(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM); // wSteps=0.4, wMotion=0.35, wHr=0.25, passMark=90
    var score = new AwakeScore(cfg);

    score.disableHr();
    Test.assertEqual(cfg.wHr, 0.0);
    Test.assertMessage(!cfg.hrGate, "Medium's hrGate was already false and must stay false");
    var renormalizedSum = cfg.wSteps + cfg.wMotion;
    Test.assertMessage(renormalizedSum > 0.999 && renormalizedSum < 1.001,
        "wSteps+wMotion must renormalize to ~1.0 once wHr is zeroed");

    // Regression for the fixed bug: before disableHr(), maxing steps+motion
    // alone only reached 75, below Medium's passMark of 90 -- unpassable with
    // a dead HR sensor. After disableHr(), it must clear passMark.
    score.setBaseline(0, null);
    score.updateSteps(cfg.requiredSteps);
    score.updateMotion(cfg.motionThreshold);
    var dt = cfg.motionSustainSec;
    if (cfg.holdSec > dt) { dt = cfg.holdSec; }
    score.tick(dt);

    Test.assertMessage(score.total() >= cfg.passMark,
        "steps+motion alone must clear Medium's passMark once HR is disabled");
    Test.assert(score.passed());
    return true;
}

(:test)
function testDisableHrLiftsHardMandatoryGate(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.HARD);
    var score = new AwakeScore(cfg);

    Test.assertMessage(cfg.hrGate, "sanity check: Hard must start with the HR gate on");
    score.disableHr();
    Test.assertMessage(!cfg.hrGate, "disableHr() must lift Hard's mandatory HR gate");
    Test.assertEqual(cfg.wHr, 0.0);
    Test.assert(score.hrDisabled());
    return true;
}

(:test)
function testDisableHrIsIdempotent(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);

    score.disableHr();
    var wStepsAfterFirstCall = cfg.wSteps;
    var wMotionAfterFirstCall = cfg.wMotion;

    score.disableHr(); // must be a no-op the second time
    Test.assertEqualMessage(cfg.wSteps, wStepsAfterFirstCall,
        "a second disableHr() call must not renormalize weights again");
    Test.assertEqualMessage(cfg.wMotion, wMotionAfterFirstCall,
        "a second disableHr() call must not renormalize weights again");
    return true;
}

(:test)
function testStepsRemainingAndHrRiseNeverGoNegative(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);

    score.setBaseline(0, 60);
    score.updateSteps(cfg.requiredSteps + 500); // far past the requirement
    Test.assertEqual(score.stepsRemaining(), 0);

    score.updateHeartRate(10); // far below the resting baseline
    Test.assertEqual(score.hrRise(), 0);
    return true;
}

(:test)
function testProgressBlendsHoldFractionOnceScoreIsMaxed(logger as Test.Logger) as Boolean {
    var cfg = Difficulty.forLevel(Difficulty.MEDIUM);
    var score = new AwakeScore(cfg);
    score.setBaseline(0, 60);

    // Build motion sustain to full BEFORE steps/HR are set, so this tick
    // doesn't also satisfy the pass condition (total() stays 0 -- steps/HR
    // are still at their defaults) and holdAccum stays untouched at 0.
    score.updateMotion(cfg.motionThreshold);
    score.tick(cfg.motionSustainSec);

    // Now the pass condition is reachable; a small tick pushes holdAccum
    // partway through holdSec without immediately completing it.
    score.updateSteps(cfg.requiredSteps);
    score.updateHeartRate(60 + cfg.hrRiseBpm);
    score.tick(cfg.holdSec / 4.0);
    Test.assertMessage(!score.passed(), "holdSec has not elapsed yet");

    var p = score.progress();
    logger.debug("mid-hold progress=" + p);
    // scoreFrac is clamped to 1.0 (total >= passMark); holdFrac = 0.25, so
    // progress = 0.9 + 0.1*0.25 = 0.925. Use a tolerance band, not exact
    // equality -- Float math on 0.1 increments is not guaranteed bit-exact.
    Test.assertMessage(p > 0.92 && p < 0.93, "progress should sit mid-way through the 0.9-1.0 hold band");

    score.tick(cfg.holdSec); // comfortably finishes the hold
    Test.assert(score.passed());
    Test.assertMessage(score.progress() > 0.999, "progress must reach (clamp to) 1.0 once passed");
    return true;
}
