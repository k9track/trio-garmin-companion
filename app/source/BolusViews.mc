import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Screens for BolusFlow. Buttons: UP/DOWN change, START accepts, BACK goes back.
// Touch swipes map to the same UP/DOWN behaviour.

const C_OK = 0x00DD55;
const C_BAD = 0xFF3B30;
const C_WARN = 0xFFCC00;
const C_DIM = 0xAAAAAA;
const C_SEL = 0x22AAFF;

function clearScreen(dc as Graphics.Dc) as Void {
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();
}

function centerText(dc as Graphics.Dc, y as Number, font as Graphics.FontType, color as Number, text as String) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.drawText(dc.getWidth() / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
}

// BG and IOB from the latest Trio data, so the amount is chosen with them in view.
function contextLine() as String {
    var d = TrioData.get();
    if (d == null) {
        return "No Trio data";
    }
    var parts = "";
    if (d["sgv"] != null) {
        var sgv = d["sgv"] as Number;
        var bg = "mmol".equals(d["units"]) ? (sgv / 18.0).format("%.1f") : sgv.toString();
        var bgTime = d["bgTime"];
        var stale = bgTime instanceof Number && Time.now().value() - (bgTime as Number) > 900;
        parts = "BG " + bg + (stale ? " (old)" : "");
    }
    if (d["iob"] != null) {
        parts += (parts.length() > 0 ? "  " : "") + "IOB " + (d["iob"] as Float).format("%.2f");
    }
    return parts;
}

// MARK: - Amount picker

class AmountView extends WatchUi.View {
    var kind as Symbol;
    var value as Number = 0;
    private var _lastPress as Number = 0;
    private var _streak as Number = 0;

    function initialize(kind as Symbol) {
        View.initialize();
        self.kind = kind;
    }

    function step() as Number {
        // Quick repeated presses speed up: 0.1 → 0.5 U, 1 → 5 g.
        var big = _streak >= 3;
        return kind == :carbs ? (big ? 5 : 1) : (big ? 50 : 10);
    }

    function max() as Number {
        // Trio enforces the real limits; these just bound the picker.
        return kind == :carbs ? 250 : 1500;
    }

    function change(dir as Number) as Void {
        var now = System.getTimer();
        _streak = now - _lastPress < 450 ? _streak + 1 : 0;
        _lastPress = now;
        var s = step();
        var v = value + dir * s;
        // Snap to the step so speeding up doesn't leave odd values.
        v = (v / s) * s;
        value = v < 0 ? 0 : v > max() ? max() : v;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        clearScreen(dc);
        var h = dc.getHeight();
        var isCarbs = kind == :carbs;
        centerText(dc, (h * 0.17).toNumber(), Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE, isCarbs ? "Carbs" : "Insulin");
        if (!isCarbs && BolusFlow.carbs > 0) {
            centerText(dc, (h * 0.27).toNumber(), Graphics.FONT_SMALL, 0xFFAA00, "with " + BolusFlow.carbs + " g carbs");
        }
        var text = isCarbs ? value.toString() : (value / 100.0).format("%.1f");
        centerText(dc, (h * 0.45).toNumber(), Graphics.FONT_NUMBER_HOT, Graphics.COLOR_WHITE, text);
        centerText(dc, (h * 0.615).toNumber(), Graphics.FONT_MEDIUM, C_DIM, isCarbs ? "grams" : "units");
        centerText(dc, (h * 0.715).toNumber(), Graphics.FONT_SMALL, C_DIM, contextLine());
        centerText(dc, (h * 0.81).toNumber(), Graphics.FONT_XTINY, C_DIM, "Hold UP for menu");
    }
}

class AmountDelegate extends IdleDelegate {
    private var _view as AmountView;

