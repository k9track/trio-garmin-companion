import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

(:background)
class TrioServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        Background.exit(TrioData.compact(msg.data));
    }
}
