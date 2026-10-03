# Watch → Trio bolus protocol

Trio side: `Trio/Sources/Views/GarminCompanion/GarminCompanionBolus.swift` on the
[`garmin-companion` branch of k9track/Trio-1](https://github.com/k9track/Trio-1/tree/garmin-companion).
Only the watch **app** (`47446545-…`) may send these; the face can't transmit.

## Request (watch → phone)

`Communications.transmit` a Dictionary:

| key   | type   | meaning |
|-------|--------|---------|
| `t`   | String | `"bolus"` |
| `id`  | String | random hex, 8–32 chars, new for every request |
| `u`   | Number | insulin in **hundredths** of a unit (1.5 U → `150`); `0` = carbs only |
| `c`   | Number | carbs in grams; `0` = insulin only |
| `ts`  | Number | `Time.now().value()` (unix seconds) |
| `sig` | String | lowercase hex HMAC-SHA256 of `"bolus|<id>|<u>|<c>|<ts>"`, key = PIN as UTF-8 |

Test vector: PIN `1234`, string `bolus|a1b2c3d4|150|20|1760000000` →
`d2f54163bba68e74965e5ec3dc4a3843323eda9e7391837e8a338af752beeaa3`

## Replies (phone → watch)

`{"t": "bolusAck", "id": <id>, "ok": Bool, "stage": String, "msg": String}`

| stage        | ok    | meaning |
|--------------|-------|---------|
| `rejected`   | false | nothing was saved or delivered; show `msg` |
| `delivering` | true  | checks passed, carbs (if any) saved, bolus sent to pump |
| `done`       | true  | bolus started on the pump, or carbs-only entry saved |
| `failed`     | false | accepted but the pump or carb save failed; show `msg` |

A request can get `delivering` then `done`/`failed`. No reply within 30 s, or a transmit
error (the request may still have arrived), = unknown: the watch shows **Check Trio** and
**never** resends automatically.

The PIN is entered on the watch (START → Set PIN) and kept in `Application.Storage`;
sideloaded apps have no Garmin Connect settings page.

## Checks Trio runs, in order

1. "Allow Bolus from Garmin" is on and a 4-digit PIN is saved (Trio → Watch → Garmin → Watch Bolus).
2. Fields parse; signature matches.
3. `ts` within ±60 s of the phone clock, `id` not seen before, `ts` not older than the last accepted request.
4. No other watch request in progress.
5. Carbs ≤ Trio Max Carbs. Units ≤ watch max (default 3 U).
6. `BolusSafetyValidator`: pump Max Bolus, Max IOB, and no bolus ≥ 20 % of this one since
   `min(ts, now − 6 min)`.

Then carbs are saved (note "Via Garmin") and the bolus goes to `APSManager.enactBolus`.
If carbs fail to save, no insulin is given.
