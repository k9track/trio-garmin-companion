import Toybox.Lang;

// Normal builds: no fake replies. app/demo/ has the screenshot version.
module BolusDemo {
    function active() as Boolean {
        return false;
    }

    function respond(id as String, centiUnits as Number) as Void {}

    function respondPair(id as String) as Void {}
}
