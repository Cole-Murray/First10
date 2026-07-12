import Toybox.Sensor;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// SensorManager owns all sensor access and, critically, is only started during
// the wake/dismissal phase (never during the nap). This keeps battery use tiny
// and avoids the known instability where continuously running sensor events can
// get a device app killed by the OS.
//
// It exposes three signals used by the Awake Score:
//   - steps   : cumulative device step count (ActivityMonitor, no permission)
//   - heart   : latest optical HR in bpm (may be null while it settles)
//   - motion  : a rolling "movement intensity" metric derived from the
//               high-frequency accelerometer, in milli-g of magnitude std-dev.
module SensorManager {

    var _running = false as Boolean;
    var _hr = null as Number?;
    var _motion = 0.0 as Float;      // EMA of accel magnitude std-dev (mg)
    var _hasGyro = false as Boolean; // whether gyro data is actually arriving
    var _accelListenerActive = false as Boolean;

    function isRunning() as Boolean {
        return _running;
    }

    // Whether the platform can supply what the Awake Score needs. Steps and HR
    // are the essentials; gyro is a bonus used only for the anti-cheat gait check.
    function heartRateSupported() as Boolean {
        return (Sensor has :setEnabledSensors) && (Sensor has :enableSensorEvents);
    }

    function highFreqSupported() as Boolean {
        return (Sensor has :registerSensorDataListener);
    }

    function gyroPresent() as Boolean {
        return _hasGyro;
    }

    function start() as Void {
        if (_running) {
            return;
        }
        _running = true;
        _hr = null;
        _motion = 0.0;
        _hasGyro = false;

        // Low-frequency optical HR via sensor info events (~1 Hz).
        if (heartRateSupported()) {
            try {
                Sensor.setEnabledSensors([ Sensor.SENSOR_HEARTRATE ]);
                Sensor.enableSensorEvents(method(:onSensorInfo));
            } catch (e) {
                System.println("HR enable failed: " + e.getErrorMessage());
            }
        }

        // High-frequency accelerometer (and gyro if present) for motion analysis.
        if (highFreqSupported()) {
            try {
                Sensor.registerSensorDataListener(method(:onSensorData), {
                    :period => 1,
                    :accelerometer => { :enabled => true, :sampleRate => 25 },
                    :gyroscope => { :enabled => true, :sampleRate => 25 }
                });
                _accelListenerActive = true;
            } catch (e) {
                System.println("accel listener failed: " + e.getErrorMessage());
            }
        }
    }

    function stop() as Void {
        shutdown();
    }

    // Safe to call even if never started.
    function shutdown() as Void {
        try {
            if (_accelListenerActive && (Sensor has :unregisterSensorDataListener)) {
                Sensor.unregisterSensorDataListener();
            }
        } catch (e) {}
        _accelListenerActive = false;

        try {
            if (Sensor has :enableSensorEvents) {
                Sensor.enableSensorEvents(null);
            }
            if (Sensor has :setEnabledSensors) {
                Sensor.setEnabledSensors([]);
            }
        } catch (e) {}

        _running = false;
    }

    function getHeartRate() as Number? {
        return _hr;
    }

    function getMotion() as Float {
        return _motion;
    }

    function getSteps() as Number {
        try {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.steps != null) {
                return info.steps;
            }
        } catch (e) {}
        return 0;
    }

    // ---- callbacks ----

    function onSensorInfo(info as Sensor.Info) as Void {
        if (info has :heartRate && info.heartRate != null) {
            _hr = info.heartRate;
        }
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        if (data has :accelerometerData && data.accelerometerData != null) {
            var accel = data.accelerometerData;
            var std = _magnitudeStdDev(accel.x, accel.y, accel.z);
            if (std != null) {
                // Exponential moving average so a single spike (a wrist flick)
                // does not immediately satisfy "sustained motion".
                _motion = (0.5 * _motion) + (0.5 * std);
            }
        }

        if (data has :gyroscopeData && data.gyroscopeData != null) {
            var gyro = data.gyroscopeData;
            if (gyro.x != null && gyro.x.size() > 0) {
                _hasGyro = true;
            }
        }
    }

    // Standard deviation of the per-sample acceleration magnitude across a batch.
    // A resting wrist sits near ~1000 mg with near-zero std; walking produces a
    // large, rhythmic std.
    function _magnitudeStdDev(xs as Array<Number>?, ys as Array<Number>?, zs as Array<Number>?) as Float? {
        if (xs == null || ys == null || zs == null) {
            return null;
        }
        var n = xs.size();
        if (n > ys.size()) { n = ys.size(); }
        if (n > zs.size()) { n = zs.size(); }
        if (n <= 1) {
            return null;
        }

        var sum = 0.0;
        var sumSq = 0.0;
        for (var i = 0; i < n; i++) {
            var x = xs[i].toFloat();
            var y = ys[i].toFloat();
            var z = zs[i].toFloat();
            var mag = Math.sqrt((x * x) + (y * y) + (z * z));
            sum += mag;
            sumSq += (mag * mag);
        }
        var mean = sum / n;
        var variance = (sumSq / n) - (mean * mean);
        if (variance < 0.0) {
            variance = 0.0;
        }
        return Math.sqrt(variance);
    }
}
