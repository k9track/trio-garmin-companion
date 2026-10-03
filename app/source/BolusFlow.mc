import Toybox.Application;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Watch side of PROTOCOL.md. One request at a time: pick amounts, confirm,
// send once, then show Trio's replies. Never resends on its own — a lost
// reply means "check Trio", not "try again".
module BolusFlow {
    const PIN_KEY = "pin";
    const REPLY_TIMEOUT_MS = 30000;

    enum Stage {
        IDLE,
        SENDING,
        DELIVERING,
        DONE,
        FAILED,
        NO_REPLY
    }

    var carbs as Number = 0;
    var centiUnits as Number = 0;
    var requestId as String? = null;
    var stage as Stage = IDLE;
    var message as String = "";
    var _timer as Timer.Timer? = null;

    // A PIN of any other length (from an older build) counts as unset.
    function pin() as String? {
        var p = Application.Storage.getValue(PIN_KEY);
        return p instanceof String && (p as String).length() == PIN_LENGTH ? p as String : null;
    }

    function savePin(p as String) as Void {
        Application.Storage.setValue(PIN_KEY, p);
    }

    // Entry from the menu: :bolus, :carbs or :pin. Called after the menu is popped.
    function begin(kind as Symbol) as Void {
        if (kind == :pin || pin() == null) {
            var pv = new PinView(kind != :pin);
            WatchUi.pushView(pv, new PinDelegate(pv), WatchUi.SLIDE_LEFT);
            return;
        }
        carbs = 0;
        centiUnits = 0;
        var av = new AmountView(kind == :carbs ? :carbs : :units);
        WatchUi.pushView(av, new AmountDelegate(av), WatchUi.SLIDE_LEFT);
    }

    function amountChosen(kind as Symbol, value as Number) as Void {
        if (kind == :carbs) {
            carbs = value;
            var av = new AmountView(:units);
            WatchUi.switchToView(av, new AmountDelegate(av), WatchUi.SLIDE_LEFT);
            return;
        }
        centiUnits = value;
        if (carbs + centiUnits == 0) {
            buzz(false);
            return;
        }
        var cv = new ConfirmView();
        WatchUi.switchToView(cv, new ConfirmDelegate(cv), WatchUi.SLIDE_LEFT);
    }

    function send() as Void {
        var p = pin();
        requestId = TrioSign.newId();
        message = "";
        WatchUi.switchToView(new StatusView(), new StatusDelegate(), WatchUi.SLIDE_LEFT);

        if (p == null) {
            finish(FAILED, "No PIN set");
            return;
        }
        if (BolusDemo.active()) {
            stage = SENDING;
            BolusDemo.respond(requestId as String, centiUnits);
            restartTimer();
            return;
        }
        if (!System.getDeviceSettings().phoneConnected) {
            finish(FAILED, "Phone not connected");
            return;
        }

        var ts = Time.now().value();
        var id = requestId as String;
        var sig = TrioSign.hmacHex(p, "bolus|" + id + "|" + centiUnits + "|" + carbs + "|" + ts);
        stage = SENDING;
        Communications.transmit(
            { "t" => "bolus", "id" => id, "u" => centiUnits, "c" => carbs, "ts" => ts, "sig" => sig },
            null,
            new BolusSendListener(id)
        );
        restartTimer();
    }

    // From TrioApp.onPhoneMessage. Ignores replies to anything but the current request.
    function onAck(ack as Dictionary) as Void {
        var id = ack["id"];
        if (requestId == null || !(id instanceof String) || !(requestId as String).equals(id)) {
            return;
        }
        var msg = ack["msg"] instanceof String ? ack["msg"] as String : "";
        var st = ack["stage"];
        if ("delivering".equals(st)) {
            stage = DELIVERING;
            message = msg;
            restartTimer();
            WatchUi.requestUpdate();
        } else if ("done".equals(st)) {
            finish(DONE, msg);
        } else {
            finish(FAILED, msg.length() > 0 ? msg : "Rejected");
        }
    }

    function sendFailed(id as String) as Void {
        if (requestId != null && (requestId as String).equals(id) && stage == SENDING) {
            // The request may still have reached Trio; only the delivery receipt is known lost.
            finish(NO_REPLY, "Couldn't confirm it reached the phone. Check Trio before trying again.");
        }
    }

    function onTimeout() as Void {
        if (stage == SENDING || stage == DELIVERING) {
            finish(NO_REPLY, "No reply. Check Trio before trying again.");
        }
    }

    function finish(s as Stage, msg as String) as Void {
        stopTimer();
        stage = s;
        message = msg;
        buzz(s == DONE);
        WatchUi.requestUpdate();
    }

    // Leaving the status screen: forget the request so late replies are ignored.
    function reset() as Void {
        stopTimer();
        requestId = null;
        stage = IDLE;
        message = "";
    }

    function restartTimer() as Void {
        stopTimer();
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(new Lang.Method(BolusFlow, :onTimeout), REPLY_TIMEOUT_MS, false);
    }

    function stopTimer() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function buzz(ok as Boolean) as Void {
        if (Attention has :vibrate) {
            var pattern = ok
                ? [new Attention.VibeProfile(60, 200)]
                : [new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 150), new Attention.VibeProfile(100, 300)];
            Attention.vibrate(pattern);
        }
    }

    function unitsText(centi as Number) as String {
        return (centi / 100.0).format("%.1f") + " U";
    }
}

class BolusSendListener extends Communications.ConnectionListener {
    private var _id as String;

    function initialize(id as String) {
        ConnectionListener.initialize();
        _id = id;
    }

    function onComplete() as Void {}

    function onError() as Void {
        BolusFlow.sendFailed(_id);
    }
}
