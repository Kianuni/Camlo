# Camlo · 开幕 — Detailed Features & Architecture

<p>
  <a href="../README_EN.md">← Back to Overview</a> ·
  <a href="./FEATURES.md">中文详细介绍</a> ·
  <a href="../wallpapers/README.md">🎨 60 Official Cloud Wallpapers</a>
</p>

---

## Core Rendering & Engine Architecture

- **Native iPhone Duo Dual-Screen Engine (`Inner` + `Outer` `<wallpapers>`)**: Compiles unified `WallpaperKit` `ParameterizedCA` (`Marble` / `requiresLandscapeScaling = true`) packages embedding both the `466×678` pt `Outer` cover planes (`BACKGROUND`/`FLOATING`) and `951×669` pt `Inner` unfolded landscape planes (`BACKGROUND_INNER`/`FLOATING_INNER`), with separate gyro parallax, clock-depth cutouts, custom media pickers, and live Outer/Inner preview switching across Morph Studio, Video Studio, and Vault X-Ray;
- **120Hz Native `.ca` Live Preview (`LiveCAPreviewView`)**: Clean-room Objective-C `CamloCAStageController` (`CAPackage` + `CAStateController`) paired with a 120Hz ProMotion `CADisplayLink` & `CoreMotion` tilt engine lets you inspect and interact with `.tendies` packs (`LayeredAnimation`, `ParameterizedCA`, and `Still`) directly inside Vault X-Ray and Cloud Gallery — complete with live `Sleep`/`Locked`/`Unlock` transitions, iPhone Duo Outer/Inner display switching, finger tilt scrubbing, Day/Night toggling, and Home Screen mockups;
- **3D Gyroscope Spatial Parallax (`ParameterizedCA`)**: Toggle 120Hz gyroscope depth and depth scale (`25%–100%`) or trigger a 1-tap Auto 3D Orbit Demo in both Studios; compiles `wantsDeviceMotion = true` `wallpaper.ca` bundles with 6 `<wallpaperParallaxGroups>` entries (overscanned background + inverse floating/foreground planes) and full `<wallpaperPropertyGroups>` (`v_sleep`/`v_lock`/`v_home` KVC interpolation for Lock-to-Unlock & Depth Cutout transitions);
- **Day/Night Dual Appearance (`appearanceAware`)**: Enable dual Day/Night mode in Slide-to-Morph Studio with 1-tap `CoreImage` Moonlight grading or custom night frames, night cutouts, and night particles — writing both `default` and `dark` variants into `Wallpaper.plist`;
- **Smart Clock Typography, Contrast Color & Home Screen Pairing (`PosterStyleGenerator`)**: Samples clock-sky luminance and dominant hues to drive 6 `PosterKit` time fonts (`PRTimeFontIdentifier*`), 8 color strategies, and 4 Home Screen companion styles (`Soft-Focus Blur`, `Clear Match`, `Matched Gradient`, `Matched Solid`) encoded directly into binary `titleStyleConfiguration.plist`, `homescreenConfiguration.plist`, and `RuntimeSnapshotMetadata`;
- **iOS 26 / iOS 27 Liquid Glass UI**: Native grouped editorial cards and single-layer Liquid Glass navigation toolbar platters adapting seamlessly across Dark and Light appearances.

---

## Key Modules in Detail

### 1. Zero-Code Slide-to-Morph Studio (`MorphEditorView`)

- Pick 2–3 images (`Locked`, `Unlock`, and optional custom `Sleep` AOD art) to compile spec-compliant `LayerKit` 3-state CAML packages automatically.
- **6 Curated Transition Curves**: *Curtain Rise*, *Burst Awaken*, *Silk Crossfade*, *Flash Morph*, *Holo Flip*, and *AOD Gaze* with customizable duration (`0.35s–1.40s`) and spring bounce (`0%–100%`).
- **6 Built-in Award-Winning Landscape Presets (`PresetGallery.bundle`)**: Curated pixel-aligned Lock <-> Unlock landscapes (*Dolomites Alpenglow*, *Namib Dune Geometry*, *Iceland Basalt Coast*, *Yosemite Firefall*, *Mount Fuji Sea of Clouds*, *Alpine Starry Aurora*) with pre-extracted 8-bit Clock-Depth masks ready in 1 tap — keeping the IPA ultra-slim (~9 MB) while all 60 museum-pantheon official packs live cleanly in the repository.
- **Multi-Source Cloud `.tendies` Gallery (385+ Packs · [`wallpapers/`](../wallpapers/README.md) Zero-Bloat OTA)**: Browse **60 zero-bloat museum-pantheon official packs across Old Master Oils, Impressionism, Song Dynasty Scrolls, Cosmos & 10 iPhone Duo Dual-Screen exclusives in `wallpapers/` (animated WebP grid & sheet previews, 1-tap `120Hz Interactive .ca Try-On`, and SHA-256 verification)** plus live catalogs from **CAPlayground (183+)**, **Nugget Custom (111+)**, and **Apple Collections (32+)** — featuring clean-room `CamloRemotePreview` Core Animation keyframe playback, `CamloEndpointRanker` (5-min host EWMA latency cache + `Range: bytes=0-1` probe), iOS `/var -> /private/var` canonical archive extraction, and full iOS 26/27 cross-device package normalization (`versions/0`, `.wallpaperCollection` ID sync & `productTypes` stripping).
- **Visual Installed Lock Screen Manager & Universal `.tendies` Engine**: Powered by 100% Camlo-native `SystemPosterStore` with ImageIO 520px disk-cached thumbnails, batch `PBRoleIndexFile` pruning, single-pass streaming Zip-Slip-hardened unpacking, `*CollectionsPoster*`/`*MercuryPoster*` mirroring, and pure POSIX C `worse_query` App Group `Library/Caches` guarding.
- **Hybrid Live Photo × Morph & Interactive Lock Screen Crop Studio**: Pick static photos, **Live Photos**, or short video clips directly into `Locked` / `Unlock` slots for continuous motion + morph transitions under a Jetsam-safe memory budget, plus non-destructive pan/pinch framing with live `09:41` clock & control guides and blurred edge-extend fill.

