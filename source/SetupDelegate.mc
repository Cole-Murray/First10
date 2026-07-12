import Toybox.WatchUi;
import Toybox.Lang;

class SetupDelegate extends WatchUi.BehaviorDelegate {

    var _view as SetupView;

    function initialize(view as SetupView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.nextDuration();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.prevDuration();
        return true;
    }

    function onMenu() as Boolean {
        _view.cycleDifficulty();
        return true;
    }

    // START / tap begins the nap.
    function onSelect() as Boolean {
        _startNap();
        return true;
    }

    function _startNap() as Void {
        var durationSec = _view.durationMinutes() * 60;
        var view = new NappingView(durationSec, _view.difficulty());
        WatchUi.switchToView(view, new NappingDelegate(view), WatchUi.SLIDE_LEFT);
    }
}
