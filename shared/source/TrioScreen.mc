import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Draws the Trio screen shared by the watch face and the watch app:
// loop status as an arc along the top edge; date and time; a large glucose
// value with trend arrow, delta and reading age; IOB / COB / basal with small
// labels; heart rate and battery at the bottom.
class TrioScreen {
    const LOW = 70;
    const HIGH = 180;

    const C_IOB = 0x3AA0FF;
    const C_COB = 0xFFAA00;
    const C_LOW = 0xFF3B30;
    const C_HIGH = 0xFFCC00;
    const C_OK = 0x00DD55;
    const C_LABEL = 0x888888;
    const C_STALE = 0x888888;
    const C_TRACK = 0x1C1C1C;

    function initialize() {}

    // lowPower: AMOLED always-on mode, where only a few pixels may stay lit.
    function draw(dc as Graphics.Dc, lowPower as Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var d = TrioData.get();
        var now = Time.now().value();
        var mmol = d != null && "mmol".equals(d["units"]);

        if (lowPower) {
            drawLowPower(dc, w, h, d, now, mmol);
            return;
        }

        drawLoopArc(dc, w, h, loopMinutes(d, now));
        drawCentered(dc, cx, (h * 0.13).toNumber(), Graphics.FONT_XTINY, C_LABEL, dateText());
        drawClock(dc, cx, (h * 0.205).toNumber(), Graphics.FONT_SMALL);
        drawGlucose(dc, w, (h * 0.425).toNumber(), d, now, mmol);
        drawTreatments(dc, w, h, d);
        drawVitals(dc, cx, (h * 0.868).toNumber(), Graphics.FONT_TINY);

        if (d != null && d["demo"] == true) {
            drawCentered(dc, cx, (h * 0.955).toNumber(), Graphics.FONT_XTINY, C_LOW, "DEMO DATA");
        }
    }

    // Thin arc along the top edge: green if the loop ran in the last 7 min,
    // yellow under 15, red after that, grey with no data. A dim track shows
    // the rest of the ring.
    private function drawLoopArc(dc as Graphics.Dc, w as Number, h as Number, mins as Number?) as Void {
        var r = w / 2 - 9;
        dc.setPenWidth(8);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(w / 2, h / 2, r);
        var color = mins == null ? C_STALE : mins < 7 ? C_OK : mins < 15 ? C_HIGH : C_LOW;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(w / 2, h / 2, r, Graphics.ARC_CLOCKWISE, 150, 30);
        dc.setPenWidth(1);
    }