    function initialize(view as AmountView) {
        IdleDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() as Boolean {
        _view.change(1);
        return true;
    }

    function onNextPage() as Boolean {
        _view.change(-1);
        return true;
    }

    function onSelect() as Boolean {
        BolusFlow.amountChosen(_view.kind, _view.value);
        return true;
    }

    // Long-press UP: Carbs + Bolus, Set PIN.
    function onMenu() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        openTrioMenu();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

// MARK: - Confirm

const HOLD_STEPS = 10;
const HOLD_STEP_MS = 100;

// Delivers only after START (or a finger) is held for about a second, with a
// ring filling around the edge. A short press does nothing, so a double press
// from the amount screen can't send a bolus.
class ConfirmView extends WatchUi.View {
    var progress as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        clearScreen(dc);
        var h = dc.getHeight();
        var w = dc.getWidth();
        centerText(dc, (h * 0.20).toNumber(), Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE, "Deliver");
        // Fixed rows so the carbs line never runs into "Hold START" below.
        if (BolusFlow.centiUnits > 0) {
            centerText(dc, (h * 0.37).toNumber(), Graphics.FONT_NUMBER_MEDIUM, 0x22AAFF, BolusFlow.unitsText(BolusFlow.centiUnits));
            if (BolusFlow.carbs > 0) {
                centerText(dc, (h * 0.535).toNumber(), Graphics.FONT_MEDIUM, 0xFFAA00, "+ " + BolusFlow.carbs + " g carbs");
            }
        } else {
            centerText(dc, (h * 0.42).toNumber(), Graphics.FONT_NUMBER_MEDIUM, 0xFFAA00, BolusFlow.carbs + " g");
        }
        var holding = progress > 0;
        centerText(dc, (h * 0.68).toNumber(), Graphics.FONT_MEDIUM, holding ? C_OK : Graphics.COLOR_WHITE,
            holding ? "Keep holding" : "Hold START");
        centerText(dc, (h * 0.79).toNumber(), Graphics.FONT_XTINY, C_DIM, "BACK to cancel");

        if (holding) {
            dc.setColor(C_OK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(10);
            var sweep = 360 * progress / HOLD_STEPS;
            dc.drawArc(w / 2, h / 2, w / 2 - 6, Graphics.ARC_CLOCKWISE, 90, 90 - sweep);
        }
    }
}

class ConfirmDelegate extends IdleDelegate {
    private var _view as ConfirmView;
    private var _timer as Timer.Timer?;
    private var _sent as Boolean = false;

    function initialize(view as ConfirmView) {
        IdleDelegate.initialize();
        _view = view;
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        Idle.touch();
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            startHold();
            return true;
        }
        return false;
    }

    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            cancelHold();
            return true;
        }
        return false;
    }

    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        Idle.touch();
        startHold();
        return true;
    }

    function onRelease(evt as WatchUi.ClickEvent) as Boolean {
        cancelHold();
        return true;
    }

    // Short presses and taps deliberately do nothing here (screenshot builds
    // start the hold on a tap, since the simulator can't easily hold START).
    function onSelect() as Boolean {
        if (BolusDemo.active()) {
            startHold();
        }
        return true;
    }

    function onBack() as Boolean {
        cancelHold();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    private function startHold() as Void {
        if (_sent || _timer != null) {
            return;
        }
        _view.progress = 1;
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:step), BolusDemo.active() ? 400 : HOLD_STEP_MS, true);
        WatchUi.requestUpdate();
    }

    private function cancelHold() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
        if (!_sent) {
            _view.progress = 0;
            WatchUi.requestUpdate();
        }
    }

    function step() as Void {
        _view.progress += 1;
        if (_view.progress >= HOLD_STEPS) {
            cancelHold();
            _sent = true;
            BolusFlow.send();
        } else {
            WatchUi.requestUpdate();
        }
    }
}

// MARK: - Status

