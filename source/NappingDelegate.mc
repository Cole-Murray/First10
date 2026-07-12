import Toybox.WatchUi;
import Toybox.Lang;

class NappingDelegate extends WatchUi.BehaviorDelegate {

    var _view as NappingView;

    function initialize(view as NappingView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Any button/tap other than BACK just peeks at the remaining time.
    function onSelect() as Boolean {
        _view.peek();
        return true;
    }

    function onNextPage() as Boolean {
        _view.peek();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.peek();
        return true;
    }

    // BACK cancels the nap and returns to setup.
    function onBack() as Boolean {
        var setup = new SetupView();
        WatchUi.switchToView(setup, new SetupDelegate(setup), WatchUi.SLIDE_RIGHT);
        return true;
    }
}
