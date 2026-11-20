#!/usr/bin/env python3
"""
Camlo · 开幕 — 自动生成与更新签名工具软件源清单
输出文件：
  - apps.json     (AltStore / SideStore / Feather / LiveContainer 官方标准源，含 SHA-256 与 App Group)
  - repo.json     (兼容历史链接：与 apps.json 内容一致的官方直连源)
  - esign.json    (全能签 / 轻松签 ESign 官方直连源)
  - repo_cn.json  (国内加速镜像源：同时加速图标与 Release IPA 下载)
  - esign_cn.json (国内加速镜像源：全能签 / 轻松签专用)
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import hashlib
import io
import json
import os
import plistlib
import re
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_REPO_SLUG = "Kianuni/Camlo"
MIRROR_PREFIX = "https://ghfast.top/"
ALT_TINT_COLOR = "#6B4EFF"
ESIGN_TINT_COLOR = "6B4EFF"

DEFAULT_CHANGELOG_BY_VER: dict[str, str] = {
    "1.3.4": (
        "v1.3.4 Build 27 — 彻底修复真机锁屏景深破框 (#7, #3) & 3D 陀螺仪重影与立体视差重塑 (#3) | Fix On-Device Clock-Depth & 3D Gyroscope Ghosting:\n"
        "1. 修复自制及官方壁纸在 iOS 真机锁屏不触发「人物/主体挡时间（景深破框）」的问题（#7, #3）：定位并满足 `WallpaperKit` (`supportsDepthEffect`) 对 `ParameterizedCA` 捆绑包路径与 `LayeredAnimation` `Floating.ca` 路径需包含 `Clownfish` 标记的系统白名单校验，防止系统日志触发 `collapsing floating view into foreground view` 将前景压到时间之下；覆盖 3D `ParameterizedCA` 与普通滑动/视频 `LayeredAnimation` 双引擎，并支持金库已有壁纸与外部导入包开机/直写自动原地自愈；\n"
        "   (Fix On-Device Lock Screen Clock-Depth (#7, #3): satisfies `WallpaperKit.supportsDepthEffect`'s internal `Clownfish` path whitelist for both `ParameterizedCA` `.wallpaper` bundles and `LayeredAnimation` `Floating.ca` layers so subjects render natively in `PRPosterLevelFloating` above the clock instead of collapsing behind time, with automatic Vault & imported `.tendies` self-healing.)\n"
        "2. 修复开启 3D 陀螺仪视差后主体背后出现「双重人物轮廓重影」及双平面生硬错位的问题（#3）：将背景与前景超采样倍率（`1.065x`）对齐为精确 1:1 居中贴合、为抠图遮挡后的背景区域自动执行金字塔与水平扫线补全修复（消除晃动时从人物背后漏出的第二张脸/兵器残影），并引入 `sublayerTransform` 3D 透视投影与 `transform.rotation.x/y` 细腻倾斜响应；\n"
        "   (Fix 3D Gyroscope Double-Silhouette Ghosting & Flat Feel (#3): locks resting BG/FG overscan to exact 1:1 registration (`1.065x`), runs exterior-inward background occlusion inpainting behind foreground cutouts, and adds `sublayerTransform` 3D perspective projection + subtle `transform.rotation.x/y` tilt.)\n"
        "3. 云端全部 76 套官方 `.tendies`（含「次元 3D」「海岸海报 3D」「iPhone Duo」「馆藏名画」）同步重编升级并完成 `CAPackage` 与 SHA-256 全量校验。\n"
        "   (Upgraded all 76 official cloud `.tendies` packs OTA with full `CAPackage` and SHA-256 verification.)"
    ),
    "1.3.3": (
        "v1.3.3 Build 26 — 修复 SideStore / AltStore 个人免费 Apple ID 安装失败 (#6) | Fix SideStore / AltStore App ID Registration:\n"
        "1. 修复使用 SideStore / AltStore 个人免费签安装时因 `CFBundleDisplayName` 含中文及空格导致 `An invalid value '开幕 Camlo' was provided for the parameter 'appIdName'` 报错的问题：将主 `Info.plist` 顶层 `CFBundleDisplayName` 与 `apps.json` `name` 统一调整为纯英文 ASCII 标识 `Camlo`，并通过 `InfoPlist.xcstrings`（`zh-Hans.lproj/InfoPlist.strings`）本地化保留简体中文系统桌面显示名称「开幕 Camlo」；\n"
        "   (Fix SideStore / AltStore Free Apple ID `appIdName` Error (#6): sets the top-level `Info.plist` `CFBundleDisplayName` and `apps.json` `name` to pure ASCII `Camlo` so Apple's `addAppId` endpoint succeeds reliably, while preserving the localized Chinese Home Screen label `开幕 Camlo` via `InfoPlist.xcstrings`.)\n"
        "2. 完整包含 `v1.3.2` iPhone Duo 折叠屏 `retinaMultiplier` 与内屏偏移修复、10 套原创「次元 3D」二次元交互包与金库旧包自动原地自愈。\n"
        "   (Includes all `v1.3.2` iPhone Duo scaling/centering fixes, 10 official 3D Anime packs, and automatic Vault self-healing.)"
    ),
    "1.3.2": (
        "v1.3.2 Build 25 — 修复 iPhone Duo（折叠屏）所有壁纸缩小为 1/3 与展开内屏偏移问题 & 金库旧包自动自愈 | Fix iPhone Duo 1/3 Shrunk Scaling & Off-Center Inner Screen Layout:\n"
        "1. 彻底修复 iPhone Duo（#4）：修正 `WallpaperKit` `<wallpapers>` `retinaMultiplier` 由 `3` 改为 `1`（解决以逻辑点坐标 `466×678` / `951×669` 编译时被按 `@3x` 缩小为 `1/3` 尺寸的问题），并将 `BACKGROUND_INNER` / `FLOATING_INNER` 图层 `position` 对齐 `__capRootLayer__` 中心（`233 339`），消除展开内屏右下方偏移；同时升级外屏素材采样至全 `@3x`（`1398×2034`）与内屏至高清（`2282×1606`）；\n"
        "   (Fix iPhone Duo 1/3 Shrink & Inner-Screen Offset (#4): updates `retinaMultiplier` from `3` to `1` for logical-point `466×678` / `951×669` `<wallpapers>` variants, aligns `BACKGROUND_INNER` / `FLOATING_INNER` positions with `__capRootLayer__` center (`233 339`) so `WallpaperKit`'s `hostingLayer` fills the unfolded canvas seamlessly, and upgrades Duo export assets to crisp `1398×2034` Outer and `2282×1606` Inner resolution.)\n"
        "2. 10 套官方云端 iPhone Duo 双屏壁纸全量重新编译并校验；已下载或自制保存在金库的旧版 Duo 壁纸升级 `v1.3.2` 后会自动原地自愈（重新点击一次「一键应用到锁屏」并注销即可满屏生效，无需重新创作）。\n"
        "   (Recompiled All 10 Official Cloud Duo Packs + Automatic Vault Self-Healing: existing downloaded or Studio-created Duo wallpapers in your Vault heal automatically in-place upon updating to `v1.3.2` — just tap 1-Tap Apply again and respring.)"
    ),
    "1.3.1": (
        "v1.3.1 Build 24 — 新增 10 套原创「次元 3D」二次元交互官方云端壁纸（真机 3D 陀螺仪 + AI 景深挡时间 + 粒子流光）& 云端分类筛栏升级 | 10 Original 3D Gyro + Clock-Depth Anime Cloud Packs:\n"
        "1. 官方云端壁纸广场扩容至 70 套（全网总库 395+ 款 · 零安装包体积占用）：新增 10 套 100% 原创「次元 3D」二次元精品壁纸（墨线樱绘、赛博瞳孔唤醒、雨岸平交道霞光、狐面鸟居千灯、猩红爵士切入、天台流星雨、Lo-Fi 窗猫、星穹魔女星盘、轨道机甲出击、松崖青莲仙剑），全部原生编译为 single-screen ParameterizedCA（3D 硬件陀螺仪视差 + 实景人物/武器/狐耳/伞檐遮挡 09:41 时间 + 粒子特效），一次解决三方搬运包无真机陀螺仪或缺少前景遮挡的问题；\n"
        "   (10 Original 3D Anime Cloud Packs in `wallpapers/` — 70 Official / 395+ Total, Zero IPA Bloat: introduces 10 100%-original Anime packs compiled natively as `ParameterizedCA` with true on-device 120Hz 3D Gyro Parallax, Vision foreground cutouts over the `09:41` clock, and hardware particle FX.)\n"
        "2. 「云端 .tendies 壁纸广场」新增 `次元 3D (Anime 3D)` 专区并升级为横向胶囊计数筛选栏，零截断浏览全部 70 套官方作品。\n"
        "   (Adds the `Anime 3D` category filter and a scrollable pill selector bar inside Cloud Gallery.)"
    ),
    "1.2.9": (
        "1. 优化首页右上角「直写就绪 / 导出模式」状态指示器与 iOS 26 / iOS 27 原生液态玻璃（Liquid Glass）导航栏的视觉融合：移除多余的内层胶囊底色与双层描边，使状态指示灯与文字直接承载于单层原生液态玻璃外框中，深浅色模式更通透协调；\n"
        "2. 同步首页「云端壁纸广场」卡片精选徽章数量至 `375+`。\n"
        "(UI Polish: integrates the Studio Home top-right container status indicator directly into iOS 26/27's native Liquid Glass toolbar platter—removing the nested inner capsule and double hairline border—and updates the Cloud Gallery card badge to `375+`.)"
    ),
    "1.2.8": (
        "1. 官方云端壁纸广场扩容至 50 套馆藏殿堂级杰作：新增 30 套大师纯艺术滑动变身壁纸（锚定伦勃朗、维米尔、卡拉瓦乔、拉图尔、萨金特、委拉斯开兹、达芬奇晕涂、莫奈、梵高、索罗利亚、柯罗、毕沙罗、克里姆特、弗里德里希、哈默修伊、怀斯蛋彩、艾瓦佐夫斯基、惠斯勒、霍默、雷东粉画，以及马远、郭熙、宋徽宗、夏圭、米芾、马麟、八大山人、川濑巴水与北斋馆藏意境），真实粗亚麻布厚涂、透明罩染、古绢裂纹与宣纸枯笔质感，全量零体积托管于 wallpapers/；\n"
        "2. 全系 50 套官方壁纸均配备动画 WebP 实时预览、SHA-256 完整性校验、120Hz 原生 .ca 交互试穿与一键直写锁屏，保持 ~9 MB 超轻量安装包。"
    ),
    "1.2.7": (
        "v1.2.7 Build 20 — 官方云端画廊重塑至 20 套博物馆级意境美学 + 私有仓库内测 GitHub Token 直连授权 | 20 Museum-Grade Official Cloud Packs & Private-Repo Token Testing:\n"
        "1. 官方云端壁纸库美学重塑与扩容（15 → 20 套）：全面退役早期粗糙风格主题，以长期耐看的意境美学标准重制 20 套精品——涵盖极致自然风光（罗弗敦极夜、乌尤尼盐镜、巴塔哥尼亚日照、贝加尔冰渊）、深空宇宙奇观（韦伯创生之柱、黑洞事件视界、卡西尼土星逆光环、阿波罗地出）、东方诗意审美（千里江山青绿、敦煌月牙星穹、苔庭听雨、水墨寒松）与大师光影油画/空间建筑（莫奈睡莲、透纳雾海、特瑞尔苍穹天窗、洞石圣殿光束），升级 `600×1300` 摄影级呼吸循环与高质感 WebP 预览并修正叠加黑边渗色。\n"
        "   (Rebuilt & Expanded Official Cloud Gallery to 20 Museum-Grade Packs: replaces all 15 earlier packs with 20 contemplative masterpieces spanning Nature, JWST/Cassini/Apollo Cosmos, Eastern Song Scroll & Dunhuang Scrolls, Impressionist/Romanticist Oils, and Turrell/Ando Light Architecture — upgraded to crisp `600×1300` cinemagraphs, seamless crossfades, and `360×780` WebP previews while keeping the IPA ~9 MB.)\n"
        "2. 私有仓库内测授权访问与说明完善：在「设备与设置 → 软件源订阅 → 高级」新增可选 `GitHub Token` 配置，内测阶段即使 `Kianuni/Camlo` 保持私有，填写后也可实时拉取官方目录、动画预览、下载 `.tendies` 与检查更新；仓库公开后无需配置即可享全网节点加速。\n"
        "   (Optional GitHub Token for Private-Repo Testing: adds an optional Token field in System & Settings -> App Source -> Advanced so testers can stream private `Kianuni/Camlo` cloud catalogs, animated previews, `.tendies`, and OTA updates immediately.)"
    ),
    "1.2.6": (
        "v1.2.6 Build 19 — 修复开启陀螺仪 3D 视差后锁屏只显示第一张图（完整支持 `<wallpaperPropertyGroups>` 三态插值与金库旧包自愈） | Fix 3D Gyroscope (`ParameterizedCA`) Lock/Unlock Morphing & Self-Healing:\n"
        "1. 修复 `ParameterizedCA`（开启「陀螺仪 3D 视差」）在 iOS 26 / iOS 27 真机锁屏及「设为墙纸组合」预览中卡在第一张图不随解锁变身的问题：在 `wallpaper.ca/main.caml` 中完整生成符合 Apple `WallpaperKit` (`WKParameterizedCAPackageLoader`) 规范的 `<wallpaperPropertyGroups>`（精确映射 `CALayer.name` 与 `Background`/`Floating` 视图归属，按 `v_sleep` / `v_lock` / `v_home` 插值并自动展开 `transform.scale.xy` 为 `scale.x` + `scale.y`），改用原生 `<CALayer>` 承载视差容器以保留体积光与粒子混合滤镜，并消除滑动叠化中点的暗场渗色。\n"
        "   (Fix 3D Gyroscope `ParameterizedCA` Lock/Unlock Transitions on iOS 26/27: emits full `WallpaperKit`-compliant `<wallpaperPropertyGroups>` entries with `v_sleep`/`v_lock`/`v_home` KVC interpolation, `CALayer.name` + `Background`/`Floating` routing, `transform.scale.x/y` expansion, native `<CALayer>` parallax containers, and zero black-bleed crossfade blending.)\n"
        "2. 金库旧版 3D 壁纸原位自愈 & 社区陀螺仪 `.tendies` 实时预览/X-Ray 增强：对之前保存的旧版 3D `.tendies` 在重新应用写入或导出时自动补全 `<wallpaperPropertyGroups>` 与视差层类型；应用内 `120Hz` 实时舞台 (`LiveCAPreviewView`) 与 `X-Ray` 透视同步支持直接解析并驱动仅含 `<wallpaperPropertyGroups>` 的社区 3D 动态壁纸包。\n"
        "   (Vault Self-Healing & Community 3D Preview/X-Ray Support: automatically heals previously compiled 3D `.tendies` in-place during apply/export, and adds `<wallpaperPropertyGroups>` stage playback and X-Ray inspection for community `ParameterizedCA` packages.)"
    ),
    "1.2.5": (
        "v1.2.5 Build 18 — 极限安装包瘦身 (~41 MB → ~9 MB)：仅内置 6 套获奖风光，全部潮流创意与动态壁纸云端零体积托管 | Ultra-Slim IPA (~9 MB) & Zero-Bloat Official Cloud Gallery:\n"
        "1. 安装包极限瘦身：移除随包体积较大的 `OfficialGallerySeed.bundle` 以及 5 套「潮流创意」内置包（星穹剑姬、寒江孤月、暗夜超跑、苍穹机甲、柴犬团子），`PresetGallery.bundle` 仅保留 **6 套获奖摄影级自然风光**（多洛米蒂日照金山、纳米布光影沙丘、冰岛黑沙玄光、优胜美地熔岩火瀑、富士山破晓云海、凛冬雪峰极光），IPA 安装包体积从 ~41.2 MB 骤降至 ~9 MB。\n"
        "   (Ultra-Slim IPA Footprint: strips `OfficialGallerySeed.bundle` and the 5 Creative packs from the app bundle, keeping only the 6 Award-Winning Landscape packs built-in and cutting IPA size from ~41.2 MB to ~9 MB.)\n"
        "2. 官方云端 `.tendies` 壁纸库扩充至 15 套并全量零体积托管于 `wallpapers/`：将原内置 5 套潮流创意预设连同其 8-bit 景深遮罩一并编译为完整 `.tendies`（ID 18911–18915）与 16 帧动态 WebP 预览图，与原有 10 套无缝动态/景深包组成 15 套零安装包负担的官方云端目录（支持 SHA-256 校验与 WebP 实时动画预览）。\n"
        "   (15 Official Zero-Bloat Cloud Packs in `wallpapers/`: converts the 5 Creative packs + Clock-Depth cutouts into verified `.tendies` packages and animated WebP previews alongside the existing 10 packs — streamed directly from `wallpapers/` with zero IPA bloat.)"
    ),
    "1.2.4": (
        "v1.2.4 Build 17 — 云端 .tendies 解压真机路径修复 & 官方主题全动态预览 | Cloud .tendies Symlink Fix & Live Official Gallery Previews:\n"
        "1. 彻底修复云端/社区 `.tendies` 下载时在真机上误报「检测到非法路径穿越条目，已安全拦截导入」：统一规范化目标根目录与未创建子路径的 `/var` vs `/private/var`（及 `/tmp` vs `/private/tmp`）符号链接前缀校验，同时保留对前置 `/`、`..` 及 `.symlink` 越界条目的严格拦截；扩展目录探索兼容大小写 `Extensions` 与 `ordered-descriptors`。\n"
        "   (Fix False Zip-Slip Rejection on iOS Devices: canonicalizes `/var` vs `/private/var` symlink prefixes between created extraction roots and not-yet-created child entries in `TendiesPackager`, while preserving strict traversal/symlink blocking and case-insensitive `Extensions`/`ordered-descriptors` discovery.)\n"
        "2. Camlo 官方云端主题全面支持实时动态预览与私有库秒装体验：为全部 10 套官方壁纸包生成轻量级 24 位多关键帧 WebP 动态预览（`wallpapers/previews/*.webp`，呈现无缝动态循环与滑动变身+时钟破框遮挡效果），并在云端卡片、详情页及 `120Hz 原生 Core Animation 交互试穿` 链路中接入实时动态渲染与 `OfficialGallerySeed.bundle` 离线/私有仓库兜底。\n"
        "   (Live Dynamic Previews for Camlo Official Packs: adds 24-bit animated WebP previews for all 10 official motion-loop and Clock-Depth morph themes across grid cards and detail sheets, 1-tap `120Hz Interactive .ca Try-On`, and `OfficialGallerySeed.bundle` offline/private-beta fallback.)"
    ),
    "1.2.3": (
        "v1.2.3 Build 16 — 社区/外部壁纸写入可见性修复 & 云端多镜像原生下载重构 | Community .tendies Visibility & Cloud Multi-Mirror Downloader Fix:\n"
        "1. 修复外部导入 / 金库已有 `.tendies` 写入并注销后在锁屏画廊（「收藏」/「专为 iPhone 设计」）找不到的问题：移除 `purgeLegacyBrokenVideoDescriptors` 对合法 `keyPath=\"speed\"` 与离散帧动画的误删，统一将 `userInfo` 中的 `wallpaperRepresentingIdentifier` 写入整型 (`Int`)，清理碰撞的 `7400.DYNAMIC` `suggestionMetadata.plist` 并恢复非陀螺仪壁纸 `logicalScreenClass` 与最高版本号 `PRBPosterExtensionDataStore` 扩展目录定位；金库中之前下载的包在点击写入时自动原地自愈，无需重新下载。\n"
        "   (Fix External/Community & Vault `.tendies` Missing After Respring: removes over-eager CAML `keyPath=\"speed\"` self-deletion, enforces integer `wallpaperRepresentingIdentifier`, strips colliding `7400.DYNAMIC` `suggestionMetadata.plist`, preserves/heals `logicalScreenClass`, and picks the highest active DataStore version.)\n"
        "2. 修复国内无代理环境下云端壁纸库下载报 `TLS错误导致安全连接失败`：移除已失效的 `raw.jsdmirror.com`，接入 `ghfast.top` / `gh-proxy.com` / `ghproxy.net` / `cdn.jsdmirror.com` / `fastly.jsdelivr.net` 多线路容灾与大陆地区自动优选默认线路；改用原生 `URLSessionDownloadTask` 分块落盘 + `PK\\x03\\x04` ZIP 魔数校验并解耦导入重试环，避免错误码被尾随镜像 TLS 错误覆盖。\n"
        "   (Fix Cloud Download TLS Error on CN Networks: drops dead `raw.jsdmirror.com`, adds multi-mirror CDN/proxy fallback with smart CN default routing, replaces byte-by-byte streaming with `URLSessionDownloadTask` + ZIP magic verification, and decouples local import from mirror retries.)\n"
        "3. 优化 CAPlayground 云端目录毫秒级时间戳显示：自动将 `1766052000000` 等 Unix 毫秒时间格式化为 `yyyy-MM-dd` 标准日期。\n"
        "   (Format CAPlayground Unix millisecond timestamps into `yyyy-MM-dd` dates.)"
    ),
    "1.2.2": (
        "v1.2.2 Build 15 — iOS 27.0 容器沙盒令牌修复 & 缓存自愈重塑 | iOS 27.0 Container Token & Caches Recovery Fix:\n"
        "1. 修复 iOS 27.0 (`24A437`) 免电脑直写报 `-6`（内核未下发沙盒扩展令牌）问题：根据运行系统版本动态选用 iOS 27 (`0x8000000000`) 与 iOS 26 (`0x800000000`) XPC 容器查询操作标志，并区分消费令牌失败码 (`-7`)，彻底恢复免电脑一键写入锁屏与画廊定位。\n"
        "   (Fix iOS 27.0 (`24A437`) `-6` Sandbox Token Issuance Error: honors dynamic iOS 27 (`0x8000000000`) vs iOS 26 (`0x800000000`) XPC container operation flags, isolates consume errors as `-7`, and restores on-device 1-tap PosterBoard apply & discovery.)\n"
        "2. App Group `Library/Caches` 文件锁守护与断电/旧版残留自愈：`flock` 独占锁串行化容器查询并单次缓存系统符号句柄，自动检测并恢复旧版中断残留的 `.camlo_caches_saved_*` 备份与悬空符号链接。\n"
        "   (Self-Healing `Library/Caches` Guard: adds `flock` exclusion, `dispatch_once` symbol caching, and automatic startup recovery of stranded `.camlo_caches_saved_*` directories or dangling symlinks.)\n"
        "3. `CSStore2` 只读穿透令牌保留、MCM 直查与状态诊断透明化：保留根权限系统容器只读穿透令牌以加速 `.csstore` 解析，新增 `csstore_mcm_find_app_container` 秒级直查与真实错误码透出。\n"
        "   (CSStore2 Traversal Token Preservation & Transparent Diagnostics: preserves read-only traversal tokens on root-owned system containers, adds direct MCM container query, and surfaces real diagnostic errors in System Settings.)"
    ),
    "1.2.1": (
        "v1.2.1 Build 14 — 容器直写链路加固 & Apple Editorial Bento 首页重塑 | Container Access Hardening & Editorial Studio Bento:\n"
        "1. 容器查询标志协商与 iOS 26.5 CSStore2 布局修复：规范化 `/private/var` 路径、支持 iOS 26/27 XPC 容器查询标志自动协商与有界 LRU 句柄复用，新增 iOS 26.5 CSStore2 布局偏移与容器自动恢复。\n"
        "   (Container Query Flag Negotiation & iOS 26.5 CSStore2 Layout Fix: `/private/var` path canonicalization, automatic iOS 26/27 XPC query flag negotiation, bounded LRU handle reuse, and iOS 26.5 CSStore2 record layouts.)\n"
        "2. Apple Editorial Studio Bento 首页重塑：采用适配深浅色模式的分组表面与细高光描边，重构「滑动解锁变身」旗舰主卡（缓存缩略图）与「视频与实况 / 云端壁纸广场」双栏 Bento 布局。\n"
        "   (Apple Editorial Studio Bento Home Redesign: adaptive dark/light bento surfaces, flagship Slide-to-Morph card with cached preview thumbnails, and balanced 2-column Video & Cloud Gallery cards.)\n"
        "3. 单槽位 AI 主体抠图修复：仅填充锁屏或解锁单个静态槽位时亦可正常提取前景主体。\n"
        "   (Single-Slot AI Subject Cutout Fix: enables foreground subject extraction when only a single static Lock or Unlock slot is populated.)\n"
        "4. 异步壁纸包 X-Ray 透视与实时预览加载：将包结构扫描、多扩展描述符解析与纹理降采样移至后台线程，保持 120Hz 流畅响应。\n"
        "   (Async Package X-Ray & Live Preview Loading: moves `.tendies` inspection, descriptor resolution, and texture downsampling off the main thread.)\n"
        "5. 动态锁屏日期与深色时钟对比度修复：实时渲染本地化锁屏日期，并为深色时钟文字匹配柔和浅色阴影。\n"
        "   (Dynamic Lock Screen Date & Dark-Ink Clock Legibility Fix: dynamic localized Lock Screen date and adaptive light shadow for dark clock ink.)"
    ),
    "1.2.0": (
        "v1.2.0 Build 13 — 120Hz 原生 `.ca` 实时预览 · 陀螺仪 3D 裸眼视差 · 昼夜双生壁纸 · 智能时钟与主屏配套：\n"
        "1. 120Hz 原生 Core Animation 实时交互预览 (`LiveCAPreviewView`)：内置异常安全 ObjC `CAPackage` + `CAStateController` 与 120Hz ProMotion `CADisplayLink`，"
        "在金库透视详情页与云端壁纸广场下载页可直接以真实 Core Animation 层级树（Background → 09:41 时钟 → Floating → Foreground）交互试穿，支持熄屏/锁屏/解锁三态过渡、指尖跟手摆动及 X-Ray 元数据透视。\n"
        "2. 陀螺仪 3D 裸眼视差 (`ParameterizedCA`)：两大创作工坊新增 120Hz 裸眼空间视差开关、深度调节滑块与一键 3D 摆动演示，直接编译含 `wantsDeviceMotion = true`、"
        "防露边超采样背景与反相前景/粒子平面的 `wallpaper.ca`（`wallpaperParallaxGroups`）。\n"
        "3. 昼夜双生壁纸 (`appearanceAware`)：滑动解锁变身工坊支持一键 `CoreImage` 月色夜景调色、自定义夜间双态图/夜间主体破框/夜间粒子，"
        "生成同时包含 `default` 与 `dark` 变体的 `Wallpaper.plist`，随系统深色模式与日落时间自动切换。\n"
        "4. 智能时钟配色字体 & 主屏柔焦配套 (`PosterStyleGenerator`)：自动分析顶部 `09:41` 区域亮度与全画幅主题色板，提供 6 款 `PosterKit` 字体、8 种智能对比/取色策略及 4 种主屏配套模式（柔焦虚化 / 清晰直通 / 同色渐变 / 暗调纯色），"
        "实时输出标准二进制 `titleStyleConfiguration.plist` 与 `homescreenConfiguration.plist`。"
    ),
    "1.1.0": (
        "v1.1.0 Build 12 — 100% Camlo 原生引擎重构 & 外部壁纸真机兼容修复：\n"
        "1. 修复 CAPlayground / Nugget Custom / Apple Collections 外部壁纸导入并注销后未出现在「收藏」与「专为 iPhone 18 Pro Max 设计的墙纸」的真机问题："
        "移除 FileManager `.skipsPackageDescendants` 限制，完整同步 `.wallpaper` / `.wallpaperCollection` 包内的 `Wallpaper.plist`、`WallpaperCollection.plist`、`userInfo` 与描述符 ID；"
        "跨 `versions/0` 与 `versions/1` 自动剔除硬件 `productTypes` 锁定与异设备 `.atx` 快照并补全 PosterKit 必需清单，同时同步镜像 `*MercuryPoster*` 与 `*CollectionsPoster*` 扩展目录。\n"
        "2. `worse_query` POSIX C 级 `Library/Caches` 原生守护：基于底层 `lstat`/`rename`/`mkdir` 栈守卫重构容器授权链路，零 NSFileManager 额外开销。\n"
        "3. Camlo 原生 `SystemPosterStore` 与 `CamloEndpointRanker` / `CamloRemotePreview`：采用 ImageIO 520px+SHA256 缩略图缓存、单次遍历 RoleIndex 批量修剪、"
        "Core Animation 离散关键帧 GIF 预览与 5 分钟 EWMA + HTTP Range 轻量测速选路，全部功能 100% 独立原创重写。"
    ),
    "1.0.9": (
        "1.0.9 重大扩展：\n"
        "1. 新增「官方云端 .tendies 壁纸库」：10 套开箱即用精选包（5 套无缝动态循环 + 5 套时钟景深变身包）独立托管于仓库 wallpapers/，零安装包体积负担；\n"
        "2. 支持 GitHub 直连与大陆镜像 (ghfast.top) 线路一键切换、在线预览缩略图、SHA-256 校验下载、直写锁屏与金库收藏；\n"
        "3. 优化构建管线，自动校验并生成 wallpapers/catalog.json。"
    ),
    "1.0.8": (
        "## Camlo · 开幕 v1.0.8\n"
        "- 「滑动解锁变身工坊」正式支持 **Live Photo 实况照片 / 短视频 × 滑动变身融合**：`锁屏常态` 与 `解锁变身` 槽位均支持直接导入静态图片、Live Photo 或短视频，在保持真机实况连续循环播放（支持乒乓往返 / 单向循环及一键切换实况/静态高清）的同时，上滑依然丝滑触发 6 种 CAML 状态机变身特效；\n"
        "- 实况动态与互动裁剪深度对齐（1:1 匹配实况视频防抖画幅并按调整后取景自动重抽帧），并根据单路 / 双路实况及景深叠加自动调节分辨率与帧数包络（≤52 MB RGBA8），防止 `PosterBoard` 后台内存溢出；\n"
        "- 修复「滑动解锁变身 → 官方精选预设画廊（点选即刻切换）」点击无反应的问题：约束全站 `.scaledToFill()` 缩略图与选图卡的实际命中区域（避免下方选图框越界遮挡上方预设栏），优化嵌套滚动容器按键触控响应并加入预设缩略图内存缓存。"
    ),
    "1.0.7": (
        "## Camlo · 开幕 v1.0.7\n"
        "- 新增沉浸式「锁屏取景裁剪工作台」：支持在「滑动解锁变身」与「动态视频 / 实况锁屏」中对照片、Live Photo 与短视频单指拖拽平移、双指捏合及滑杆缩放，让角落或边缘人物轻松对齐居中；\n"
        "- 内置真实 `09:41` 锁屏时间、手电筒/相机底部参考区及三分线辅助网格（支持一键显隐），所见即所得避开遮挡；\n"
        "- 新增「超界自由挪动」模式：支持缩小至 `0.70x` 及越界上提贴底人物，边缘自动生成柔焦延展填充；并在双图变身工坊支持一键「同步相同裁剪」到另一状态槽。"
    ),
    "1.0.6": (
        "## Camlo · 开幕 v1.0.6\n"
        "- 修复「动态视频 / 实况锁屏」关键帧动画未生效与内存超限问题：改用 Core Animation 原生 `discrete` 离散帧切换并移除越界 `speed` 弹簧动画，限制序列总帧数 ≤40 帧并按总解码内存（≤52 MB RGBA8）自适应分辨率，杜绝 `CollectionsPoster` 扩展被系统 Jetsam 静默终止；\n"
        "- 修复从「文件」及相册选取短视频 / Live Photo 时的沙盒权限、更多视频类型识别与参数调节自动重抽帧；\n"
        "- 注入桌面画廊采用 `19999 -> 10100` 递减排序与原位去重，并自动清理旧版异常视频描述包；\n"
        "- 修正 iOS 26 / iOS 27 锁屏画廊引导文案，提示壁纸位于机型专属栏（系统默认壁纸右侧第 2 张起）或底部「收藏」专区。"
    ),
    "1.0.5": (
        "## Camlo · 开幕 v1.0.5\n"
        "- 修复手动选择高像素照片后点击「立即注销桌面生效 / 一键注销」不触发注销的问题：消除双 WebView 进程竞争与弹窗退场抢占，卸载重型预览层并加入 `WebContent` 守护自动重载，对齐 `Erosion-CN` 单实例顶层全屏承载；\n"
        "- 相册选图引入 `ImageIO` 硬件级视网膜降采样解码，峰值内存降低 90% 以上，杜绝 4800 万像素原图引发的 Jetsam 提前终止。"
    ),
    "1.0.4": (
        "## Camlo · 开幕 v1.0.4\n"
        "- 全新「真流光 · 异形多维粒子引擎」：彻底告别单一圆点，重制 17 张高清矢量多形态精灵与体积光层；\n"
        "- 新增 3 套大尺度体积流光特技：星河流星（斜向曳光流星 + 十字微星）、丁达尔晨光（斜向流动体积光束 + 棱镜金尘）、幻彩流光（S 曲线极光丝绸光带 + 六芒眩光）；\n"
        "- 全面升级原有 5 套粒子造型（双态 3D 落樱 + 柔焦花影、六棱分形冰晶飞雪、电影级水平拉丝十字星芒、破空流火火花 + 棱角余烬、流光尾迹萤火 + 镜头六角光斑），应用内 60fps 仿真预览与真机锁屏同步还原；\n"
        "- 优化 X-Ray 纹理透视暗色背板，全系光效延续熄屏 AOD 零功耗休眠（`birthRate = 0` / `speed = 0`）。"
    ),
    "1.0.3": (
        "## Camlo · 开幕 v1.0.3\n"
        "- 修复从弹窗或桌面点击「立即注销桌面生效」时 WebKit 被遮挡/裁剪导致的偶发不生效问题，独立顶层黑色窗体全屏承载注销重载；\n"
        "- 熄屏低功耗 (Always-On Display) 加固：Sleep 状态下自动暂停粒子发射与视频帧率推进，兼顾灵动变身与整日续航；\n"
        "- 新增 5 套「获奖风光摄影」级 9:16 固定机位变身方案（多洛米蒂日照金山、纳米布光影沙丘、冰岛黑沙玄光、优胜美地熔岩火瀑、富士山破晓云海）并支持画廊分类筛选。"
    ),
    "1.0.2": (
        "## Camlo · 开幕 v1.0.2\n"
        "- 新增内置「软件源订阅与在线更新」中心：支持一键跳转添加至 Feather / SideStore / AltStore / 轻松签 / TrollApps，并内置全能签与国内加速镜像线路切换；\n"
        "- 支持应用内一键检查新版本与更新日志预览；\n"
        "- 包含 iOS 27 (iPhone 18 Pro Max)「收藏」栏持久化白名单、`homescreenConfiguration.plist` 补充配置及一键注销桌面重载。"
    ),
}


def inspect_ipa_bytes(ipa_bytes: bytes, filename: str = "Camlo.ipa") -> dict[str, Any]:
    with zipfile.ZipFile(io.BytesIO(ipa_bytes), "r") as zf:
        plist_names = [
            n for n in zf.namelist()
            if re.match(r"^Payload/[^/]+\.app/Info\.plist$", n)
        ]
        if not plist_names:
            raise ValueError(f"Info.plist not found in {filename}")
        with zf.open(plist_names[0]) as pf:
            info = plistlib.load(pf)
    return {
        "bundle_id": str(info.get("CFBundleIdentifier", "com.kianuni.Camlo")),
        "version": str(info.get("CFBundleShortVersionString", "1.0.4")),
        "build": str(info.get("CFBundleVersion", "1")),
        "min_os": str(info.get("MinimumOSVersion", "26.0")),
        "size": len(ipa_bytes),
        "sha256": hashlib.sha256(ipa_bytes).hexdigest(),
        "filename": filename,
    }


def inspect_ipa(ipa_path: Path) -> dict[str, Any]:
    return inspect_ipa_bytes(ipa_path.read_bytes(), filename=ipa_path.name)


def http_get_bytes(url: str, timeout: int = 30, accept: str = "application/vnd.github+json") -> bytes:
    headers = {
        "User-Agent": "Camlo-AltStore-Sync/1.0",
        "Accept": accept,
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token and ("api.github.com" in url or "github.com" in url):
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def find_latest_ipa() -> Path:
    candidates = [
        Path(p) for p in glob.glob(str(ROOT_DIR / "Camlo_*.ipa"))
        if not p.endswith(".debug.ipa")
    ]
    if not candidates:
        raise FileNotFoundError(f"No Camlo_*.ipa found in {ROOT_DIR}")
    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0]


def load_existing_versions() -> list[dict[str, Any]]:
    for path in (ROOT_DIR / "apps.json", ROOT_DIR / "repo.json"):
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            apps = data.get("apps") or []
            if apps and isinstance(apps[0].get("versions"), list):
                return list(apps[0]["versions"])
        except Exception:
            pass
    return []


def apply_mirror(url: str, use_mirror: bool) -> str:
    if not use_mirror:
        return url
    if url.startswith(MIRROR_PREFIX):
        return url
    return f"{MIRROR_PREFIX}{url}"


def build_payloads(
    repo_slug: str,
    meta: dict[str, Any],
    versions: list[dict[str, Any]],
    use_mirror: bool,
) -> tuple[dict[str, Any], dict[str, Any]]:
    tz_cn = dt.timezone(dt.timedelta(hours=8))
    now_cn = dt.datetime.now(tz_cn).strftime("%Y-%m-%d %H:%M:%S")
    short_cn = now_cn[:16]

    raw_icon = f"https://raw.githubusercontent.com/{repo_slug}/main/PreviewIcon.png"
    icon_url = apply_mirror(raw_icon, use_mirror)

    mapped_versions: list[dict[str, Any]] = []
    for v in versions:
        copied = dict(v)
        copied["downloadURL"] = apply_mirror(str(v["downloadURL"]), use_mirror)
        mapped_versions.append(copied)

    latest = mapped_versions[0]

    altstore_app = {
        "name": "Camlo",
        "bundleIdentifier": meta["bundle_id"],
        "developerName": "Kianuni",
        "subtitle": "开幕 · 零门槛「滑动解锁变身 + 动态锁屏」壁纸工坊",
        "localizedDescription": (
            "Camlo（开幕）是一款零门槛 iOS / iPadOS 原生 Core Animation (.tendies / CAML) 动态与滑动变身锁屏制作工坊。"
            "内置 120Hz 原生 `.ca` 实时交互试穿、陀螺仪 3D 裸眼视差 (ParameterizedCA)、昼夜双生壁纸 (appearanceAware)、智能时钟配色字体与主屏柔焦配套、"
            "6 套内置获奖风光双态预设与 70 套零体积馆藏大师级官方云端壁纸、8 款异形粒子与体积流光特效、AI 主体抠图遮挡时钟、视频/实况抽帧无缝循环与免电脑一键直写 iOS 26 / iOS 27 锁屏画廊。"
        ),
        "iconURL": icon_url,
        "tintColor": ALT_TINT_COLOR,
        "category": "utilities",
        "screenshots": [],
        "versions": mapped_versions,
        "appPermissions": {
            "entitlements": ["com.apple.security.application-groups"],
            "privacy": {
                "NSPhotoLibraryUsageDescription": "用于选择锁屏变身图片、视频或实况照片制作动态壁纸。"
            },
        },
        "version": latest["version"],
        "buildVersion": str(latest.get("buildVersion", "1")),
        "versionDate": latest["date"],
        "versionDescription": latest["localizedDescription"],
        "downloadURL": latest["downloadURL"],
        "size": latest["size"],
    }

    source_suffix = "（国内加速源）" if use_mirror else ""
    altstore_repo = {
        "name": f"Camlo · 开幕 官方软件源{source_suffix}",
        "subtitle": "亮屏即开幕，上滑即变身 — 官方版本自动更新源",
        "description": "支持 Feather、SideStore、AltStore、TrollApps、LiveContainer 一键订阅与覆盖更新 Camlo（开幕）动态锁屏工坊。",
        "identifier": f"{meta['bundle_id']}.repo" + (".cn" if use_mirror else ""),
        "iconURL": icon_url,
        "website": f"https://github.com/{repo_slug}",
        "tintColor": ALT_TINT_COLOR,
        "featuredApps": [meta["bundle_id"]],
        "apps": [altstore_app],
        "news": [],
    }

    try:
        parsed_dt = dt.datetime.fromisoformat(str(latest["date"]).replace("Z", "+00:00"))
        esign_date = parsed_dt.astimezone(tz_cn).strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        esign_date = now_cn

    esign_repo = {
        "name": f"Camlo · 开幕 官方软件源{source_suffix}",
        "identifier": f"{meta['bundle_id']}.esign" + (".cn" if use_mirror else ""),
        "news": {
            "title": "Camlo · 开幕 官方更新源",
            "caption": f"最新版本：v{latest['version']} · 同步于 {short_cn}",
            "date": short_cn,
            "tintColor": ESIGN_TINT_COLOR,
            "isUnlock": 1,
            "key": "",
            "imageURL": "",
            "url": f"https://github.com/{repo_slug}",
            "pay": "",
        },
        "apps": [
            {
                "name": "Camlo · 开幕",
                "bundleIdentifier": meta["bundle_id"],
                "developerName": "Kianuni",
                "version": latest["version"],
                "versionDate": esign_date,
                "downloadURL": latest["downloadURL"],
                "iconURL": icon_url,
                "size": latest["size"],
                "isNeedlock": 0,
                "appType": 1,
                "localizedDescription": latest["localizedDescription"],
            }
        ],
    }

    return altstore_repo, esign_repo


def sync_from_github_releases(repo_slug: str) -> tuple[dict[str, Any], list[dict[str, Any]]] | None:
    existing_by_ver = {
        str(e.get("version")): e
        for e in load_existing_versions()
        if isinstance(e, dict) and e.get("version")
    }
    api_url = f"https://api.github.com/repos/{repo_slug}/releases?per_page=15"
    releases = json.loads(http_get_bytes(api_url).decode("utf-8"))

    versions_out: list[dict[str, Any]] = []
    latest_bundle_id = "com.kianuni.Camlo"

    for rel in releases:
        if rel.get("draft") or rel.get("prerelease"):
            continue
        assets = [a for a in rel.get("assets", []) if str(a.get("name", "")).endswith(".ipa")]
        if not assets:
            continue
        asset = assets[0]
        tag = str(rel.get("tag_name") or "").strip()
        version = tag.lstrip("vV")
        if not version:
            continue

        prev = existing_by_ver.get(version, {})
        digest_raw = str(asset.get("digest") or "")
        sha256 = (
            digest_raw.split("sha256:", 1)[1].lower()
            if digest_raw.startswith("sha256:")
            else prev.get("sha256")
        )
        build_ver = prev.get("buildVersion")
        min_os = prev.get("minOSVersion", "26.0")

        if (len(versions_out) == 0 and not build_ver) or not sha256:
            local_ipa = ROOT_DIR / str(asset["name"])
            if local_ipa.exists() and local_ipa.stat().st_size == int(asset.get("size", 0)):
                ipa_bytes = local_ipa.read_bytes()
            else:
                token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
                if token and asset.get("url"):
                    ipa_bytes = http_get_bytes(
                        str(asset["url"]),
                        timeout=60,
                        accept="application/octet-stream",
                    )
                else:
                    ipa_bytes = http_get_bytes(str(asset["browser_download_url"]), timeout=60)
            parsed = inspect_ipa_bytes(ipa_bytes, filename=str(asset["name"]))
            if not sha256:
                sha256 = parsed["sha256"]
            build_ver = parsed.get("build") or build_ver
            min_os = parsed.get("min_os") or min_os
            if len(versions_out) == 0:
                latest_bundle_id = parsed.get("bundle_id") or latest_bundle_id

        notes = (rel.get("body") or "").strip() or DEFAULT_CHANGELOG_BY_VER.get(
            version, f"Camlo · 开幕 v{version}"
        )
        entry: dict[str, Any] = {
            "version": version,
            "buildVersion": str(build_ver or "1"),
            "date": rel.get("published_at") or rel.get("created_at"),
            "localizedDescription": notes,
            "downloadURL": str(asset["browser_download_url"]),
            "size": int(asset["size"]),
            "sha256": str(sha256),
            "minOSVersion": str(min_os),
        }
        versions_out.append(entry)
        if len(versions_out) >= 10:
            break

    if not versions_out:
        return None

    return {"bundle_id": latest_bundle_id}, versions_out


def write_all_manifests(repo_slug: str, meta: dict[str, Any], versions: list[dict[str, Any]]) -> None:
    repo_direct, esign_direct = build_payloads(repo_slug, meta, versions, use_mirror=False)
    repo_cn, esign_cn = build_payloads(repo_slug, meta, versions, use_mirror=True)

    outputs = [
        (ROOT_DIR / "apps.json", repo_direct),
        (ROOT_DIR / "repo.json", repo_direct),
        (ROOT_DIR / "esign.json", esign_direct),
        (ROOT_DIR / "repo_cn.json", repo_cn),
        (ROOT_DIR / "esign_cn.json", esign_cn),
    ]
    for path, payload in outputs:
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Update Camlo signing-tool repo JSON manifests")
    parser.add_argument("--ipa", help="Path to built IPA (defaults to latest Camlo_*.ipa)")
    parser.add_argument("--repo", default=DEFAULT_REPO_SLUG, help="GitHub owner/repo slug")
    parser.add_argument("--tag", help="Release git tag (defaults to v<version>)")
    parser.add_argument("--download-url", help="Explicit IPA download URL override")
    parser.add_argument("--notes", help="Release notes / changelog text")
    parser.add_argument("--sync-releases", action="store_true", help="Sync manifests directly from GitHub Releases")
    args = parser.parse_args()

    if args.sync_releases:
        synced = sync_from_github_releases(args.repo)
        if synced is None:
            print(f"[!] No published IPA releases found on github.com/{args.repo}; skipping sync.")
            return
        meta, versions = synced
        latest = versions[0]
        write_all_manifests(args.repo, meta, versions)
        print(
            f"[✓] Synced apps.json, repo.json, esign.json, repo_cn.json, esign_cn.json from GitHub Releases "
            f"(latest: v{latest['version']}, build {latest['buildVersion']}, {len(versions)} versions)"
        )
        return

    ipa_path = Path(args.ipa).resolve() if args.ipa else find_latest_ipa()
    meta = inspect_ipa(ipa_path)
    ver = meta["version"]
    tag = args.tag or f"v{ver}"
    dl_url = args.download_url or f"https://github.com/{args.repo}/releases/download/{tag}/{meta['filename']}"
    notes = (args.notes or "").strip() or DEFAULT_CHANGELOG_BY_VER.get(
        ver, f"Camlo · 开幕 v{ver} (Build {meta['build']})"
    )
    now_utc = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    existing = load_existing_versions()
    filtered = [e for e in existing if e.get("version") != ver and e.get("sha256")]
    new_entry = {
        "version": ver,
        "buildVersion": meta["build"],
        "date": now_utc,
        "localizedDescription": notes,
        "downloadURL": dl_url,
        "size": meta["size"],
        "sha256": meta["sha256"],
        "minOSVersion": meta["min_os"],
    }
    versions = [new_entry, *filtered][:10]

    write_all_manifests(args.repo, meta, versions)
    print(f"[✓] Updated apps.json, repo.json, esign.json, repo_cn.json, esign_cn.json for v{ver} (Build {meta['build']}, {meta['size']} bytes)")


if __name__ == "__main__":
    main()
