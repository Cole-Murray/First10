import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class AlarmDelegate extends WatchUi.BehaviorDelegate {

    var _view as AlarmView;

    // Emergency dismissal: 5 BACK presses within 3 seconds. This is deliberately
    // awkward so it can't be done half-asleep by reflex, but guarantees no one is
    // ever trapped by the alarm.
    const EMERGENCY_PRESSES = 5;
    const EMERGENCY_WINDOW_MS = 3000;
    var _backCount as Number = 0;
    var _firstBackMs as Number = 0;

    function initialize(view as AlarmView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // SELECT/START = snooze.
    function onSelect() as Boolean {
        _view.snooze();
        return true;
    }

    // Swallow page keys so they don't do anything unexpected.
    function onNextPage() as Boolean {
        return true;
    }

    function onPreviousPage() as Boolean {
        return true;
    }

    function onMenu() as Boolean {
        return true;
    }

    // BACK does NOT exit. It only contributes to the emergency-dismiss combo.
    function onBack() as Boolean {
        var now = System.getTimer();
        if (_backCount == 0 || (now - _firstBackMs) > EMERGENCY_WINDOW_MS) {
            _backCount = 1;
            _firstBackMs = now;
        } else {
            _backCount++;
        }
        if (_backCount >= EMERGENCY_PRESSES) {
            _backCount = 0;
            _view.emergencyDismiss();
        }
        return true;
    }
}