### 2. On-Device Vision AI Clock Depth + Hardware Particles

- **AI Foreground Cutout (`Floating.ca`)**: Uses Apple Neural Engine (`VNGenerateForegroundInstanceMaskRequest`) to isolate people, characters, or pets into `Floating.ca`, rendering naturally **in front of** the iOS Lock Screen Clock (`09:41`) while morphing in sync with `Background.ca`.
- **8 Multi-Dimensional Particle & Volumetric Light FX (`Foreground.ca`)**: *Meteor Shower*, *Tyndall Sunbeams*, *Aurora Silk Ribbon*, *Sakura*, *Snowfall*, *Starlight*, *Embers*, and *Fireflies* powered by 17 bespoke CoreGraphics vector sprites, additive (`plusL`) volumetric ribbons, and hardware `CAEmitterLayer` choreography — automatically throttled to `0` birthRate and animation `speed` in Always-On Display (`Sleep`) for zero battery drain.

### 3. Video & Live Photo Motion Studio (`VideoEditorView`)

- Import `MP4` / `MOV` clips from Photos/Files or pick `PHLivePhoto` directly.
- Auto-crops to 9:16 Retina resolution within `PosterBoard`'s Jetsam memory envelope (`12 / 18 / 24 FPS`, max 150 frames) and compiles native `CAKeyframeAnimation` CAML loops in **Seamless Ping-Pong** or **Standard Loop** mode.

### 4. Interactive Lock Screen Simulator & `.tendies` Vault

- Scrub transitions continuously with your finger right inside the 60/120Hz simulated iPhone bezel.
- Full `.tendies` import/export compatibility with `CAPlayground`, `Nugget`, and `Erosion`, featuring **CAML X-Ray Inspection**, **Zip-Slip traversal protection**, **multi-file descriptor ID synchronization**, **non-destructive `GalleryCache` refresh**, and **`.camlo_origin`-scoped safe cleanup**.

---

## System Compatibility & How Direct Apply Works

- **iOS / iPadOS 26.0 – 26.7.2** & **iOS / iPadOS 27.0 – 27.2.1 / 27.3 beta 1**: Full 1-tap on-device apply support (since `com.apple.PosterBoard` resides in `/var/mobile/Containers/Data/Application`, `CSStore2` + `worse_query` direct container injection works across both iOS 26 and iOS 27).

> 💡 Direct on-device `PosterBoard` apply requires at least one valid `App Group` entitlement injected by your signing tool (**SideStore, AltStore, Feather, Sideloadly, Impactor, iLoader**, or a developer certificate with App Group enabled). Without an App Group entitlement, creation, cloud browsing, and `.tendies` export remain 100% functional.

---

## Building from Source

Requires macOS + Xcode 26 / 27+:

```bash
chmod +x ./ipabuild.sh
./ipabuild.sh
```

Produces `Camlo_v1.3.0_Bilingual.ipa` and refreshes [`apps.json`](../apps.json), [`repo.json`](../repo.json), [`esign.json`](../esign.json), [`repo_cn.json`](../repo_cn.json), and [`esign_cn.json`](../esign_cn.json).

---

## Related Projects

Companion iOS / iPadOS 26–27 open-source tools by the same author:

- **[Erosion-CN](https://github.com/Kianuni/Erosion-CN)**: Bilingual, bootloop-hardened iOS / iPadOS `MobileGestalt` & cross-container customization toolkit (Apple Intelligence & overseas eSIM unlock on `CH/A` devices, app data backup, cache cleaner, and PosterBoard tweaks);
- **[AppleFlow](https://github.com/Kianuni/AppleFlow)**: Zero-MitM routing modules, rule-sets, and local Config Doctor for Apple Intelligence, PCC High-Quality Clean Up, and Mandarin Siri;
- **[WQGuard](https://github.com/Kianuni/WQGuard)**: Zero-dependency, 100% read-only iOS sandbox escape detector, Mach-O static analyzer, and firmware CVE guard.

---

## License & Credits

Released under the **[GNU General Public License v3.0 (GPLv3)](../LICENSE)**. All core v1.1.0+ mechanisms are 100% Camlo clean-room native implementations. Special thanks to upstream open-source projects and researchers:

- **[frs0n/placard](https://github.com/frs0n/placard)** for **feature & UX inspiration** (App Group cache guarding, installed Lock Screen manager, multi-extension support & community gallery concepts)
- **[jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion)** (`lunginspector`, `neonmodder123`, `skadz108`) for `CSStore2` container resolution, `PosterBoard` injection, and jailed respring references
- **[forcequitOS/worse_query](https://github.com/forcequitOS/worse_query)** (`forcequit` & `0xjohnnydev`) for iOS cross-container sandbox research
- **[CAPlayground](https://github.com/CAPlayground/CAPlayground)** & **[CAPlayground/wallpapers](https://github.com/CAPlayground/wallpapers)**, **[Nugget](https://github.com/leminlimez/Nugget)** & **[SerStars/nugget-wallpapers](https://github.com/SerStars/nugget-wallpapers)** for open `.tendies` / CAML specs and community wallpaper catalogs
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)** by `Thomas Zoechling`
