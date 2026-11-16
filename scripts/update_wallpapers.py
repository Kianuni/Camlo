#!/usr/bin/env python3
"""Scan wallpapers/packages/*.tendies, verify zip & CAML integrity, and emit catalog.json & wallpapers/README.md."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import plistlib
import zipfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
WALLPAPERS_DIR = REPO_ROOT / "wallpapers"
PACKAGES_DIR = WALLPAPERS_DIR / "packages"
THUMBS_DIR = WALLPAPERS_DIR / "thumbs"
PREVIEWS_DIR = WALLPAPERS_DIR / "previews"
METADATA_PATH = WALLPAPERS_DIR / "metadata.json"
CATALOG_PATH = WALLPAPERS_DIR / "catalog.json"
README_PATH = WALLPAPERS_DIR / "README.md"
REPO_SLUG = "Kianuni/Camlo"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_tendies_zip(tendies_path: Path, is_duo: bool = False) -> dict[str, object]:
    """Verify .tendies archive has zero Zip-Slip paths, valid descriptor & CAML files."""
    if not zipfile.is_zipfile(tendies_path):
        raise ValueError(f"Not a valid zip archive: {tendies_path}")

    has_descriptor = False
    has_bg_caml = False
    has_floating_caml = False
    has_fg_caml = False
    has_param_caml = False
    has_duo_inner = False
    has_cutout = False
    wallpaper_plist_id = None

    with zipfile.ZipFile(tendies_path, "r") as zf:
        for info in zf.infolist():
            name = info.filename
            if name.startswith("/") or ".." in Path(name).parts:
                raise ValueError(f"Unsafe zip entry path (Zip-Slip risk): {name}")
            if name.startswith("descriptors/") and name.endswith("com.apple.posterkit.provider.descriptor.identifier"):
                has_descriptor = True
            if name.endswith("7400.WWDC_2022_Background-390w-844h@3x~iphone.ca/main.caml"):
                has_bg_caml = True
            if name.endswith("7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca/main.caml"):
                has_floating_caml = True
            if name.endswith("7400.WWDC_2022_Foreground-390w-844h@3x~iphone.ca/main.caml"):
                has_fg_caml = True
            if name.endswith("wallpaper.ca/main.caml"):
                has_param_caml = True
                caml_text = zf.read(info).decode("utf-8", errors="ignore")
                if "<wallpapers" in caml_text and "BACKGROUND_INNER" in caml_text:
                    has_duo_inner = True
            if ("7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca/assets/" in name or "wallpaper.ca/assets/" in name) and (
                "cutout" in Path(name).name and (name.endswith(".png") or name.endswith(".jpg"))
            ):
                has_cutout = True
            if name.endswith("Wallpaper.plist"):
                raw_plist = zf.read(info)
                parsed = plistlib.loads(raw_plist)
                wallpaper_plist_id = parsed.get("identifier")

    if not has_descriptor:
        raise ValueError(f"Missing posterkit descriptor identifier inside {tendies_path.name}")
    if not (has_param_caml or (has_bg_caml and has_floating_caml and has_fg_caml)):
        raise ValueError(
            f"Missing CAML bundles inside {tendies_path.name}: "
            f"param={has_param_caml}, bg={has_bg_caml}, floating={has_floating_caml}, fg={has_fg_caml}"
        )
    if is_duo and not has_duo_inner:
        raise ValueError(f"Duo package missing dual-screen <wallpapers> / BACKGROUND_INNER in {tendies_path.name}")
    if wallpaper_plist_id is None:
        raise ValueError(f"Missing Wallpaper.plist identifier in {tendies_path.name}")

    return {
        "wallpaperIdentifier": wallpaper_plist_id,
        "hasClockDepthAssets": has_cutout,
        "hasDuoDualCanvas": has_duo_inner,
    }


def main() -> None:
    if not METADATA_PATH.exists():
        raise FileNotFoundError(f"Missing metadata file: {METADATA_PATH}")

    meta = json.loads(METADATA_PATH.read_text(encoding="utf-8"))
    raw_packs: list[dict] = meta.get("packs", [])

    catalog_packs: list[dict] = []
    seen_ids: set[str] = set()

    for entry in raw_packs:
        pack_id = entry["id"]
        seen_ids.add(pack_id)
        pkg_file = PACKAGES_DIR / f"{pack_id}.tendies"
        thumb_file = THUMBS_DIR / f"{pack_id}.jpg"
        if not pkg_file.exists():
            raise FileNotFoundError(f"Missing compiled .tendies package: {pkg_file}")
        if not thumb_file.exists():
            raise FileNotFoundError(f"Missing thumbnail image: {thumb_file}")

        inspect_info = verify_tendies_zip(pkg_file, is_duo=(entry.get("category") == "duo"))
        size_bytes = pkg_file.stat().st_size
        digest = sha256_file(pkg_file)
        motion = entry.get("motion") or {}
        preview_webp = PREVIEWS_DIR / f"{pack_id}.webp"
        preview_gif = PREVIEWS_DIR / f"{pack_id}.gif"
        preview_rel = (
            f"wallpapers/previews/{pack_id}.webp"
            if preview_webp.exists()
            else (f"wallpapers/previews/{pack_id}.gif" if preview_gif.exists() else None)
        )

        catalog_packs.append(
            {
                "id": pack_id,
                "posterSeedId": entry.get("posterSeedId") or inspect_info["wallpaperIdentifier"],
                "category": entry["category"],
                "kind": entry["kind"],
                "titleZh": entry["titleZh"],
                "titleEn": entry["titleEn"],
                "subtitleZh": entry["subtitleZh"],
                "subtitleEn": entry["subtitleEn"],
                "badgeZh": entry["badgeZh"],
                "badgeEn": entry["badgeEn"],
                "tagsZh": entry.get("tagsZh", []),
                "tagsEn": entry.get("tagsEn", []),
                "transitionPreset": entry.get("transitionPreset"),
                "particlePreset": entry.get("particlePreset"),
                "supportsClockDepth": bool(entry.get("supportsClockDepth", False)),
                "hasClockDepthAssets": bool(inspect_info["hasClockDepthAssets"]),
                "packagePath": f"wallpapers/packages/{pack_id}.tendies",
                "thumbPath": f"wallpapers/thumbs/{pack_id}.jpg",
                "previewPath": preview_rel,
                "sizeBytes": size_bytes,
                "sha256": digest,
                "fps": motion.get("fps"),
                "frameCount": motion.get("frameCount"),
                "accentHex": entry.get("accentHex", "#6A4DF5"),
            }
        )

    # Also detect any manually dropped extra .tendies not listed in metadata.json
    for extra_pkg in sorted(PACKAGES_DIR.glob("*.tendies")):
        extra_id = extra_pkg.stem
        if extra_id in seen_ids:
            continue
        inspect_info = verify_tendies_zip(extra_pkg)
        thumb_file = THUMBS_DIR / f"{extra_id}.jpg"
        extra_webp = PREVIEWS_DIR / f"{extra_id}.webp"
        extra_gif = PREVIEWS_DIR / f"{extra_id}.gif"
        extra_preview_rel = (
            f"wallpapers/previews/{extra_id}.webp"
            if extra_webp.exists()
            else (f"wallpapers/previews/{extra_id}.gif" if extra_gif.exists() else None)
        )
        catalog_packs.append(
            {
                "id": extra_id,
                "posterSeedId": inspect_info["wallpaperIdentifier"],
                "category": "morph" if inspect_info["hasClockDepthAssets"] else "motion",
                "kind": "imported",
                "titleZh": extra_id.replace("_", " ").title(),
                "titleEn": extra_id.replace("_", " ").title(),
                "subtitleZh": "仓库内置云端 .tendies 扩展包",
                "subtitleEn": "Repository hosted .tendies package",
                "badgeZh": "云端精选",
                "badgeEn": "Cloud Pack",
                "tagsZh": ["OTA 云端包"],
                "tagsEn": ["Cloud OTA"],
                "transitionPreset": None,
                "particlePreset": None,
                "supportsClockDepth": bool(inspect_info["hasClockDepthAssets"]),
                "hasClockDepthAssets": bool(inspect_info["hasClockDepthAssets"]),
                "packagePath": f"wallpapers/packages/{extra_id}.tendies",
                "thumbPath": f"wallpapers/thumbs/{extra_id}.jpg" if thumb_file.exists() else "",
                "previewPath": extra_preview_rel,
                "sizeBytes": extra_pkg.stat().st_size,
                "sha256": sha256_file(extra_pkg),
                "fps": None,
                "frameCount": None,
                "accentHex": "#6A4DF5",
            }
        )

    now_iso = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    catalog = {
        "schemaVersion": 1,
        "generatedAt": now_iso,
        "repo": REPO_SLUG,
        "packCount": len(catalog_packs),
        "packs": catalog_packs,
    }
    CATALOG_PATH.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Emit bilingual wallpapers/README.md table
    total_bytes = sum(p["sizeBytes"] for p in catalog_packs)
    total_mb = total_bytes / (1024 * 1024)
    lines = [
        "# Camlo Cloud `.tendies` Wallpaper Repository / 云端官方壁纸仓库",
        "",
        f"> Total packages / 收录包数: **{len(catalog_packs)}** · Total size (hosted outside IPA) / 仓库总体积（不占 IPA 安装包体积）: **{total_mb:.2f} MB**",
        "",
        "These `.tendies` wallpaper packs are stored outside `Camlo/` so they add **0 bytes** to `Camlo.ipa` while remaining one-tap browsable and downloadable inside the Camlo **Cloud `.tendies` Gallery** (with automatic `ghfast.top` Mainland China mirror & GitHub Direct routing and SHA-256 verification).",
        "",
        "本目录的 `.tendies` 壁纸包独立托管于仓库根目录 `wallpapers/` 下，**不会打入 `Camlo.ipa` 安装包**。在 App 内打开「**官方云端 `.tendies` 壁纸库**」即可支持大陆镜像加速在线预览、SHA-256 校验下载并一键写入锁屏或存入本地金库；也可以直接下载后通过 AirDrop / 文件导入。",
        "",
        "| Preview | Name / 名称 | Category / 分类 | Depth / Features | Size | Direct Download (GitHub / CN Mirror) | SHA-256 (Prefix) |",
        "| :---: | :--- | :---: | :---: | :---: | :--- | :--- |",
    ]

    for p in catalog_packs:
        direct_url = f"https://raw.githubusercontent.com/{REPO_SLUG}/main/{p['packagePath']}"
        cn_url = f"https://ghfast.top/{direct_url}"
        if (PREVIEWS_DIR / f"{p['id']}.webp").exists():
            thumb_rel = f"./previews/{p['id']}.webp"
        elif (PREVIEWS_DIR / f"{p['id']}.gif").exists():
            thumb_rel = f"./previews/{p['id']}.gif"
        else:
            thumb_rel = f"./thumbs/{p['id']}.jpg"
        size_kb = p["sizeBytes"] / 1024
        size_str = f"{size_kb / 1024:.2f} MB" if size_kb >= 1024 else f"{size_kb:.0f} KB"
        is_duo = p.get("category") == "duo"
        thumb_width = "92" if is_duo else "54"
        if is_duo:
            feat = "Duo Inner+Outer · Live 12 FPS" if p.get("kind") == "duoMotion" else "Duo Inner+Outer · 3D CAML"
        elif p["supportsClockDepth"]:
            feat = "Clock Depth · CAML"
        elif p.get("kind") == "morphPair" or p.get("category") == "morph":
            feat = "Slide Morph · CAML"
        else:
            feat = f"{p['fps'] or 14} FPS Seamless"
        lines.append(
            f"| <img src=\"{thumb_rel}\" width=\"{thumb_width}\"/> "
            f"| **{p['titleZh']}**<br/><sub>{p['titleEn']}</sub> "
            f"| `{p['badgeEn']}` "
            f"| {feat} "
            f"| `{size_str}` "
            f"| [GitHub Raw]({direct_url}) · [大陆镜像]({cn_url}) "
            f"| `{p['sha256'][:12]}…` |"
        )

    lines.append("")
    README_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"[+] Updated {CATALOG_PATH} ({len(catalog_packs)} packs, {total_mb:.2f} MB total) and {README_PATH}")


if __name__ == "__main__":
    main()
