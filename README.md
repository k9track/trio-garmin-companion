# Trio Companion for Garmin

A Connect IQ **watch face** and **watch app** for the Garmin fēnix 8 that show live
[Trio](https://github.com/nightscout/Trio) data and let you **bolus and log carbs from the watch**,
the way Trio's Apple Watch app can.

<p>
<img src="docs/screenshots/01-watch-face.png" width="200">
<img src="docs/screenshots/02-amount.png" width="200">
<img src="docs/screenshots/04-holding.png" width="200">
<img src="docs/screenshots/06-done.png" width="200">
</p>

- **Watch face:** time; IOB / COB / temp basal; delta, glucose, trend arrow, loop age and loop ring;
  2-hour graph; heart rate and battery. Dims to time / glucose / arrow in always-on mode, shifting each
  minute to avoid AMOLED burn-in.
- **Watch app:** touch and hold the face → set the amount → START → **hold START** to deliver.
  Carbs + Bolus and a carbs-only entry are in its menu.
- Data comes straight from the Trio iPhone app over Bluetooth through Garmin Connect. No servers.

**How to use it, step by step: [docs/WATCH_BOLUS.md](docs/WATCH_BOLUS.md).**

> ⚠️ **Use at your own risk.** This is a do-it-yourself add-on, not part of official Trio and not reviewed
> by the Trio developers. It can deliver insulin. Try it against Trio's simulated pump first, and keep the
> watch maximum low.

## Safety

Trio does all the checking; the watch only asks. A request is refused, with nothing saved or delivered, unless:

- **Watch Bolus** is switched on in Trio (it's off by default) and a 4-digit PIN is set there;
- it is signed with that PIN (HMAC-SHA256), is under 60 seconds old and has never been used before;
- insulin is within the **watch maximum** (default 3 U) and the pump's **Max Bolus**, and won't exceed **Max IOB**;
- no bolus of 20 % or more of this one was given in the last few minutes (Trio's standard remote-bolus check);
- carbs are within Trio's **Max Carbs**.

On the watch, a dose is only sent after START is held for about a second, it is sent once, and if the
result is unknown the watch says **Check Trio** instead of retrying. Details: [PROTOCOL.md](PROTOCOL.md).

## What you need

1. **A fēnix 8:** 43 mm, 47 mm or Pro 47 mm. Other watches aren't built or tested.
2. **Trio with the receiver.** Stock Trio doesn't talk to these apps. Build Trio from the
   [`garmin-companion` branch of k9track/Trio-1](https://github.com/k9track/Trio-1/tree/garmin-companion),
   which is Trio `main` plus only the Garmin changes:
   - `Trio/Sources/Services/WatchManager/GarminManager.swift`: sends data to these apps and routes bolus requests;
   - `Trio/Sources/Views/GarminCompanion/`: the bolus receiver and the **Watch Bolus** settings screen.

   Build it the way you normally build Trio (Xcode or Browser Build), just from that branch.
3. **Garmin Connect** on the iPhone, with the watch paired, and the watch added in Trio under
   Settings → Watch → Garmin.

## Install on the watch

Prebuilt files are on the [Releases](../../releases) page, or build them yourself (below). Pick the file for your watch size.

1. On the watch: **Settings → System → USB Mode → MTP**, then plug it into a Mac and wake it.
2. Open [OpenMTP](https://openmtp.ganeshrvel.com) (`brew install --cask openmtp`), go to **GARMIN → Apps**,
   drag in the `.prg` files, and refresh to confirm they're listed.
3. **Unplug.** The watch installs them when it disconnects.
4. Choose **Trio Companion Face** from the watch face list (sideloaded faces are in the list itself,
   not under "Add New").
5. Open the **Trio Companion** app once from the apps list. Until it has run, touch-and-hold on the face
   can't find it. Do this again after every update.

Then set up the PIN and turn Watch Bolus on, as described in [docs/WATCH_BOLUS.md](docs/WATCH_BOLUS.md).

## Build it yourself

Needs the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) **9.2 or newer** (fēnix 8 firmware
requires API 6.0) and a developer key:

    mkdir -p ~/.garmin
    openssl genrsa -out /tmp/key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/key.pem -out ~/.garmin/developer_key -nocrypt

Then:

    ./build.sh face fenix847mm release    # watch face → bin/TrioCompanionFace-fenix847mm.prg
    ./build.sh app  fenix847mm release    # watch app  → bin/TrioCompanion-fenix847mm.prg
    ./build.sh test                        # request-signing tests, in the simulator

Use `fenix843mm` or `fenix8pro47mm` for other sizes. Debug builds (without `release`) show labeled
DEMO data in the simulator: `open "$SDK/bin/ConnectIQ.app"`, then `"$SDK/bin/monkeydo" bin/<file>.prg fenix847mm`.
`./build.sh screenshots` makes a simulator-only build with a stand-in for Trio's replies; never install it.

    shared/   drawing, data handling, background service, icon
    face/     Trio Companion Face (watch face)
    app/      Trio Companion (watch app, bolus screens)

## App IDs

Trio recognises the apps by these IDs (`companionApps` in `GarminManager.swift`). If you change one, change both sides.

- Watch app: `47446545-d711-4b95-8267-9eda745199cc`
- Watch face: `d0679157-1ca2-481a-9511-12d0ffac3c6a`

## License

MIT, see [LICENSE](LICENSE). No warranty: you are responsible for any insulin this delivers.
