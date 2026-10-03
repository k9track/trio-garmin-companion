import Toybox.Cryptography;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Test;

// Request signing for PROTOCOL.md: lowercase hex HMAC-SHA256, keyed with the PIN.
module TrioSign {
    function hmacHex(key as String, msg as String) as String {
        var mac = new Cryptography.HashBasedMessageAuthenticationCode({
            :algorithm => Cryptography.HASH_SHA256,
            :key => toBytes(key)
        });
        mac.update(toBytes(msg));
        return toHex(mac.digest());
    }

    // Random hex request id, 16 chars.
    function newId() as String {
        return toHex(Cryptography.randomBytes(8));
    }

    function toBytes(s as String) as ByteArray {
        return StringUtil.convertEncodedString(s, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY
        }) as ByteArray;
    }

    function toHex(b as ByteArray) as String {
        var hex = StringUtil.convertEncodedString(b, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX
        }) as String;
        return hex.toLower();
    }
}

// Run with: ./build.sh test
(:test)
function signMatchesTrio(logger as Test.Logger) as Boolean {
    // Same vector as PROTOCOL.md, cross-checked with CryptoKit and openssl.
    var sig = TrioSign.hmacHex("1234", "bolus|a1b2c3d4|150|20|1760000000");
    logger.debug(sig);
    return sig.equals("d2f54163bba68e74965e5ec3dc4a3843323eda9e7391837e8a338af752beeaa3");
}

(:test)
function idIsHex16(logger as Test.Logger) as Boolean {
    var id = TrioSign.newId();
    logger.debug(id);
    return id.length() == 16;
}
