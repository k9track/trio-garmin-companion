import Toybox.Lang;
import Toybox.Time;

// Debug builds only: sample data so the simulator renders without a phone.
// The screen labels it "DEMO DATA" so it can never pass for a real reading.
module TrioDemo {
    (:debug)
    function seed() as Void {
        // Real data always wins; old demo data is refreshed so ages stay current.
        var existing = TrioData.get();
        if (existing != null && existing["demo"] != true) {
            return;
        }
        var now = Time.now().value();
        TrioData.save({
            "sgv" => 137, "delta" => -6, "dir" => "Flat", "units" => "mgdl",
            "iob" => 5.2, "cob" => 35.0, "tbr" => 0.0,
            "loop" => now - 60, "bgTime" => now - 60,
            "demo" => true
        });
    }

    (:release)
    function seed() as Void {}
}
