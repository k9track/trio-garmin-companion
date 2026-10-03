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
        var hist = [] as Array<Number>;
        var histT = [] as Array<Number>;
        for (var i = 0; i < 24; i++) {
            hist.add(150 - i * 2 + (i % 5) * 4);
            histT.add(now - 60 - i * 300);
        }
        TrioData.save({
            "sgv" => 137, "delta" => -6, "dir" => "Flat", "units" => "mgdl",
            "iob" => 5.2, "cob" => 35.0, "tbr" => 0.0,
            "loop" => now - 60, "bgTime" => now - 60,
            "hist" => hist, "histT" => histT, "demo" => true
        });
    }

    (:release)
    function seed() as Void {}
}
