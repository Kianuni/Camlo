<div align="center">
  <br>
  <img src="./PreviewIcon.png" alt="Camlo App Icon" width="150">
  <br>
  <h1>Camlo · 开幕</h1>
  <p><strong>Wake to unveil. Swipe to transform.</strong> — Zero-threshold Slide-to-Unlock Morph &amp; Dynamic Lock Screen (<code>.tendies</code> / CAML) Studio for iOS &amp; iPadOS</p>
  <p>Craft native Core Animation wallpapers on-device and apply directly to <code>PosterBoard</code> in 1 tap on iOS 26.x &amp; iOS 27.0 – 27.3 beta 1 — zero PC required.</p>
  <p><a href="./README.md">简体中文文档</a> · <strong>English</strong> · <a href="https://github.com/Kianuni/Erosion-CN">Erosion-CN Companion Toolkit</a></p>
  <img alt="Version" src="https://img.shields.io/badge/Version-v1.2.4-6A4DF5?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/iOS%20%2F%20iPadOS-26.0%20%E2%80%93%2027.3b1-FF6B7A?style=flat-square">
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json"><img alt="Official AltSource" src="https://img.shields.io/badge/Official%20Source-SideStore%20%2F%20AltStore-0EA5E9?style=flat-square"></a>
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/License-GPLv3-blue?style=flat-square"></a>
</div>

---

## What's New in v1.2.0

- **120Hz Native `.ca` Live Preview (`LiveCAPreviewView`)**: Clean-room Objective-C `CamloCAStageController` (`CAPackage` + `CAStateController`) paired with a 120Hz ProMotion `CADisplayLink` & `CoreMotion` tilt engine lets you inspect and interact with `.tendies` packs (`LayeredAnimation`, `ParameterizedCA`, and `Still`) directly inside Vault X-Ray and Cloud Gallery — complete with live `Sleep`/`Locked`/`Unlock` transitions, finger tilt scrubbing, Day/Night toggling, and Home Screen mockups;
- **3D Gyroscope Spatial Parallax (`ParameterizedCA`)**: Toggle 120Hz gyroscope depth and depth scale (`25%–100%`) or trigger a 1-tap Auto 3D Orbit Demo in both Studios; compiles `wantsDeviceMotion = true` `wallpaper.ca` bundles with 6 `<wallpaperParallaxGroups>` entries (overscanned background + inverse floating/foreground planes);
- **Day/Night Dual Appearance (`appearanceAware`)**: Enable dual Day/Night mode in Slide-to-Morph Studio with 1-tap `CoreImage` Moonlight grading or custom night frames, night cutouts, and night particles — writing both `default` and `dark` variants into `Wallpaper.plist`;
- **Smart Clock Typography, Contrast Color & Home Screen Pairing (`PosterStyleGenerator`)**: Samples clock-sky luminance and dominant hues to drive 6 `PosterKit` time fonts (`PRTimeFontIdentifier*`), 8 color strategies, and 4 Home Screen companion styles (`Soft-Focus Blur`, `Clear Match`, `Matched Gradient`, `Matched Solid`) encoded directly into binary `titleStyleConfiguration.plist`, `homescreenConfiguration.plist`, and `RuntimeSnapshotMetadata`.

## Key Features

