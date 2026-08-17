# Android — build setup and first run

Companion to [ANDROID.md](ANDROID.md), which says *why* and *when*. This one says *how*.

> **This code has never been compiled.** It was written on a Windows box with no Android
> SDK. Treat every version number as a starting guess and expect to fix imports on the
> first build. Everything that could not be verified is marked `⚠️ SIGNATURE NOTE` or
> `⚠️ UNVERIFIED` in the source — grep for those before you start.

---

## 1. What is here

```
android/
  settings.gradle.kts          repos + module list
  build.gradle.kts             plugin declarations
  gradle/libs.versions.toml    every dependency version, in one file
  app/
    build.gradle.kts
    proguard-rules.pro         kotlinx.serialization keep rules — do not delete
    src/main/AndroidManifest.xml
    src/main/java/app/lockin/
      LockinApplication.kt     channel creation + RevenueCat configure
      MainActivity.kt          screen routing, permission prompts, pending-proof pickup
      model/Commitment.kt      ← mirrors Commitment.swift
      data/
        CommitmentStore.kt     ← mirrors CommitmentStore.swift
        LockinPreferences.kt   ← mirrors UserDefaults / @AppStorage / PendingProof
      alarm/
        AlarmService.kt        ← mirrors AlarmService.swift (scheduling brain)
        AlarmReceiver.kt       fired alarm → hand off
        BootReceiver.kt        re-arm after reboot / app update
        AlarmRingService.kt    foreground service; makes the noise
        AlarmRingActivity.kt   the full-screen takeover
        AlarmNotifications.kt  channel + fullScreenIntent notification
      billing/
        SubscriptionService.kt ← mirrors SubscriptionService.swift
      proof/
        DeskPhotoValidator.kt  on-device photo check, no network
        QrScanner.kt           CameraX + ML Kit
        DeskCode.kt            printable sticker generator
      system/SystemPrompts.kt  battery / full-screen-intent / settings deep links
      ui/                      Compose screens + theme
    src/test/java/…/AlarmScheduleTest.kt   recurrence maths (JVM, no device)
```

Naming deliberately tracks the iOS tree so the two can be read side by side. The one
place the names had to diverge: `AlarmService` is the *scheduler* (as on iOS), while
`AlarmRingService` is the actual `android.app.Service`. Two different jobs.

---

## 2. Getting it to build

1. **Android Studio** — anything recent enough to ship AGP 8.11. Open `android/`, not the
   repo root.
2. **Gradle wrapper.** `gradle-wrapper.jar` is a binary and is not in the repo. Either let
   Android Studio generate it on first open, or from `android/`:
   ```
   gradle wrapper --gradle-version 8.13
   ```
3. **SDK.** Install the platform matching `compileSdk` in `app/build.gradle.kts` (36 as
   written) and set `sdk.dir` via `local.properties` — Studio writes it for you.
4. **JDK 17.** Set in `compileOptions` / `jvmTarget`. Studio's bundled JBR is fine.
5. **Resolve versions.** Run `./gradlew :app:dependencies` and fix whatever the catalog
   got wrong. The ones most likely to have moved:
   - `revenuecat` — the `await*` coroutine extensions.
   - `composeBom` — `LocalLifecycleOwner` moved packages; see the note in `QrScanner.kt`.
   - `camerax` / `mlkitBarcode`.
6. `./gradlew test` — the recurrence tests need no device and should pass before you ever
   plug a phone in.

### Dependencies, and why each one is there

| Dependency | Why |
|---|---|
| Compose BOM + material3 | UI |
| `material-icons-extended` | three icons; R8 strips the rest in release |
| `kotlinx-serialization-json` | `commitments.json` — same format as iOS |
| `kotlinx-coroutines-android` | receivers and the store |
| CameraX (`core`/`camera2`/`lifecycle`/`view`) | QR proof preview + frame analysis |
| `com.google.mlkit:barcode-scanning` | QR decode, **bundled** model = offline |
| `com.google.zxing:core` | QR *generation* only (the printable desk sticker) |
| `com.revenuecat.purchases:purchases` | subscriptions |

No Room, no Hilt, no Retrofit, no navigation library. There is no backend and no account
system, and the whole app is five screens.

---

## 3. Manifest entries that carry policy weight

Every one of these is deliberate. Read the comments in `AndroidManifest.xml` before you
change any of them.

### Exact alarms — the only real blocker

```xml
<uses-permission android:name="android.permission.USE_EXACT_ALARM"
                 android:minSdkVersion="33" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"
                 android:maxSdkVersion="32" />
```

| API level | Permission in effect | Granted how |
|---|---|---|
| 26–30 | none needed | n/a |
| 31–32 | `SCHEDULE_EXACT_ALARM` | auto-granted, user-revocable |
| 33+ | `USE_EXACT_ALARM` | always granted, gated by Play review |

Exactly one permission per device, which is what ANDROID.md requires. `AlarmService`
still calls `canScheduleExactAlarms()` because a 31/32 user can revoke, and
`requestExactAlarmPermission()` is a no-op on 33+ by design — there is nothing to ask for.

### Other restricted permissions

- `USE_FULL_SCREEN_INTENT` — Android 14+ gates this; alarm apps keep it by default but
  the app checks `canUseFullScreenIntent()` and shows a banner if not.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — Play-restricted, allowed for alarm clocks. If
  you would rather not declare it, delete the line; `SystemPrompts.requestBatteryExemption`
  falls through to the generic settings screen on its own.
- `FOREGROUND_SERVICE_SPECIAL_USE` — see below.

### Foreground service type

`AlarmRingService` runs as `specialUse` with
`PROPERTY_SPECIAL_USE_FGS_SUBTYPE = "alarm_clock_ringing"`. There is no `alarm` FGS type,
and `mediaPlayback` invites a policy argument about media-player UX that this app would
lose. `specialUse` needs a written justification in Play Console — something like:

