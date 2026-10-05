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

    // Request signature with the paired key (64 hex characters = 32 bytes).
    function hmacHexWithKey(keyHex as String, msg as String) as String {
        var mac = new Cryptography.HashBasedMessageAuthenticationCode({
            :algorithm => Cryptography.HASH_SHA256,
            :key => StringUtil.convertEncodedString(keyHex, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY
            }) as ByteArray
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
function keySignMatchesTrio(logger as Test.Logger) as Boolean {
    // Key of bytes 0x00..0x1f; same vector as PROTOCOL.md (CryptoKit and openssl agree).
    var key = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
    var sig = TrioSign.hmacHexWithKey(key, "bolus|a1b2c3d4|150|20|1760000000");
    logger.debug(sig);
    return sig.equals("e3c8a5b8fd5ad73f8731a64e670c7e75c449225185572dcab3bd6db695836d3a");
}

(:test)
function idIsHex16(logger as Test.Logger) as Boolean {
    var id = TrioSign.newId();
    logger.debug(id);
    return id.length() == 16;
}