1. **Zero-Code Slide-to-Morph Studio (`MorphEditorView`)**
   - Pick 2–3 images (`Locked`, `Unlock`, and optional custom `Sleep` AOD art) to compile spec-compliant `LayerKit` 3-state CAML packages automatically;
   - **6 Curated Transition Curves**: *Curtain Rise*, *Burst Awaken*, *Silk Crossfade*, *Flash Morph*, *Holo Flip*, and *AOD Gaze* with customizable duration (`0.35s–1.40s`) and spring bounce (`0%–100%`);
   - **11 Curated HD Pixel-Aligned Official Presets (`PresetGallery.bundle`)**: **6 award-inspired natural landscapes** (*Dolomites Alpenglow*, *Namib Dune Geometry*, *Iceland Basalt Coast*, *Yosemite Firefall*, *Mount Fuji Sea of Clouds*, *Alpine Starry Aurora*) and **5 creative themes** (*Starlight Valkyrie*, *Ink Moon to Golden Dawn*, *Midnight GT Ignition*, *Aegis Mecha Overdrive*, *Sleepy Shiba Morning*) — complete with pre-extracted 8-bit foreground depth masks ready to apply in 1 tap;
   - **Multi-Source Cloud `.tendies` Gallery (330+ Packs · [`wallpapers/`](./wallpapers/README.md) OTA & Live Previews)**: Browse **Camlo Official (10 animated packs with animated WebP grid & sheet previews, 1-tap `120Hz Interactive .ca Try-On`, `OfficialGallerySeed.bundle` offline/private seed & SHA-256 checks)** plus live catalogs from **CAPlayground (183+)**, **Nugget Custom (111+)**, and **Apple Collections (32+)** — featuring clean-room `CamloRemotePreview` Core Animation keyframe playback, `CamloEndpointRanker` (5-min host EWMA latency cache + `Range: bytes=0-1` probe), iOS `/var -> /private/var` canonical archive extraction, and full iOS 26/27 cross-device package normalization (`versions/0`, `.wallpaperCollection` ID sync & `productTypes` stripping);
   - **Visual Installed Lock Screen Manager & Universal `.tendies` Engine**: Powered by 100% Camlo-native `SystemPosterStore` with ImageIO 520px disk-cached thumbnails, batch `PBRoleIndexFile` pruning, single-pass streaming Zip-Slip-hardened unpacking, `*CollectionsPoster*`/`*MercuryPoster*` mirroring, and pure POSIX C `worse_query` App Group `Library/Caches` guarding;
   - **Hybrid Live Photo × Morph & Interactive Lock Screen Crop Studio**: Pick static photos, **Live Photos**, or short video clips directly into `Locked` / `Unlock` slots for continuous motion + morph transitions under a Jetsam-safe memory budget, plus non-destructive pan/pinch framing with live `09:41` clock & control guides and blurred edge-extend fill.

2. **On-Device Vision AI Clock Depth + Hardware Particles**
   - **AI Foreground Cutout (`Floating.ca`)**: Uses Apple Neural Engine (`VNGenerateForegroundInstanceMaskRequest`) to isolate people, characters, or pets into `Floating.ca`, rendering naturally **in front of** the iOS Lock Screen Clock (`09:41`) while morphing in sync with `Background.ca`;
   - **8 Multi-Dimensional Particle & Volumetric Light FX (`Foreground.ca`)**: *Meteor Shower*, *Tyndall Sunbeams*, *Aurora Silk Ribbon*, *Sakura*, *Snowfall*, *Starlight*, *Embers*, and *Fireflies* powered by 17 bespoke CoreGraphics vector sprites, additive (`plusL`) volumetric ribbons, and hardware `CAEmitterLayer` choreography — automatically throttled to `0` birthRate and animation `speed` in Always-On Display (`Sleep`) for zero battery drain.

3. **Video & Live Photo Motion Studio (`VideoEditorView`)**
   - Import `MP4` / `MOV` clips from Photos/Files or pick `PHLivePhoto` directly;
   - Auto-crops to 9:16 Retina resolution within `PosterBoard`'s Jetsam memory envelope (`12 / 18 / 24 FPS`, max 150 frames) and compiles native `CAKeyframeAnimation` CAML loops in **Seamless Ping-Pong** or **Standard Loop** mode.

4. **Interactive Lock Screen Simulator & `.tendies` Vault**
   - Scrub transitions continuously with your finger right inside the 60/120Hz simulated iPhone bezel;
   - Full `.tendies` import/export compatibility with `CAPlayground`, `Nugget`, and `Erosion`, featuring **CAML X-Ray Inspection**, **Zip-Slip traversal protection**, **multi-file descriptor ID synchronization**, **non-destructive `GalleryCache` refresh**, and **`.camlo_origin`-scoped safe cleanup**.

---

## Compatibility

- **iOS / iPadOS 26.0 – 26.7.2** & **iOS / iPadOS 27.0 – 27.2.1 / 27.3 beta 1**: Full 1-tap on-device apply support (since `com.apple.PosterBoard` resides in `/var/mobile/Containers/Data/Application`, `CSStore2` + `worse_query` direct container injection works across both iOS 26 and iOS 27).

---

## Installation & Sideloading

> [!WARNING]
> Direct on-device PosterBoard apply requires at least one valid `App Group` entitlement injected by your signing tool. Sign and install using **SideStore, AltStore, Feather, Sideloadly, Impactor, iLoader**, or a paid Apple Developer certificate with an App Group enabled (`Camlo` dynamically detects re-signed App Group IDs at runtime; without an App Group, creation and `.tendies` export remain 100% functional).

