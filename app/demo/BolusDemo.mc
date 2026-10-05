import Toybox.Lang;
import Toybox.Timer;

// SCREENSHOT BUILDS ONLY (./build.sh screenshots). Pretends to be Trio so the
// simulator can show every status screen. Never in app/monkey.jungle builds.
// One repeating timer drives every fake reply: the watch limits live timers.
module BolusDemo {
    const TICK_MS = 2000;

    var _id as String = "";
    var _centi as Number = 0;
    var _pairing as Boolean = false;
    var _ticks as Number = 0;
    var _timer as Timer.Timer? = null;

    function active() as Boolean {
        return true;
    }

    function respond(id as String, centiUnits as Number) as Void {
        start(id, centiUnits, false);
    }

    function respondPair(id as String) as Void {
        start(id, 0, true);
    }

    function start(id as String, centi as Number, pairing as Boolean) as Void {
        _id = id;
        _centi = centi;
        _pairing = pairing;
        _ticks = 0;
        if (_timer == null) {
            _timer = new Timer.Timer();
            (_timer as Timer.Timer).start(new Lang.Method(BolusDemo, :tick), TICK_MS, true);
        }
    }

    function stop() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function tick() as Void {
        _ticks += 1;
        if (_pairing) {
            stop();
            Pairing.onAck({ "t" => "pairAck", "id" => _id, "ok" => true, "msg" => "Paired",
                "key" => "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f" });
        } else if (_ticks == 2) {
            if (_centi > 300) {
                stop();
                BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => false, "stage" => "rejected", "msg" => "Over watch max (3 U)" });
            } else if (_centi == 0) {
                stop();
                BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => true, "stage" => "done", "msg" => BolusFlow.carbs + " g logged" });
            } else {
                BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => true, "stage" => "delivering", "msg" => "Delivering " + BolusFlow.unitsText(_centi) });
            }
        } else if (_ticks >= 7) {
            stop();
            BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => true, "stage" => "done", "msg" => "Bolus started" });
        }
    }
}
