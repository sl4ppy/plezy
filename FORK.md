# Plezy Pre-roll — fork notes

This is a personal fork of [edde746/plezy](https://github.com/edde746/plezy) that adds **Plex server pre-rolls**
(the short clips Plex plays before a movie, set under *Settings → Extras → Cinema Trailers pre-roll video* on the
server). Upstream Plezy 2.24.0 does not play them ([edde746/plezy#970](https://github.com/edde746/plezy/issues/970)).

It is upstream **2.24.0** plus the still-open upstream pull request
[edde746/plezy#2483](https://github.com/edde746/plezy/pull/2483) by @torp93, plus a few fork fixes found while
testing. Everything is on the **`preroll`** branch; `main` tracks upstream unchanged.

> Not affiliated with or endorsed by the Plezy project. If #2483 (or another pre-roll feature) lands upstream, use
> the official app again — this fork exists only to bridge that gap.

- App name on the device: **Plezy Pre-roll** (`com.edde746.plezy.preroll`), installs **next to** official Plezy.
- Android only (arm64-v8a). Built and tested on a Pixel 9 Pro XL (Android 17). Android TV (NVIDIA SHIELD) not
  tested yet — see [Status](#status).
- Turn it on in the app: **Settings → Video Playback → Play Pre-Roll Before Movies** (off by default).

---

## How it works

Plex servers already know how to attach the configured pre-roll: when a client creates a play queue with the
`extrasPrefixCount` parameter, the server puts the pre-roll in front of the movie as an ordinary `clip` item. The
client never reads `CinemaTrailersPrerollID` itself. Checked against this server (PMS on MS-01) on 2026-10-22:

| `POST /playQueues?type=video&uri=<movie>` | Queue returned |
|---|---|
| no `extrasPrefixCount` | movie only (what upstream Plezy does) |
| `extrasPrefixCount=0` | **pre-roll → movie** — a different random clip each call when the server pref is a `;` list |
| `extrasPrefixCount=1` | trailer(s) + pre-roll → movie (no trailers here: the server's trailer options are off) |

So when the setting is on and a movie is played directly, the app builds that queue with `extrasPrefixCount=0`
and plays it. If the server prefixes nothing (no pre-roll configured, or an error), it falls back to ordinary
direct playback.

The pre-roll is **skipped** when:
- the movie is being **resumed** (it has a saved position or an explicit start position) — like Plex's own apps.
  *Play from beginning* clears the position, so it does get a pre-roll;
- the item is not a movie (episodes, clips, music);
- playing offline / a download;
- you are in a **Watch Together** session (a host's pre-roll would desync guests);
- the movie is started from a queue that already exists (collection, playlist, shuffle) — no double pre-roll.

When the pre-roll ends the player goes straight into the movie (no "next in queue" countdown). A pre-roll is not
reported to the server as a watch (checked in the server's play history after testing).

## What changed (on top of upstream 2.24.0)

```
d50e4a5  fork: pre-roll goes straight into the movie; none on resume
7968dd6  fork: own application id and label so it installs beside upstream
829fe06  fork: adapt #2483 to 2.24.0 Watch Together API
d000c30  torp93: feat(plex): play the server-configured pre-roll before movies      (#2483)
fe71c8f  torp93: feat(plex): allow prefixing play queues with cinema extras         (#2483)
         + test stub fix, build script, this file
```

| File | Change |
|---|---|
| `lib/services/plex_client/parts/play_queues.dart` | `createPlayQueue()` takes optional `extrasPrefixCount` (#2483) |
| `lib/services/play_queue_launcher.dart` | `launchMovieWithCinemaExtras()` builds the queue, returns null if nothing was prefixed (#2483) |
| `lib/utils/video_player_navigation.dart` | calls it for movies when the setting is on (#2483); fork: Watch Together check adapted to 2.24.0, skip on resume |
| `lib/screens/video_player/parts/playback_prompts.dart` | fork: a finished `clip` advances straight to the movie |
| `lib/services/settings_service.dart`, `lib/screens/settings/playback_settings_screen.dart`, `lib/i18n/*` | the setting and its strings (#2483; generated files rebuilt with slang) |
| `android/app/build.gradle.kts`, `AndroidManifest.xml`, two Kotlin files | fork: application id `com.edde746.plezy.preroll`, label *Plezy Pre-roll*, matching content-provider authorities |
| `pubspec.yaml` | version `2.24.0-preroll.N` |
| `test/…` | #2483's tests; fork: `playlist_detail_screen_test.dart` stub takes the new parameter |
| `scripts/fork-build-android.sh` | fork: one-command signed build |

## Status

| Check | Result |
|---|---|
| #2483 unit tests (`test/services/play_queue_launcher_test.dart`) | ✅ 12/12 |
| Full upstream test suite (preroll.2) | ✅ 8151 passed, 7 skipped; 1 failure = `memory_pressure_breadcrumbs_test.dart`, flaky (process-RSS timing) and failing on plain 2.24.0 too |
| `dart analyze` | ✅ no new issues vs. upstream 2.24.0 (the 49 pre-existing ones are in vendored packages) |
| Server queue behaviour (`extrasPrefixCount`) | ✅ verified with curl against PMS |
| Pixel 9 Pro XL: pre-roll before a fresh movie | ✅ |
| Pixel: pre-roll → movie without a prompt | ✅ (fixed in preroll.2; preroll.1 showed "next in queue" + countdown) |
| Pixel: resume a started movie → no pre-roll | ✅ (fixed in preroll.2; preroll.1 replayed the pre-roll) |
| Pre-roll not recorded as watched | ✅ (server history after the tests) |
| NVIDIA SHIELD (Android TV, D-pad, DV/Atmos passthrough) | ⏳ not tested yet |
| Collections / playlists / shuffle, Back or seek during pre-roll, other accounts | ⏳ not tested yet |

Known limitations:
- **No in-app updates.** The build has `ENABLE_UPDATE_CHECK` off, so it never offers upstream releases (they are
  signed with a different key and could not install over it anyway). Update by installing a newer fork release.
- **Different signing key** from upstream, and a different app id: settings and sign-in are separate from the
  official app.
- Dolby Vision **profile 7** (UHD-disc remuxes) may show as HDR10 on Android TV players; that is player behaviour,
  not this fork. Use a profile 8 file as the reference when testing.
- `extrasPrefixCount=1` would add trailers — the setting only ever asks for the pre-roll (`0`).

## Installing

Download `plezy-preroll-<version>-arm64-v8a.apk` from the [releases](../../releases) and check its SHA-256
against the release notes. Then either open it on the device, or with `adb`:

```bash
adb connect <device-ip>:<port>          # SHIELD: Settings → Device Preferences → Developer options → Network debugging (port 5555)
                                        # Phone (Android 11+): Developer options → Wireless debugging; `adb pair` first
adb install -r plezy-preroll-<version>-arm64-v8a.apk
```

`-r` updates an existing install and keeps its data. The signing certificate (SHA-256
`f5be0096728ba5bc16e7d17a275035a035a467654d261ae6df7f76615d22bed8`, `CN=sl4ppy plezy fork`) is the same for every
fork release, so updates install over each other.

Then: sign in, **Settings → Video Playback → Play Pre-Roll Before Movies** on.

## Building it yourself

Versions match upstream CI (`.github/workflows/build.yml`) for 2.24.0.

| Tool | Version | Where (on the build machine) |
|---|---|---|
| Flutter | 3.47.1 stable (Dart 3.13.1) | `~/sdk/flutter` (tarball from `storage.googleapis.com/flutter_infra_release`) |
| JDK | Temurin 21 — a **full JDK** | `~/sdk/jdk-21.*` (Adoptium API) |
| Android SDK | platform 36, build-tools 36.x, platform-tools | `~/Android/Sdk` (cmdline-tools + `sdkmanager`) |
| NDK | 29.0.14206865 | `~/Android/Sdk/ndk/` |
| CMake | 4.1.2 (+ 3.22.1, which a plugin installs itself) | `~/Android/Sdk/cmake/` |

```bash
sdkmanager --sdk_root=$HOME/Android/Sdk "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
  "ndk;29.0.14206865" "cmake;4.1.2"
flutter config --android-sdk ~/Android/Sdk --jdk-dir ~/sdk/jdk-21.0.13+9
```

### Signing

`android/app/build.gradle.kts` signs release builds with `android/key.properties` when it exists (it is
git-ignored). On the build machine it is a symlink to `~/.config/plezy-fork/key.properties`, next to the
keystore `~/.config/plezy-fork/plezy-fork.jks` (both mode 600, never committed):

```properties
storePassword=…
keyPassword=…
keyAlias=plezy-fork
storeFile=/home/<user>/.config/plezy-fork/plezy-fork.jks
```

**Back up the keystore and its password.** Without them a new build cannot update an installed one — you would
have to uninstall (losing settings and sign-in) and install a build signed with a new key.

### Build

```bash
ln -s ~/.config/plezy-fork/key.properties android/key.properties   # once
./scripts/fork-build-android.sh
```

The script runs `pub get`, regenerates the translations (`dart run slang`), builds a release arm64 APK with
`GIT_COMMIT` set, copies it to `build/fork/plezy-preroll-<version>-arm64-v8a.apk`, and prints its SHA-256 and the
signer certificate. First build ~10 min (Gradle and native deps download), later ones ~7 min.

Tests: `flutter test` (all) or `flutter test test/services/play_queue_launcher_test.dart` (pre-roll).

## Moving to a new upstream release

1. `git fetch upstream --tags`
2. If #2483 (or an equivalent) has been merged upstream: stop — use the official app.
3. `git checkout -b preroll-<new> <new-tag>` and `git cherry-pick 2.24.0..preroll` (the five commits above,
   plus the later fork commits).
4. Expect conflicts in `lib/i18n/strings*.g.dart` (generated): take the new tag's version, then
   `dart run slang`. Re-check anything the player code renamed (2.24.0 already renamed one parameter #2483
   relied on).
5. Bump `version:` in `pubspec.yaml` to `<new>-preroll.1+<build>`, run the tests, build, test on a device, release.

## Build log — what went wrong along the way

Recorded so the next update is quicker.

| Problem | Cause | Fix |
|---|---|---|
| #2483 did not apply cleanly to 2.24.0 | it was written against an older `main`; GitHub showed it as conflicting | cherry-picked its two commits; conflicts only in generated i18n files (regenerated) and one test file (kept both test groups) |
| would not compile on 2.24.0 | the PR uses `watchTogetherLease`, which 2.24.0 replaced with `watchTogetherCopy` | `829fe06`: use `watchTogetherCopy`, and also skip while in any Watch Together session |
| install would clash with upstream Plezy | same application id, and two hard-coded provider authorities | `7968dd6`: own id/label/authorities |
| `Toolchain installation '/usr/lib/jvm/java-21-openjdk-amd64' does not provide the required capabilities: [JAVA_COMPILER]` | the distro Java was a JRE (no `javac`) | Temurin JDK 21 in `~/sdk`; the script sets `JAVA_HOME` |
| build killed (exit 144) | `pkill -f GradleDaemon` matched the shell running the build | don't do that — use `./gradlew --stop` |
| `[CXX1300] CMake '4.1.2' was not found in SDK` | native (mpv/Dolby Vision) build needs that exact CMake | `sdkmanager "cmake;4.1.2"` |
| script's last step failed: `Unsupported command: …/36.1.0/apksigner` | the build installed a second build-tools version, so the glob matched two `apksigner`s | the script picks the newest |
| preroll.1: "next in queue" countdown after the pre-roll | the clip went through the episode Play Next prompt | `d50e4a5`: a finished `clip` goes straight to the next item |
| preroll.1: resuming a started movie replayed the pre-roll | no resume check | `d50e4a5`: skip when there is a saved/explicit start position |
| `playlist_detail_screen_test.dart` did not compile | its `createPlayQueue` stub lacked the new parameter (the test is newer than the PR's base) | added `extrasPrefixCount` to the stub |

Not done / ruled out:
- Using another fork: none ships server pre-rolls. Bergasha/plezy (#2271) plays a random clip from a chosen
  library instead; TeeJS/plezy has signed builds but no pre-roll; derFrisson/plezy-apks only repackages upstream.
- Reading `CinemaTrailersPrerollID` and playing the file client-side (the approach of closed #1695): unnecessary —
  the server does it — and it was the source of that PR's watch-reporting problems.
