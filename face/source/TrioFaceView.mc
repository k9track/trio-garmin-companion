import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class TrioFaceView extends WatchUi.WatchFace {
    private var _screen as TrioScreen = new TrioScreen();
    private var _sleeping as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        _screen.draw(dc, _sleeping);
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }
}