> Lockin is an alarm clock. When a user-scheduled alarm fires, this service plays the
> alarm tone and holds the alarm active until the user either dismisses it or completes
> the task-start confirmation. It runs only while an alarm is actively ringing, never in
> the background otherwise, and stops automatically after two minutes.

---

## 4. Play Console declarations

Do these before the first upload; getting them wrong risks removal, and this app genuinely
qualifies for all of them.

1. **Exact alarm permission declaration.** Core function is an alarm clock. Say exactly
   that. Have a screen recording of the full-screen alarm ready.
2. **Foreground service (special use).** Wording above.
3. **Data safety form.** The honest answer for v1 is *no data collected, no data shared*.
   Commitments, streaks and the proof photo never leave the device; the photo is written
   to the cache directory, validated on-device, and deleted in the same coroutine. Do not
   let this become untrue without updating the form.
4. **Health claims — don't.** PRODUCT.md's red line applies to the Play listing too. No
   ADHD, no treatment, no therapy. It is a focus tool.

> ⚠️ Play's exact-alarm policy text changes on **28 October 2026**. If you submit after
> that date, re-read the current policy before filling any of this in.

---

## 5. RevenueCat

1. Add an **Android app** to the existing RevenueCat project — the same project as iOS, or
   subscribers lose Pro when they switch platforms.
2. Entitlement id must be exactly **`pro`** (`SubscriptionService.ENTITLEMENT_ID`), same as
   iOS.
3. Create the Play subscription products and attach them to the same offering.
4. Paste the **public** Android SDK key into `LockinApplication.REVENUECAT_API_KEY`. It
   starts with `goog_`, not `appl_` — the iOS key will not work.
5. Upload a signed build to a Play testing track first. Play Billing returns nothing
   useful for an app that has never been uploaded, so the paywall will look empty on a
   pure debug build. That is expected, not a bug.

Free tier is 2 active commitments (`CommitmentStore.FREE_COMMITMENT_LIMIT`).

---

## 6. First-run checklist on a real device

Emulators cannot honestly test this app: Doze, OEM battery managers and lock-screen
behaviour are the whole risk surface. Use a physical phone, and ideally one Samsung or
Xiaomi in addition to a Pixel.

**Setup**
- [ ] `./gradlew installDebug`, complete onboarding, create one commitment 2 minutes out.
- [ ] Grant notifications when asked; accept the battery-optimisation exemption.
- [ ] Confirm no warning banners remain on the list screen.

**The core mechanic**
- [ ] Lock the phone. Alarm fires → screen turns on → full-screen red takeover, not a
      banner.
- [ ] Phone on silent → still audible. Do Not Disturb on → still audible.
- [ ] Tap **Dismiss**. Confirm it returns in ~2 minutes with "STILL HAVEN'T STARTED".
- [ ] Let it repeat to nag 5, confirm it stops. It must stop.
- [ ] Tap **I'm starting**, then background the app without proving. It should still come
      back — "I'm starting" is not a free silence.
- [ ] Complete a proof. Confirm the chain is gone and the streak incremented.
- [ ] Let one ring go completely untouched for 2 minutes. Confirm it silences itself, the
      miss counter increments, and a nag is queued.

**Proof types**
- [ ] Photo: real desk accepted. Ceiling and covered-lens rejected. **Then shoot ~20 real
      photos and log `DeskPhotoValidator.analyse()` before trusting the thresholds** —
      they are calibrated on paper, not on data. Tune *looser*, never tighter: PRODUCT.md
      is explicit that a false rejection is far worse than an accepted fake.
- [ ] Focus timer: countdown starts, proof records immediately on start.
- [ ] Desk code: generate the sticker via `DeskCode.bitmap(commitment.id)`, print or
      display it, scan it. Then scan a *different* commitment's code and confirm it is
      rejected.

**Survival**
- [ ] Reboot the phone. Confirm alarms still fire (`BootReceiver`).
- [ ] Reinstall over the top. Confirm alarms still fire (`MY_PACKAGE_REPLACED`).
- [ ] Force-stop the app, then wait for an alarm. It should still ring.
- [ ] Leave a commitment set for 48h on an untouched phone — this is the test that catches
      OEM battery managers, and nothing else will.
- [ ] Build **release** (`./gradlew assembleRelease`) and verify commitments still load.
      R8 plus kotlinx.serialization is the classic silent data-loss combination; the keep
      rules are in `proguard-rules.pro` for exactly this reason.

---

## 7. Known gaps

Things that are deliberately unfinished, so you find them here rather than in a review.

- **Restore onto a new device does not re-arm alarms.** Backup restores
  `commitments.json`, but `AlarmManager` registrations are per-install. `BootReceiver`
  covers reboot and update; a cloud restore lands with commitments present and nothing
  scheduled. Cheapest fix: call `CommitmentStore.rescheduleAll()` once on first launch
  after a restore.
- **No desk-code UI.** `DeskCode.bitmap()` generates the sticker but nothing in the UI
  displays or shares it yet. The desk-code proof is unusable until a settings screen
  exists to show the QR. iOS has the same gap.
- **No weekly excuse report.** The counters that feed it (`missCount`, `bestStreak`) are
  recorded and persisted; the Sunday report itself is not built on either platform.
- **No editing.** Commitments can be created and deleted, not edited —
  `CommitmentStore.update()` exists and works, there is just no screen calling it.
- **Timer proof does not survive backgrounding.** The 25-minute countdown is UI-only state.
  Since *starting* is the proof, this costs nothing today, but any future "you must finish"
  variant needs it moved into a service.
- **`DeskPhotoValidator` thresholds are uncalibrated.** See the checklist above.
