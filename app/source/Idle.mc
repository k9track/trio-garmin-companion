import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Closes the app after 20 s without input, so an accidental launch from the
// face (something pressing the screen) ends on its own. Never closes while a
// request or pairing is in flight or its result is on screen.
module Idle {
    const LIMIT_MS = 20000;
    const CHECK_MS = 2000;

    var _last as Number = 0;
    var _timer as Timer.Timer? = null;

    function start() as Void {
        touch();
        if (_timer == null) {
            _timer = new Timer.Timer();
            (_timer as Timer.Timer).start(new Lang.Method(Idle, :check), CHECK_MS, true);
        }
    }

    function touch() as Void {
        _last = System.getTimer();
    }

    function check() as Void {
        if (BolusDemo.active() || BolusFlow.stage != BolusFlow.IDLE || Pairing.state != Pairing.IDLE) {
            touch();
            return;
        }
        if (System.getTimer() - _last >= LIMIT_MS) {
            System.exit();
        }
    }
}

// Every screen's delegate extends this so any key, tap or swipe counts as activity.
class IdleDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        Idle.touch();
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        Idle.touch();
        return BehaviorDelegate.onTap(evt);
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        Idle.touch();
        return BehaviorDelegate.onSwipe(evt);
    }
}
