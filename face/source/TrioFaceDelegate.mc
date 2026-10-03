import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Touch and hold the face to open the Trio Companion app (bolus menu is one
// START away). Watch faces can't launch apps directly; the app publishes a
// complication and the face exits to it.
class TrioFaceDelegate extends WatchUi.WatchFaceDelegate {
    const APP_LABEL = "Trio Companion";

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        // A face that crashes stops showing BG, so nothing here may throw.
        try {
            var id = findAppComplication();
            if (id == null) {
                System.println("Trio Companion app complication not found");
                return false;
            }
            Complications.exitTo(id);
            return true;
        } catch (e) {
            System.println("Opening Trio Companion failed: " + e.getErrorMessage());
            return false;
        }
    }

    // Looked up each time: the id changes if the app is reinstalled.
    private function findAppComplication() as Complications.Id? {
        var it = Complications.getComplications();
        var c = it.next();
        while (c != null) {
            if (c.getType() == Complications.COMPLICATION_TYPE_INVALID && APP_LABEL.equals(c.longLabel)) {
                return c.complicationId;
            }
            c = it.next();
        }
        return null;
    }
}
