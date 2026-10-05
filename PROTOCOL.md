# Watch → Trio protocol

Trio side: `Trio/Sources/Views/GarminCompanion/GarminCompanionBolus.swift` on the
[`garmin-companion` branch of k9track/Trio-1](https://github.com/k9track/Trio-1/tree/garmin-companion).
Only the watch **app** (`47446545-…`) may send these; Trio ignores bolus and pairing messages from any
other app ID, and the face can't transmit.

All signatures are lowercase hex HMAC-SHA256. Trio logs only the message type, never the contents.

## 1. Pairing (once)

The user saves a 4-digit PIN in Trio and taps **Pair Watch**, which opens a 2-minute window. On the
watch they choose **Pair with Trio** and enter the PIN. The watch sends:

| key   | type   | meaning |
|-------|--------|---------|
| `t`   | String | `"pair"` |
| `id`  | String | random hex, 8–32 chars |
| `ts`  | Number | unix seconds |
| `sig` | String | HMAC of `"pair|<id>|<ts>"`, key = PIN as UTF-8 |

Trio checks the window is open, the signature and the time (±60 s), then makes a random 256-bit key,
keeps it in the iPhone keychain (this device only, not synced) and replies:

`{"t": "pairAck", "id": <id>, "ok": true, "key": <64 hex chars>, "msg": "Paired"}`

or `"ok": false` with a `msg`. The watch stores the key; the PIN is not stored or used again. Pairing
again replaces the key, and **Unpair** in Trio deletes it.

Why: a 4-digit PIN has only 10,000 values, so anything signed with it can be brute-forced from one
captured message. A random 256-bit key can't, and it never appears in requests.

## 2. Requests (watch → phone)

| key   | type   | meaning |
|-------|--------|---------|
| `t`   | String | `"bolus"` |
| `id`  | String | random hex, 8–32 chars, new for every request |
| `u`   | Number | insulin in **hundredths** of a unit (1.5 U → `150`), 0–10000; `0` = carbs only |
| `c`   | Number | carbs in grams, 0–1000; `0` = insulin only |
| `ts`  | Number | `Time.now().value()` (unix seconds) |
| `sig` | String | HMAC of `"bolus|<id>|<u>|<c>|<ts>"`, key = the paired key's 32 bytes |

Test vectors (CryptoKit and openssl agree):
- Key bytes `00 01 02 … 1f`, string `bolus|a1b2c3d4|150|20|1760000000` →
  `e3c8a5b8fd5ad73f8731a64e670c7e75c449225185572dcab3bd6db695836d3a`
- PIN-keyed HMAC as used for pairing: key = PIN `1234` as UTF-8, string `bolus|a1b2c3d4|150|20|1760000000` →
  `d2f54163bba68e74965e5ec3dc4a3843323eda9e7391837e8a338af752beeaa3`

## 3. Replies (phone → watch)

`{"t": "bolusAck", "id": <id>, "ok": Bool, "stage": String, "msg": String}`

| stage        | ok    | meaning | watch shows |
|--------------|-------|---------|-------------|
| `rejected`   | false | nothing was saved or delivered | **Not delivered** + `msg` |
| `delivering` | true  | checks passed, carbs (if any) saved, bolus sent to the pump | Delivering |
| `done`       | true  | bolus started on the pump, or carbs-only entry saved | **Done** |
| `failed`     | false | accepted, but the pump failed; some insulin may have gone in, and carbs may be logged | **Check Trio** + `msg` |

Anything else, no reply within 30 s, or a transmit error (the request may still have arrived) also shows
**Check Trio**. The watch **never** resends automatically and ignores replies after Done / Not delivered.

## 4. Checks Trio runs, in order

1. **Allow Bolus from Garmin** is on and a watch is paired.
2. Fields parse and are in range; the signature matches the paired key.
   A wrong signature (or a wrong PIN while pairing) counts as a failure; after **5 in a row** Trio turns
   watch bolus off, closes pairing and posts a notification. Turning it back on resets the count.
3. `ts` within ±60 s of the phone clock, `id` not seen before, and `ts` **newer** than the last accepted
   request (stored as no later than the phone's clock, so a fast watch clock can't lock you out).
4. No other watch request in progress.
5. Carbs ≤ the smaller of Trio **Max Carbs** and the **watch carb max** (default 60 g).
   Units ≤ the **watch max** (default 3 U).
6. The dose is rounded down to the pump's step (reported to the watch as rounded; 0 is rejected).
7. No watch bolus ≥ 20 % of this one in the last 6 min (kept in memory in case the pump record is late),
   then `BolusSafetyValidator`: pump Max Bolus, Max IOB, and no bolus ≥ 20 % of this one since
   `min(ts, now − 6 min)`.

Then carbs are saved (note "Via Garmin") and the bolus goes to `APSManager.enactBolus`. If carbs fail
to save, no insulin is given. If the bolus then fails, the watch is told the carbs are logged so they
aren't resent. Trio posts a notification for every watch bolus, carb entry and pairing.

## 5. Known limits

- Anyone wearing an unlocked, paired watch can bolus up to the watch max. The key identifies the watch,
  not the person; keep the watch max low.
- The key travels once, during the 2-minute pairing window, over Garmin's Bluetooth link.
- The face opens the app through a public complication found by its label ("Trio Companion"). Another
  installed app publishing a complication with the same label would be opened instead; it would still
  need the paired key to send anything to Trio.
- `./build.sh screenshots` makes a simulator-only build with fake replies, its own app ID, a
  "SIMULATED" banner, and output in `bin/simulator-only/`. Never install it.
