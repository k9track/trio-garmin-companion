import Toybox.Lang;
import Toybox.Timer;

// SCREENSHOT BUILDS ONLY (./build.sh screenshots). Pretends to be Trio so the
// simulator can show every status screen. Never in app/monkey.jungle builds.
module BolusDemo {
    var _id as String = "";
    var _centi as Number = 0;
    var _t1 as Timer.Timer? = null;
    var _t2 as Timer.Timer? = null;

    function active() as Boolean {
        return true;
    }

    function respond(id as String, centiUnits as Number) as Void {
        _id = id;
        _centi = centiUnits;
        _t1 = new Timer.Timer();
        (_t1 as Timer.Timer).start(new Lang.Method(BolusDemo, :first), 4000, false);
    }

    function first() as Void {
        if (_centi > 300) {
            BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => false, "stage" => "rejected", "msg" => "Over watch max (3 U)" });
            return;
        }
        if (_centi == 0) {
            BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => true, "stage" => "done", "msg" => BolusFlow.carbs + " g logged" });
            return;
        }
        BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => true, "stage" => "delivering", "msg" => "Delivering " + BolusFlow.unitsText(_centi) });
        _t2 = new Timer.Timer();
        (_t2 as Timer.Timer).start(new Lang.Method(BolusDemo, :second), 10000, false);
    }

    function second() as Void {
        BolusFlow.onAck({ "t" => "bolusAck", "id" => _id, "ok" => true, "stage" => "done", "msg" => "Bolus started" });
    }
}