### Option A: Subscribe to Official Auto-Updating Source (Recommended)

Tap any button below on your iOS/iPadOS device to add the official source (auto-synced on every GitHub Release, with declared `App Group` entitlement and `SHA-256` checksums):

<p>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json&r=sidestore"><img alt="Add to SideStore" src="https://img.shields.io/badge/Add%20to-SideStore-7C3AED?style=for-the-badge"></a>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json&r=altstore"><img alt="Add to AltStore" src="https://img.shields.io/badge/Add%20to-AltStore-0284C7?style=for-the-badge"></a>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json&r=feather"><img alt="Add to Feather" src="https://img.shields.io/badge/Add%20to-Feather-EC4899?style=for-the-badge"></a>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json"><img alt="More Clients" src="https://img.shields.io/badge/More%20Clients-LiveContainer%20%2F%20Copy%20URL-475569?style=for-the-badge"></a>
</p>

Or copy and add the source URL manually (compatible with SideStore, AltStore, Feather, LiveContainer, and ESign):
```text
https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json
```

### Option B: Manual IPA Sideloading

1. Download the latest `Camlo_v1.2.4_Bilingual.ipa` from [Releases](https://github.com/Kianuni/Camlo/releases/latest).
2. Sideload with any signing tool above; inside the app, **System & Settings → App Source & Updates** also supports switching to the Mainland China accelerated mirror or checking for updates.

### Quick 3-Step Usage

1. Pick a preset, custom photos, or a short video/Live Photo and tap **1-Tap Apply to Lock Screen**, then tap **Respring Now** (or force-close `PosterBoard` in the App Switcher).
2. Long-press your Lock Screen and tap **`+`** to open the wallpaper gallery.
3. **Do not tap Photos** — look in your device-exclusive row (**"Wallpaper designed for your iPhone"**, starting at card #2 next to the default pink card) or scroll down to **Collections** on older models.

---

## Building from Source

```bash
chmod +x ./ipabuild.sh
./ipabuild.sh
```

Produces `Camlo_v1.2.4_Bilingual.ipa` and refreshes `apps.json`, `repo.json`, `esign.json`, `repo_cn.json`, and `esign_cn.json`.

---

## Related Projects

Companion iOS / iPadOS 26–27 open-source tools by the same author:

- **[Erosion-CN](https://github.com/Kianuni/Erosion-CN)**: Bilingual, bootloop-hardened iOS / iPadOS `MobileGestalt` & cross-container customization toolkit (Apple Intelligence & overseas eSIM unlock on `CH/A` devices, app data backup, cache cleaner, and PosterBoard tweaks);
- **[AppleFlow](https://github.com/Kianuni/AppleFlow)**: Zero-MitM routing modules, rule-sets, and local Config Doctor for Apple Intelligence, PCC High-Quality Clean Up, and Mandarin Siri;
- **[WQGuard](https://github.com/Kianuni/WQGuard)**: Zero-dependency, 100% read-only iOS sandbox escape detector, Mach-O static analyzer, and firmware CVE guard.

---

## License & Credits

Released under the **[GNU General Public License v3.0 (GPLv3)](./LICENSE)**. All core v1.1.0+ mechanisms are 100% Camlo clean-room native implementations. Special thanks to upstream open-source projects and researchers:
- **[frs0n/placard](https://github.com/frs0n/placard)** for **feature & UX inspiration** (App Group cache guarding, installed Lock Screen manager, multi-extension support & community gallery concepts)
- **[jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion)** (`lunginspector`, `neonmodder123`, `skadz108`) for `CSStore2` container resolution, `PosterBoard` injection, and jailed respring references
- **[forcequitOS/worse_query](https://github.com/forcequitOS/worse_query)** (`forcequit` & `0xjohnnydev`) for iOS cross-container sandbox research
- **[CAPlayground](https://github.com/CAPlayground/CAPlayground)** & **[CAPlayground/wallpapers](https://github.com/CAPlayground/wallpapers)**, **[Nugget](https://github.com/leminlimez/Nugget)** & **[SerStars/nugget-wallpapers](https://github.com/SerStars/nugget-wallpapers)** for open `.tendies` / CAML specs and community wallpaper catalogs
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)** by `Thomas Zoechling`
