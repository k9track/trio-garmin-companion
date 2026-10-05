import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// One-time pairing (PROTOCOL.md): the watch proves it knows Trio's 4-digit PIN,
// and Trio answers with a random 256-bit key that signs every later request.
// The PIN itself is never stored on the watch.
module Pairing {
    const KEY_STORAGE = "key";
    const LEGACY_PIN_STORAGE = "pin";
    const TIMEOUT_MS = 30000;

    enum State {
        IDLE,
        SENDING,
        PAIRED,
        FAILED
    }

    var state as State = IDLE;
    var message as String = "";
    var _id as String? = null;
    var _timer as Timer.Timer? = null;

    // The paired key as 64 hex characters, or null.
    function key() as String? {
        var k = Application.Storage.getValue(KEY_STORAGE);
        return k instanceof String && (k as String).length() == 64 ? k as String : null;
    }

    function isPaired() as Boolean {
        return key() != null;
    }

    // Older builds stored the PIN and signed with it; that's no longer used.
    function forgetLegacyPin() as Void {
        Application.Storage.deleteValue(LEGACY_PIN_STORAGE);
    }

    function start(pin as String) as Void {
        _id = TrioSign.newId();
        message = "";
        state = SENDING;
        WatchUi.switchToView(new PairStatusView(), new PairStatusDelegate(), WatchUi.SLIDE_LEFT);
        var id = _id as String;
        var ts = Time.now().value();
        var sig = TrioSign.hmacHex(pin, "pair|" + id + "|" + ts);
        if (BolusDemo.active()) {
            BolusDemo.respondPair(id);
            return;
        }
        if (!System.getDeviceSettings().phoneConnected) {
            finish(FAILED, "Phone not connected");
            return;
        }
        Communications.transmit({ "t" => "pair", "id" => id, "ts" => ts, "sig" => sig }, null, new PairSendListener(id));
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(new Lang.Method(Pairing, :onTimeout), TIMEOUT_MS, false);
    }

    function onAck(ack as Dictionary) as Void {
        var id = ack["id"];
        if (state != SENDING || _id == null || !(id instanceof String) || !(_id as String).equals(id)) {
            return;
        }
        var key = ack["key"];
        if (ack["ok"] == true && key instanceof String && (key as String).length() == 64) {
            Application.Storage.setValue(KEY_STORAGE, key);
            finish(PAIRED, "Paired with Trio");
        } else {
            finish(FAILED, ack["msg"] instanceof String ? ack["msg"] as String : "Pairing failed");
        }
    }

    function sendFailed(id as String) as Void {
        if (state == SENDING && _id != null && (_id as String).equals(id)) {
            finish(FAILED, "Couldn't reach the phone");
        }
    }

    function onTimeout() as Void {
        if (state == SENDING) {
            finish(FAILED, "No reply from Trio");
        }
    }

    function finish(s as State, msg as String) as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
        state = s;
        message = msg;
        BolusFlow.buzz(s == PAIRED);
        WatchUi.requestUpdate();
    }

    function reset() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
        _id = null;
        state = IDLE;
        message = "";
    }
}

class PairSendListener extends Communications.ConnectionListener {
    private var _id as String;

    function initialize(id as String) {
        ConnectionListener.initialize();
        _id = id;
    }

    function onComplete() as Void {}

    function onError() as Void {
        Pairing.sendFailed(_id);
    }
}
