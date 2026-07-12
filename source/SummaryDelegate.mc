import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    var _view as SummaryView;

    function initialize(view as SummaryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START begins a fresh nap from the setup screen.
    function onSelect() as Boolean {
        var setup = new SetupView();
        WatchUi.switchToView(setup, new SetupDelegate(setup), WatchUi.SLIDE_RIGHT);
        return true;
    }

    // BACK exits the app entirely.
    function onBack() as Boolean {
        SensorManager.shutdown();
        System.exit();
        return true;
    }
}
