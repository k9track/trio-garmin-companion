import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Watch faces can't message the phone directly, so this relies entirely on
// Trio's background pushes (every loop) for its data.
(:background)
class TrioFaceApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Background.registerForPhoneAppMessageEvent();
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new TrioServiceDelegate()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        TrioDemo.seed();
        return [new TrioFaceView(), new TrioFaceDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        TrioData.save(data);
        WatchUi.requestUpdate();
    }
}