    // "Mon 5th"
    private function dateText() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var day = info.day as Number;
        var suffix = "th";
        if (day % 100 < 11 || day % 100 > 13) {
            var last = day % 10;
            suffix = last == 1 ? "st" : last == 2 ? "nd" : last == 3 ? "rd" : "th";
        }
        return info.day_of_week + " " + day + suffix;
    }

    // Big glucose value with the arrow above the delta to its right, and the
    // reading's age underneath. Grey when the reading is over 15 min old.
    private function drawGlucose(dc as Graphics.Dc, w as Number, y as Number, d as Dictionary?, now as Number,
            mmol as Boolean) as Void {
        var sgv = d == null ? null : d["sgv"] as Number?;
        var bgTime = d == null ? null : d["bgTime"] as Number?;
        var stale = TrioData.isStale(bgTime, now);
        var color = sgv == null || stale ? C_STALE : colorFor(sgv);
        var bgText = glucoseText(d, mmol);
        var deltaText = deltaTextFor(d, mmol);

        var side = 70;
        var font = Graphics.FONT_NUMBER_HOT;
        if (dc.getTextWidthInPixels(bgText, font) + side > (w * 0.80).toNumber()) {
            font = Graphics.FONT_NUMBER_MEDIUM;
        }
        var bgW = dc.getTextWidthInPixels(bgText, font);
        var left = w / 2 - (bgW + side) / 2;
        drawLeft(dc, left, y, font, color, bgText);

        var sx = left + bgW + side / 2 + 4;
        if (d != null && d["dir"] != null && !stale) {
            drawTrend(dc, sx, y - 26, d["dir"] as String, color, 44);
        }
        drawCentered(dc, sx, y + 30, Graphics.FONT_SMALL, 0xCCCCCC, deltaText);

        var age = bgTime == null ? "No reading" : now < bgTime ? "Check watch time" : ageText((now - bgTime) / 60);
        var ageY = y + (dc.getFontHeight(font) * 0.42).toNumber();
        drawCentered(dc, w / 2, ageY, Graphics.FONT_XTINY, stale ? C_HIGH : C_LABEL, age);
    }

    private function ageText(mins as Number) as String {
        if (mins < 1) {
            return "Just now";
        }
        return mins < 120 ? mins + " min ago" : (mins / 60) + " h ago";
    }

    // IOB / COB / basal: coloured values over small grey labels, with thin
    // dividers between the three columns.
    private function drawTreatments(dc as Graphics.Dc, w as Number, h as Number, d as Dictionary?) as Void {
        var iob = d == null || d["iob"] == null ? "--" : (d["iob"] as Float).format("%.1f") + "u";
        var cob = d == null || d["cob"] == null ? "--" : (d["cob"] as Float).format("%.0f") + "g";
        var tbr = d == null || d["tbr"] == null ? "--" : formatRate(d["tbr"] as Float);
        var valueY = (h * 0.68).toNumber();
        // From measured heights: the font boxes carry extra space, but the
        // value's digits and the label's caps must never touch.
        var labelY = valueY + (dc.getFontHeight(Graphics.FONT_TINY) * 0.5).toNumber()
            + (dc.getFontHeight(Graphics.FONT_XTINY) * 0.5).toNumber() + 4;
        var col = (w * 0.25).toNumber();
        var xs = [w / 2 - col, w / 2, w / 2 + col];
        var labels = ["IOB", "COB", "BASAL"];
        var values = [iob, cob, tbr];
        // Grey when the loop data is old, so stale IOB isn't trusted for dosing.
        var loopStale = d == null || TrioData.isStale(d["loop"], Time.now().value());
        var colors = loopStale ? [C_STALE, C_STALE, C_STALE] : [C_IOB, C_COB, Graphics.COLOR_WHITE];
        for (var i = 0; i < 3; i++) {
            drawCentered(dc, xs[i], valueY, Graphics.FONT_TINY, colors[i], values[i]);
            drawCentered(dc, xs[i], labelY, Graphics.FONT_XTINY, C_LABEL, labels[i]);
        }
        var top = valueY - (dc.getFontHeight(Graphics.FONT_TINY) * 0.4).toNumber();
        var bottom = labelY + (dc.getFontHeight(Graphics.FONT_XTINY) * 0.35).toNumber();
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(w / 2 - col / 2, top, w / 2 - col / 2, bottom);
        dc.drawLine(w / 2 + col / 2, top, w / 2 + col / 2, bottom);
        dc.setPenWidth(1);
    }

    // Always-on view: time, glucose and arrow only, dimmed, and nudged a few
    // pixels each minute so no pixel stays lit in one spot (AMOLED burn-in).
    private function drawLowPower(dc as Graphics.Dc, w as Number, h as Number, d as Dictionary?, now as Number,
            mmol as Boolean) as Void {
        var shift = (System.getClockTime().min % 5) * 4 - 8;
        var cx = w / 2 + shift;
        var cy = h / 2 + shift;
        drawClock(dc, cx, cy - (h * 0.20).toNumber(), Graphics.FONT_MEDIUM);
        var sgv = d == null ? null : d["sgv"] as Number?;
        var bgStale = d == null || TrioData.isStale(d["bgTime"], now);
        var bgText = glucoseText(d, mmol);
        var dim = 0xAAAAAA;
        if (d != null && d["demo"] == true) {
            drawCentered(dc, cx, cy + (h * 0.18).toNumber(), Graphics.FONT_XTINY, 0x993333, "DEMO DATA");
        }
        var color = sgv == null || bgStale ? 0x666666 : sgv < LOW ? C_LOW : sgv > HIGH ? C_HIGH : dim;
        drawCentered(dc, cx, cy + (h * 0.04).toNumber(), Graphics.FONT_NUMBER_MEDIUM, color, bgText);
        if (d != null && d["dir"] != null && !bgStale) {
            var bgW = dc.getTextWidthInPixels(bgText, Graphics.FONT_NUMBER_MEDIUM);
            drawTrend(dc, cx + bgW / 2 + 26, cy + (h * 0.04).toNumber(), d["dir"] as String, color, 34);
        }
    }

    private function glucoseText(d as Dictionary?, mmol as Boolean) as String {
        var sgv = d == null ? null : d["sgv"] as Number?;
        return sgv == null ? "---" : formatBg(sgv, mmol);
    }

    private function deltaTextFor(d as Dictionary?, mmol as Boolean) as String {
        var delta = d == null ? null : d["delta"] as Number?;
        return delta == null ? "" : formatDelta(delta, mmol);
    }

    private function loopMinutes(d as Dictionary?, now as Number) as Number? {
        if (d == null || d["loop"] == null) {
            return null;
        }
        var mins = (now - (d["loop"] as Number)) / 60;
        return mins < 0 ? 0 : mins;
    }

    // Half-width of the round screen at height y.
    private function chordHalf(w as Number, y as Number) as Number {
        var r = w / 2.0;
        var dy = y - r;
        var sq = r * r - dy * dy;
        return sq > 0 ? Math.sqrt(sq).toNumber() : 0;
    }

    // --- rows -------------------------------------------------------------

    private function drawClock(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType) as Void {
        var t = System.getClockTime();
        var hour = t.hour;
        var text;
        if (System.getDeviceSettings().is24Hour) {
            text = hour.format("%02d") + ":" + t.min.format("%02d");
        } else {
            var suffix = hour >= 12 ? " PM" : " AM";
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
            text = hour + ":" + t.min.format("%02d") + suffix;
        }
        drawCentered(dc, x, y, font, Graphics.COLOR_WHITE, text);
    }

    // Heart rate and battery, centred as one group and shrunk a font size if the
    // round screen is too narrow at this height.
    private function drawVitals(dc as Graphics.Dc, cx as Number, y as Number, font as Graphics.FontType) as Void {
        var hr = null;
        var info = Activity.getActivityInfo();
        if (info != null) {
            hr = info.currentHeartRate;
        }
        var hrText = hr == null ? "--" : hr.toString();
        var battText = System.getSystemStats().battery.format("%d") + "%";
        var battery = System.getSystemStats().battery;

        var heartW = 24;
        var battIconW = 32;
        var f = font;
        var total = groupWidth(dc, f, heartW, battIconW, hrText, battText);
        var fits = 2 * (chordHalf(dc.getWidth(), y) - 12);
        if (total > fits) {
            f = Graphics.FONT_SMALL;
            total = groupWidth(dc, f, heartW, battIconW, hrText, battText);
        }
        var x = cx - total / 2;

        // heart
        var hx = x + heartW / 2;
        dc.setColor(C_LOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx - 5, y - 3, 6);
        dc.fillCircle(hx + 5, y - 3, 6);
        dc.fillPolygon([[hx - 11, y], [hx + 11, y], [hx, y + 12]]);
        x += heartW + 6;
        drawLeft(dc, x, y, f, Graphics.COLOR_WHITE, hrText);
        x += dc.getTextWidthInPixels(hrText, f) + 22;

        // battery, in grey so it sits behind the glucose data
        dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y - 8, 26, 16, 3);
        dc.fillRectangle(x + 26, y - 3, 3, 6);
        dc.fillRectangle(x + 3, y - 5, (20 * battery / 100).toNumber(), 10);
        dc.setPenWidth(1);
        x += battIconW + 6;
        drawLeft(dc, x, y, Graphics.FONT_XTINY, C_LABEL, battText);
    }

    private function groupWidth(dc as Graphics.Dc, f as Graphics.FontType, heartW as Number, battIconW as Number,
            hrText as String, battText as String) as Number {
        return heartW + 6 + dc.getTextWidthInPixels(hrText, f) + 22 + battIconW + 6
            + dc.getTextWidthInPixels(battText, Graphics.FONT_XTINY);
    }

    // --- glyphs -----------------------------------------------------------

    // Arrow angle in degrees (0 = right, 90 = up); Double* draws two heads.
    private function drawTrend(dc as Graphics.Dc, x as Number, y as Number, dir as String, color as Number,
            size as Number) as Void {
        var angle = null;
        var twin = false;
        if (dir.equals("DoubleUp")) { angle = 90; twin = true; }
        else if (dir.equals("SingleUp")) { angle = 90; }
        else if (dir.equals("FortyFiveUp")) { angle = 45; }
        else if (dir.equals("Flat")) { angle = 0; }
        else if (dir.equals("FortyFiveDown")) { angle = -45; }
        else if (dir.equals("SingleDown")) { angle = -90; }
        else if (dir.equals("DoubleDown")) { angle = -90; twin = true; }
        if (angle == null) {
            return;
        }
        if (twin) {
            drawArrow(dc, x - size / 4, y, angle, color, size);
            drawArrow(dc, x + size / 4, y, angle, color, size);
        } else {
            drawArrow(dc, x, y, angle, color, size);
        }
    }

    private function drawArrow(dc as Graphics.Dc, x as Number, y as Number, deg as Number, color as Number,
            size as Number) as Void {
        var r = Math.toRadians(deg);
        var dx = Math.cos(r);
        var dy = -Math.sin(r);
        var len = size / 2;
        var tipX = x + dx * len;
        var tipY = y + dy * len;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var head = size * 0.42;
        var wing = size * 0.28;
        dc.setPenWidth((size / 7).toNumber() + 1);
        dc.drawLine(x - dx * len, y - dy * len, tipX - dx * head / 2, tipY - dy * head / 2);
        dc.setPenWidth(1);
        // head: tip plus two points behind it, perpendicular to the shaft
        var bx = tipX - dx * head;
        var by = tipY - dy * head;
        dc.fillPolygon([[tipX, tipY], [bx - dy * wing, by + dx * wing], [bx + dy * wing, by - dx * wing]]);
    }

    // --- formatting -------------------------------------------------------

    private function colorFor(sgv as Number) as Number {
        return sgv < LOW ? C_LOW : sgv > HIGH ? C_HIGH : C_OK;
    }

    private function formatBg(sgv as Number, mmol as Boolean) as String {
        return mmol ? (sgv / 18.0).format("%.1f") : sgv.toString();
    }

    private function formatDelta(delta as Number, mmol as Boolean) as String {
        var sign = delta > 0 ? "+" : "";
        return sign + (mmol ? (delta / 18.0).format("%.1f") : delta.toString());
    }

    private function formatRate(tbr as Float) as String {
        return tbr == 0 ? "0" : tbr.format("%.2f");
    }

    private function drawCentered(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType,
            color as Number, text as String) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawLeft(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType,
            color as Number, text as String) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
