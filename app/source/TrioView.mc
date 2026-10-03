import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class TrioView extends WatchUi.View {
    private var _screen as TrioScreen = new TrioScreen();
    private var _timer as Timer.Timer?;
    private var _launchTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    // Launches straight into the bolus amount (the face already shows the data);
    // BACK from there lands on this screen.
    private var _openBolus as Boolean = true;

    function onShow() as Void {
        if (_openBolus) {
            _openBolus = false;
            var t = new Timer.Timer();
            t.start(method(:openBolus), 50, false);
            _launchTimer = t;
        }
        // Ages and the clock change without new data, so redraw periodically.
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:tick), 15000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function openBolus() as Void {
        _launchTimer = null;
        BolusFlow.begin(:bolus);
    }

    function tick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        _screen.draw(dc, false);
    }
}
