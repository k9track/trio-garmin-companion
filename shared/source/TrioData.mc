import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Trio sends an array: entry 0 has every field (`date` = last loop run,
// `glucoseDate` = reading time); later entries are history readings. Compacted
// here so background memory and storage only hold what the screen draws.
(:background)
module TrioData {
    const KEY = "trio";

    function compact(raw as Object?) as Dictionary? {
        if (!(raw instanceof Array)) {
            return null;
        }
        var list = raw as Array;
        if (list.size() == 0 || !(list[0] instanceof Dictionary)) {
            return null;
        }
        // Only entry 0 is drawn; history entries are ignored so storage stays small.
        var e0 = list[0] as Dictionary;
        return {
            "sgv" => toNum(e0["sgv"]),
            "delta" => toNum(e0["delta"]),
            "dir" => e0["direction"] instanceof String ? e0["direction"] : null,
            "units" => e0["units_hint"] instanceof String ? e0["units_hint"] : null,
            "iob" => toFloat(e0["iob"]),
            "cob" => toFloat(e0["cob"]),
            "tbr" => toFloat(e0["tbr"]),
            "loop" => toSecs(e0["date"]),
            "bgTime" => toSecs(e0["glucoseDate"])
        };
    }

    // Older than 15 min, missing, or more than 2 min in the future (a clock that's
    // wrong must not make old data look fresh).
    function isStale(t as Object?, now as Number) as Boolean {
        if (!(t instanceof Number)) {
            return true;
        }
        var age = now - (t as Number);
        return age > 15 * 60 || age < -120;
    }

    function save(data as Application.PersistableType) as Void {
        if (data != null) {
            Application.Storage.setValue(KEY, data);
        }
    }

    function get() as Dictionary? {
        var v = Application.Storage.getValue(KEY);
        return v instanceof Dictionary ? v as Dictionary : null;
    }

    function toNum(v as Object?) as Number? {
        if (v instanceof Number) {
            return v as Number;
        } else if (v instanceof Long) {
            return (v as Long).toNumber();
        } else if (v instanceof Float) {
            return (v as Float).toNumber();
        } else if (v instanceof Double) {
            return (v as Double).toNumber();
        }
        return null;
    }

    function toFloat(v as Object?) as Float? {
        if (v instanceof Float) {
            return v as Float;
        } else if (v instanceof Double) {
            return (v as Double).toFloat();
        } else if (v instanceof Number) {
            return (v as Number).toFloat();
        } else if (v instanceof Long) {
            return (v as Long).toFloat();
        }
        return null;
    }

    // Trio timestamps are milliseconds since 1970, past 32-bit range.
    function toSecs(v as Object?) as Number? {
        if (v instanceof Long) {
            return ((v as Long) / 1000).toNumber();
        } else if (v instanceof Double) {
            return ((v as Double) / 1000).toNumber();
        } else if (v instanceof Float) {
            return ((v as Float) / 1000).toNumber();
        } else if (v instanceof Number) {
            return (v as Number) / 1000;
        }
        return null;
    }
}
