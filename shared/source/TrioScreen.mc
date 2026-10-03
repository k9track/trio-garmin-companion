import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

// Draws the Trio screen shared by the watch face and the watch app. Layout
// mirrors the Trio watch face rows (time; IOB / COB / temp basal; delta /
// glucose / trend / loop age + ring), with a 2 h trend graph and heart rate /
// battery below.
class TrioScreen {
    const LOW = 70;
    const HIGH = 180;
    const GRAPH_MIN = 40;
    const GRAPH_MAX = 250;
    const GRAPH_SPAN_SECS = 7200;

    const C_IOB = 0x22AAFF;
    const C_COB = 0xFFAA00;
    const C_LOW = 0xFF3B30;
    const C_HIGH = 0xFFCC00;
    const C_OK = 0x00DD55;
    const C_LINE = 0x555555;

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

        var fRow = Graphics.FONT_LARGE;
        var fBg = pickGlucoseFont(dc, w, d, now, mmol, fRow, Graphics.FONT_MEDIUM);
        var fSide = Graphics.FONT_MEDIUM;
        var hRow = dc.getFontHeight(fRow);
        var hBg = dc.getFontHeight(fBg);
        var hSide = dc.getFontHeight(fSide);

        // Rows stack from the top using measured font heights so larger fonts
        // never collide; the graph takes whatever height is left.
        var y = (h * 0.07).toNumber();
        drawClock(dc, cx, y + hRow / 2, fRow);
        y += hRow;

        // Row 1: IOB / COB / temp basal, spread evenly across the screen at this height
        var r1 = y + hRow / 2;
        var iobText = d == null || d["iob"] == null ? "--u" : (d["iob"] as Float).format("%.1f") + "u";
        var cobText = d == null || d["cob"] == null ? "--g" : (d["cob"] as Float).format("%.0f") + "g";
        var tbrText = d == null || d["tbr"] == null ? "--" : formatRate(d["tbr"] as Float);
        var glyphW = 30;
        var iobW = dc.getTextWidthInPixels(iobText, fRow);
        var cobW = dc.getTextWidthInPixels(cobText, fRow);
        var tbrW = glyphW + dc.getTextWidthInPixels(tbrText, fRow);
        var rowSpan = 2 * (chordHalf(w, r1) - 14);
        var rowGap = (rowSpan - iobW - cobW - tbrW) / 2;
        rowGap = rowGap < 10 ? 10 : rowGap > 46 ? 46 : rowGap;
        var rx = cx - (iobW + cobW + tbrW + 2 * rowGap) / 2;
        drawLeft(dc, rx, r1, fRow, C_IOB, iobText);
        rx += iobW + rowGap;
        drawLeft(dc, rx, r1, fRow, C_COB, cobText);
        rx += cobW + rowGap;
        drawBasalGlyph(dc, rx + 12, r1);
        drawLeft(dc, rx + glyphW, r1, fRow, Graphics.COLOR_WHITE, tbrText);
        y += hRow + 2;

        drawRule(dc, w, y);

        // Row 2: delta / glucose + arrow / loop age + ring
        var r2 = y + (hBg * 0.47).toNumber();
        drawGlucoseRow(dc, w, r2, hBg, d, now, mmol, fRow, fBg, fSide);
        y = r2 + (hBg * 0.36).toNumber();

        drawRule(dc, w, y);

        // 2 h trend graph fills the gap above the vitals row
        var vitalsY = (h * 0.885).toNumber();
        var gx = (w * 0.14).toNumber();
        var gw = (w * 0.72).toNumber();
        var gy = y + 6;
        var gh = vitalsY - hSide / 2 - 6 - gy;
        if (gh < 30) {
            gh = 30;
        }
        if (d != null && d["hist"] instanceof Array && (d["hist"] as Array).size() > 0) {
            drawGraph(dc, d["hist"] as Array<Number>, d["histT"] as Array<Number>, gx, gy, gw, gh, now);
        } else {
            drawCentered(dc, cx, gy + gh / 2, Graphics.FONT_SMALL, 0x888888, "Waiting for Trio...");
        }

        drawVitals(dc, cx, vitalsY, fSide);