class StatusView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        clearScreen(dc);
        var h = dc.getHeight();
        var w = dc.getWidth();
        var title = "Sending...";
        var color = Graphics.COLOR_WHITE;
        switch (BolusFlow.stage) {
            case BolusFlow.DELIVERING:
                title = "Delivering";
                break;
            case BolusFlow.DONE:
                title = "Done";
                color = C_OK;
                break;
            case BolusFlow.FAILED:
                title = "Not delivered";
                color = C_BAD;
                break;
            case BolusFlow.NO_REPLY:
                title = "Check Trio";
                color = C_WARN;
                break;
        }
        centerText(dc, (h * 0.30).toNumber(), Graphics.FONT_LARGE, color, title);

        var summary = BolusFlow.centiUnits > 0 ? BolusFlow.unitsText(BolusFlow.centiUnits) : "";
        if (BolusFlow.carbs > 0) {
            summary += (summary.length() > 0 ? " + " : "") + BolusFlow.carbs + " g";
        }
        centerText(dc, (h * 0.44).toNumber(), Graphics.FONT_MEDIUM, C_DIM, summary);

        if (BolusFlow.message.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var fitted = Graphics.fitTextToArea(BolusFlow.message, Graphics.FONT_TINY, (w * 0.86).toNumber(), (h * 0.34).toNumber(), true);
            if (fitted != null) {
                dc.drawText(w / 2, (h * 0.68).toNumber(), Graphics.FONT_TINY, fitted,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }
}

class StatusDelegate extends IdleDelegate {
    function initialize() {
        IdleDelegate.initialize();
    }

    function onSelect() as Boolean {
        return close();
    }

    function onBack() as Boolean {
        return close();
    }

    private function close() as Boolean {
        BolusFlow.reset();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

// MARK: - PIN

const PIN_LENGTH = 4;

// Entered on the watch because sideloaded apps get no settings page in Garmin
// Connect. UP/DOWN picks each digit, START adds it; the 4th digit saves.
class PinView extends WatchUi.View {
    var digits as String = "";
    var choice as Number = 0;
    private var _required as Boolean;

    function initialize(required as Boolean) {
        View.initialize();
        _required = required;
    }

    function change(dir as Number) as Void {
        choice = (choice + dir + 10) % 10;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        clearScreen(dc);
        var h = dc.getHeight();
        centerText(dc, (h * 0.15).toNumber(), Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE, "Set PIN");
        if (_required) {
            centerText(dc, (h * 0.25).toNumber(), Graphics.FONT_TINY, C_WARN, "Needed before bolus");
        }
        var shown = "";
        for (var i = 0; i < PIN_LENGTH; i++) {
            shown += (i < digits.length() ? digits.substring(i, i + 1) : "_") + " ";
        }
        centerText(dc, (h * 0.37).toNumber(), Graphics.FONT_LARGE, C_DIM, shown);
        centerText(dc, (h * 0.55).toNumber(), Graphics.FONT_NUMBER_MEDIUM, C_SEL, choice.toString());
        centerText(dc, (h * 0.71).toNumber(), Graphics.FONT_XTINY, C_DIM, "Same 4 digits as in Trio");
        centerText(dc, (h * 0.81).toNumber(), Graphics.FONT_XTINY, C_DIM, "START add  BACK del");
    }
}

class PinDelegate extends IdleDelegate {
    private var _view as PinView;

    function initialize(view as PinView) {
        IdleDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() as Boolean {
        _view.change(1);
        return true;
    }

    function onNextPage() as Boolean {
        _view.change(-1);
        return true;
    }

    function onSelect() as Boolean {
        _view.digits += _view.choice.toString();
        if (_view.digits.length() >= PIN_LENGTH) {
            BolusFlow.savePin(_view.digits);
            BolusFlow.buzz(true);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() as Boolean {
        var len = _view.digits.length();
        if (len == 0) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            _view.digits = _view.digits.substring(0, len - 1);
            WatchUi.requestUpdate();
        }
        return true;
    }
}

// MARK: - Lock

const UNLOCK_TAPS = 3;
const UNLOCK_GAP_MS = 1000;

// First screen after launch. The face opens the app on a touch and hold, which
// something pressing on the watch can trigger; three quick taps (or START
// presses) are needed before the bolus screens appear.
class LockView extends WatchUi.View {
    var taps as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        clearScreen(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        centerText(dc, (h * 0.22).toNumber(), Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE, "Trio bolus");
        var r = 18;
        var gap = 70;
        for (var i = 0; i < UNLOCK_TAPS; i++) {
            var x = w / 2 + (i - 1) * gap;
            dc.setColor(i < taps ? C_SEL : 0x555555, Graphics.COLOR_TRANSPARENT);
            if (i < taps) {
                dc.fillCircle(x, h / 2 - 20, r);
            } else {
                dc.setPenWidth(3);
                dc.drawCircle(x, h / 2 - 20, r);
            }
        }
        centerText(dc, (h * 0.62).toNumber(), Graphics.FONT_SMALL, Graphics.COLOR_WHITE, "Tap 3 times quickly");
        centerText(dc, (h * 0.78).toNumber(), Graphics.FONT_XTINY, C_DIM, "BACK to close");
    }
}

class LockDelegate extends IdleDelegate {
    private var _view as LockView;
    private var _lastTap as Number = 0;

    function initialize(view as LockView) {
        IdleDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        var now = System.getTimer();
        if (now - _lastTap > UNLOCK_GAP_MS) {
            _view.taps = 0;
        }
        _lastTap = now;
        _view.taps += 1;
        if (_view.taps >= UNLOCK_TAPS) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            BolusFlow.begin(:bolus);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() as Boolean {
        System.exit();
    }
}

// MARK: - Menu

function openTrioMenu() as Void {
    Idle.touch();
    var menu = new WatchUi.Menu2({ :title => "Trio" });
    menu.addItem(new WatchUi.MenuItem("Bolus", null, :bolus, null));
    menu.addItem(new WatchUi.MenuItem("Carbs + Bolus", null, :carbs, null));
    menu.addItem(new WatchUi.MenuItem("Set PIN", BolusFlow.pin() == null ? "Not set" : "Set", :pin, null));
    WatchUi.pushView(menu, new TrioMenuDelegate(), WatchUi.SLIDE_UP);
}

class TrioDelegate extends IdleDelegate {
    function initialize() {
        IdleDelegate.initialize();
    }

    function onSelect() as Boolean {
        openTrioMenu();
        return true;
    }

    function onMenu() as Boolean {
        openTrioMenu();
        return true;
    }
}

class TrioMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Idle.touch();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        BolusFlow.begin(item.getId() as Symbol);
    }
}
