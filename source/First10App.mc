import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// First10 is a device app (not a widget/glance) launched from the apps menu so
// that it does NOT get the 1-2 minute inactivity timeout that glance-launched
// apps receive. It intentionally has no getGlanceView().
class First10App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        // Defensive: make sure sensors are never left running when the app exits.
        SensorManager.shutdown();
    }

    function getInitialView() {
        var view = new SetupView();
        return [view, new SetupDelegate(view)];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

function getApp() as First10App {
    return Application.getApp() as First10App;
}
