import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class TrioApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // Trio pushes every loop; the background service catches them while the
        // app is closed, so the screen is current the moment it opens.
        Background.registerForPhoneAppMessageEvent();
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new TrioServiceDelegate()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        TrioDemo.seed();
        Idle.start();
        Pairing.forgetLegacyPin();
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        if (System.getDeviceSettings().phoneConnected) {
            Communications.transmit("status", null, new StatusListener());
        }
        return [new TrioView(), new TrioDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        TrioData.save(data);
        WatchUi.requestUpdate();
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        // Replies to the watch's requests are dictionaries; loop data is an array.
        if (msg.data instanceof Dictionary) {
            var reply = msg.data as Dictionary;
            if ("bolusAck".equals(reply["t"])) {
                BolusFlow.onAck(reply);
            } else if ("pairAck".equals(reply["t"])) {
                Pairing.onAck(reply);
            }
            return;
        }
        TrioData.save(TrioData.compact(msg.data));
        WatchUi.requestUpdate();
    }

}

class StatusListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {}

    function onError() as Void {}
}