        if (d != null && d["demo"] == true) {
            drawCentered(dc, cx, (h * 0.04).toNumber() + 6, Graphics.FONT_XTINY, C_LOW, "DEMO DATA");
        }
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
        var bgStale = d == null || d["bgTime"] == null || now - (d["bgTime"] as Number) > 15 * 60;
        var bgText = glucoseText(d, mmol);
        var dim = 0xAAAAAA;
        var color = sgv == null || bgStale ? 0x666666 : sgv < LOW ? C_LOW : sgv > HIGH ? C_HIGH : dim;
        drawCentered(dc, cx, cy + (h * 0.04).toNumber(), Graphics.FONT_NUMBER_MEDIUM, color, bgText);
        if (d != null && d["dir"] != null && !bgStale) {
            var bgW = dc.getTextWidthInPixels(bgText, Graphics.FONT_NUMBER_MEDIUM);
            drawTrend(dc, cx + bgW / 2 + 26, cy + (h * 0.04).toNumber(), d["dir"] as String, color, 34);
        }
    }

    private function drawGlucoseRow(dc as Graphics.Dc, w as Number, y as Number, hBg as Number, d as Dictionary?,
            now as Number, mmol as Boolean, fDelta as Graphics.FontType, fBg as Graphics.FontType,
            fAge as Graphics.FontType) as Void {
        var sgv = d == null ? null : d["sgv"] as Number?;
        var bgStale = d == null || d["bgTime"] == null || now - (d["bgTime"] as Number) > 15 * 60;
        var bgText = glucoseText(d, mmol);
        var bgColor = sgv == null || bgStale ? 0x888888 : colorFor(sgv);
        var deltaText = deltaTextFor(d, mmol);
        var mins = loopMinutes(d, now);
        var ageText = mins == null ? "--" : mins + "m";
        var ringColor = mins == null ? 0x888888 : mins < 7 ? C_OK : mins < 15 ? C_HIGH : C_LOW;

        var gap = 14;
        var arrowW = (hBg * 0.34).toNumber();
        var ringR = 18;
        var deltaW = dc.getTextWidthInPixels(deltaText, fDelta);
        var bgW = dc.getTextWidthInPixels(bgText, fBg);
        var ageW = dc.getTextWidthInPixels(ageText, fAge);
        var total = glucoseRowWidth(dc, d, now, mmol, fDelta, fBg, fAge);
        var x = w / 2 - total / 2;

        drawLeft(dc, x, y, fDelta, Graphics.COLOR_WHITE, deltaText);
        x += deltaW + gap;
        drawLeft(dc, x, y, fBg, bgColor, bgText);
        x += bgW + gap;
        if (d != null && d["dir"] != null && !bgStale) {
            drawTrend(dc, x + arrowW / 2, y, d["dir"] as String, bgColor, arrowW);
        }
        x += arrowW + gap;
        drawLeft(dc, x, y, fAge, Graphics.COLOR_WHITE, ageText);
        x += ageW + 8;
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(7);
        dc.drawCircle(x + ringR, y, ringR);
        dc.setPenWidth(1);
    }

    // Biggest number font whose glucose row fits across the screen.
    private function pickGlucoseFont(dc as Graphics.Dc, w as Number, d as Dictionary?, now as Number,
            mmol as Boolean, fDelta as Graphics.FontType, fAge as Graphics.FontType) as Graphics.FontType {
        var fits = (w * 0.84).toNumber();
        var candidates = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD];
        for (var i = 0; i < candidates.size(); i++) {
            var f = candidates[i] as Graphics.FontType;
            if (glucoseRowWidth(dc, d, now, mmol, fDelta, f, fAge) <= fits) {
                return f;
            }
        }
        return Graphics.FONT_NUMBER_MILD;
    }

    private function glucoseRowWidth(dc as Graphics.Dc, d as Dictionary?, now as Number, mmol as Boolean,
            fDelta as Graphics.FontType, fBg as Graphics.FontType, fAge as Graphics.FontType) as Number {
        var mins = loopMinutes(d, now);
        var gap = 14;
        var arrowW = (dc.getFontHeight(fBg) * 0.34).toNumber();
        return dc.getTextWidthInPixels(deltaTextFor(d, mmol), fDelta) + gap
            + dc.getTextWidthInPixels(glucoseText(d, mmol), fBg) + gap + arrowW + gap
            + dc.getTextWidthInPixels(mins == null ? "--" : mins + "m", fAge) + 8 + 36;
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

        // battery
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y - 8, 26, 16, 3);
        dc.fillRectangle(x + 26, y - 3, 3, 6);
        dc.fillRectangle(x + 3, y - 5, (20 * battery / 100).toNumber(), 10);
        dc.setPenWidth(1);
        x += battIconW + 6;
        drawLeft(dc, x, y, f, Graphics.COLOR_WHITE, battText);
    }

    private function groupWidth(dc as Graphics.Dc, f as Graphics.FontType, heartW as Number, battIconW as Number,
            hrText as String, battText as String) as Number {
        return heartW + 6 + dc.getTextWidthInPixels(hrText, f) + 22 + battIconW + 6
            + dc.getTextWidthInPixels(battText, f);
    }

    // --- graph ------------------------------------------------------------

    private function drawGraph(dc as Graphics.Dc, hist as Array<Number>, histT as Array<Number>,
            x as Number, y as Number, w as Number, h as Number, now as Number) as Void {
        var start = now - GRAPH_SPAN_SECS;
        drawDashed(dc, x, yFor(LOW, y, h), w, C_LOW);
        drawDashed(dc, x, yFor(HIGH, y, h), w, C_HIGH);
        for (var i = 0; i < hist.size() && i < histT.size(); i++) {
            var t = histT[i];
            if (t < start) {
                continue;
            }
            var px = x + (w * (t - start) / GRAPH_SPAN_SECS);
            dc.setColor(colorFor(hist[i]), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, yFor(hist[i], y, h), 5);
        }
    }

    private function yFor(v as Number, y as Number, h as Number) as Number {
        var c = v < GRAPH_MIN ? GRAPH_MIN : v > GRAPH_MAX ? GRAPH_MAX : v;
        return y + h - (h * (c - GRAPH_MIN) / (GRAPH_MAX - GRAPH_MIN));
    }

    private function drawDashed(dc as Graphics.Dc, x as Number, y as Number, w as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < w; i += 10) {
            dc.drawLine(x + i, y, x + i + 5, y);
        }
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

    private function drawBasalGlyph(dc as Graphics.Dc, x as Number, y as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(x - 12, y + 8, x - 6, y + 8);
        dc.drawLine(x - 6, y + 8, x - 6, y - 6);
        dc.drawLine(x - 6, y - 6, x + 4, y - 6);
        dc.drawLine(x + 4, y - 6, x + 4, y + 8);
        dc.drawLine(x + 4, y + 8, x + 10, y + 8);
        dc.setPenWidth(1);
    }

    private function drawRule(dc as Graphics.Dc, w as Number, y as Number) as Void {
        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((w * 0.12).toNumber(), y, (w * 0.88).toNumber(), y);
        dc.setPenWidth(1);
    }

    // --- formatting -------------------------------------------------------

    private function colorFor(sgv as Number) as Number {
        return sgv < LOW ? C_LOW : sgv > HIGH ? C_HIGH : Graphics.COLOR_WHITE;
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
