<div align="center">
  <br>
  <img src="./PreviewIcon.png" alt="Camlo App Icon" width="150">
  <br>
  <h1>Camlo · 开幕</h1>
  <p><strong>亮屏即开幕，上滑即变身</strong> —— 零门槛「滑动解锁变身 + 动态锁屏」原生 Core Animation (<code>.tendies</code>) 壁纸制作工坊</p>
  <p>支持 iOS / iPadOS 26.x 与 iOS / iPadOS 27.0 – 27.3 beta 1 免电脑一键直写系统锁屏画廊，100% 兼容社区 <code>.tendies</code> 生态互传。</p>
  <p><strong>简体中文</strong> · <a href="./README_EN.md">English Documentation</a> · <a href="https://github.com/Kianuni/Erosion-CN">Erosion-CN 关联工具箱</a></p>
  <img alt="Version" src="https://img.shields.io/badge/Version-v1.2.3-6A4DF5?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/iOS%20%2F%20iPadOS-26.0%20%E2%80%93%2027.3b1-FF6B7A?style=flat-square">
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json"><img alt="Official AltSource" src="https://img.shields.io/badge/%E5%AE%98%E6%96%B9%E6%BA%90-SideStore%20%2F%20AltStore-0EA5E9?style=flat-square"></a>
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/License-GPLv3-blue?style=flat-square"></a>
</div>

---

## 核心能力升级（v1.2.0）

- **120Hz 原生 `.ca` 实时交互预览 (`LiveCAPreviewView`)**：通过纯原创异常安全 Objective-C `CamloCAStageController`（`CAPackage` + `CAStateController`）与 `MotionTiltManager` 120Hz `CADisplayLink`，在金库透视与云端下载页以真实原生 Core Animation 渲染树试穿 `.tendies`（同时兼容 `LayeredAnimation`、`ParameterizedCA` 与 `Still`），支持 `Sleep`/`Locked`/`Unlock` 过渡、手指横向摆动视差、日夜间切换与主屏对照预览；
- **陀螺仪 3D 裸眼视差 (`ParameterizedCA`)**：滑动变身与视频工坊支持开启 3D 裸眼空间视差、调节立体深度（`25%–100%`）并一键 3D 摆动演示；导出包含 `wantsDeviceMotion = true` 与 6 组 `<wallpaperParallaxGroups>` 的 `wallpaper.ca`（背景层自动超采样放大防露边，前景破框与粒子平面反相位移）；
- **昼夜双生壁纸 (`appearanceAware`)**：支持在「滑动解锁变身工坊」开启昼夜双生模式，一键生成 `CoreImage` 月色夜景调色或分别定制夜间双态底图、夜间 Vision 主体破框与夜间粒子，`Wallpaper.plist` 自动声明 `appearanceAware = true` 并打包 `default` / `dark` 双态变体；
- **智能时钟配色字体 & 主屏柔焦配套 (`PosterStyleGenerator`)**：自动采样壁纸顶部 `09:41` 区域亮度与全画幅主题色，提供 6 款 `PosterKit` 字体（`Soft` / `Default` / `Rounded` / `NewYork` / `Stencil` / `Rail`）、8 种对比/取色策略及 4 种主屏配套方案（原生柔焦虚化 / 清晰直通 / 同色渐变 / 暗调纯色），通过二进制 `NSKeyedArchiver` 直接写入 `titleStyleConfiguration.plist`、`homescreenConfiguration.plist` 与 `RuntimeSnapshotMetadata`。

## 四大核心能力

### 1. 滑动解锁变身工坊 (`Slide-to-Morph Studio`)
告别手写千行 XML / CAML 代码与繁琐的电脑端连线工具。只需从相册选 2～3 张图片，即可自动生成符合苹果 `LayerKit` 三态不变式（`Sleep` / `Locked` / `Unlock`）的全屏视网膜动态锁屏：
- **6 款高表现力变身预设曲线**：
  - **上滑揭幕 (`Curtain Rise`)**：锁屏帷幕随手指上滑顺势掀起，露出底层觉醒形态；
  - **破屏觉醒 (`Burst Awaken`)**：解锁瞬间高张力弹簧缩放破屏而出；
  - **丝滑叠化 (`Silk Crossfade`)**：电影级呼吸感柔光叠化，百搭昼夜风景与人物换装；
  - **圣光瞬变 (`Flash Morph`)**：一道柔白高光脉冲闪过，掩护零割裂形态切换；
  - **光栅幻卡 (`Holo Flip`)**：仿立体光栅闪卡 3D 微倾与横向视差翻转；
  - **暗夜睁眼 (`AOD Gaze`)**：熄屏常显微光剪影 → 亮屏完全展开 → 上滑二次进化。
- **无级物理调参**：自由调节 `0.35s – 1.40s` 过渡时长与 `0% – 100%` 弹簧回弹张力，并支持单独指定「熄屏常显 (AOD)」专属画面。
- **内置 11 套官方精选像素级对齐高清预设（`PresetGallery.bundle`）**：包含 **6 套获奖摄影级自然风光**（多洛米蒂日照金山、纳米布光影沙丘、冰岛黑沙玄光、优胜美地熔岩火瀑、富士山破晓云海、凛冬雪峰极光）与 **5 套潮流创意主题**（星穹剑姬、寒江孤月、暗夜超跑、苍穹机甲、柴犬团子），附带预提取 8-bit 前景/天际线破框蒙版，零选图直接上锁屏！
- **云端 `.tendies` 壁纸广场（4 大频道 330+ 套 · [`wallpapers/`](./wallpapers/README.md) 零体积 OTA）**：支持 **Camlo 官方（10 套动态与景深包，SHA-256 校验）** + **CAPlayground（183+ 动画库）** + **Nugget 创意（111+ 社区作品）** + **Apple 原厂机型库（32+ 原生包）**，采用 Camlo 原生 `CamloEndpointRanker`（5 分钟 host EWMA 延迟缓存 + `Range: bytes=0-1` 轻量探测）、`CamloRemotePreview` Core Animation 离散关键帧 GIF 预览，并已彻底修复外源壁纸在 iOS 26/27（含 iPhone 18 Pro Max）跨 `versions/0` / `.wallpaperCollection` 打包与 `productTypes` 限制导致的未显示问题；
- **系统已装锁屏视觉管理与通用 `.tendies` 引擎**：基于 100% Camlo 原生 `SystemPosterStore` 与 ImageIO 磁盘缩略图缓存预览已安装的锁屏模板与配置、按 `RoleIndex` 批量安全清理并自动追踪中文名称；兼容单遍流式解压、多扩展（含 `*CollectionsPoster*` / `*MercuryPoster*`）镜像注入，以及纯 POSIX C `worse_query` App Group `Library/Caches` 原生守卫；
- **实况动态 × 滑动变身融合 & 交互式锁屏取景裁剪**：支持在「锁屏常态 / 解锁变身」槽位直接导入 **Live Photo 实况照片** 或短视频实现边动边变身（自适应 Jetsam 安全内存预算）；内置真实 `09:41` 时钟与底栏避让预览的交互式拖拽/双指缩放裁剪工作台（支持「超界自由挪动」柔焦延展填充与双槽位一键同步裁剪）。

### 2. AI 神经网络抠图破框 + 硬件粒子流光 (`Depth Cutout & Particles`)
充分利用苹果 `WallpaperKit.CollectionsPoster` 的三层 `LayeredAnimation` 原生渲染管线：
- **AI 主体破框遮挡时钟 (`Floating.ca`)**：端侧调用 Apple Neural Engine (`VNGenerateForegroundInstanceMaskRequest`) 一键分离人物、角色或萌宠前景，自动编译入位于**锁屏时间上层**的 `Floating.ca` 包，在动态变身的同时实现**真实遮挡 `09:41` 时钟下半部**的立体破框景深！
- **8 款多维异形粒子与体积流光 (`Foreground.ca`)**：彻底告别单调圆点，基于 CoreGraphics 多形态矢量精灵 + 硬件加速 `CAEmitterLayer` / `plusL` 体积光层打造——涵盖 **星河流星（斜向曳光流星 + 十字微星）**、**丁达尔晨光（斜向流动体积光束 + 棱镜金尘）**、**幻彩流光（S 曲线极光丝绸光带 + 六芒眩光）**、**落樱缤纷（正侧双态手绘樱瓣 3D 翻飞 + 前景虚化花影）**、**冰晶飞雪（六棱分形雪花 + 星形冰晶双层视差）**、**十字星芒（电影拉丝四芒/八芒星针）**、**流火飞星（破空火线 + 棱角余烬）** 与 **森系流萤（流光尾迹 + 镜头六角光斑）**；进入熄屏常显 (`Sleep`) 自动将 `birthRate` 与动画 `speed` 归零休眠，零额外待机耗电。

### 3. 动态视频 / 实况照片锁屏工坊 (`Video & Live Photo Studio`)
- 支持直接从系统相册选取 **短视频 (`MP4` / `MOV`)**、**实况照片 (`Live Photo`)**，或从「文件」App 导入视频素材；
- 自动 9:16 视网膜居中裁切，严格控制帧预算（`12 / 18 / 24 FPS`、最高 150 帧包络）以彻底规避 `PosterBoard` 扩展 Jetsam 内存强杀导致壁纸变黑/静态；
- 支持 **无缝乒乓往返 (`Ping-Pong`)**（彻底消除首尾跳帧割裂感）与 **标准单向循环 (`Standard Loop`)**，并可叠加解锁微推镜头与粒子流光。

### 4. 实时触控仿真预览器 + `.tendies` 壁纸包金库 (`Simulator & Vault`)
- **60/120Hz 交互式锁屏仿真器**：工坊顶部内嵌 1:1 层级还原的 iPhone 锁屏预览窗，既可点击切换 `熄屏 / 锁屏 / 解锁`，也可**直接用手指在预览屏上滑跟手搓动变身进度**，即时感受 Taptic 震动反馈与时钟遮挡关系；
- **`.tendies` 全兼容金库与 X-Ray 透视器**：
  - 完美支持导入、透视检查（解析包内画布尺寸、`CALayer` 数量、`LKState` 状态机、转场数与纹理贴图）及一键导出标准 `.tendies` 壁纸包（100% 兼容 `CAPlayground`、`Nugget` 与 `Erosion-CN`）；
  - 针对外部导入包内置 **Zip-Slip 路径穿越防御**与 **多点位描述符 ID 同步重随机修复**（同时对齐 `descriptor.identifier` 字符串、`userInfo` 字符串以及 `Wallpaper.plist` 顶层与嵌套整型 ID，彻底解决多张动态壁纸相互覆盖冲突问题）；
  - 写入系统容器时自动附带 `.camlo_origin` 安全溯源标记，支持**「无损刷新 GalleryCache 画廊缓存」**与**「仅清理开幕写入的壁纸（不伤系统与其他壁纸）」**。

---

## 系统兼容性

- **iOS / iPadOS 26.0 – 26.7.2**（完整支持免电脑直写）
- **iOS / iPadOS 27.0 – 27.2.1 / 27.3 beta 1**（完整支持免电脑直写）
  > 💡 由于锁屏管理进程 `com.apple.PosterBoard` 属于标准应用数据容器（`/var/mobile/Containers/Data/Application/<UUID>`），基于 `CSStore2` + `worse_query` 的沙盒桥接在 **iOS 26 与 iOS 27 全系**均可稳定免电脑直写！

---

## 安装与签名要求

> [!WARNING]
> 免电脑一键直写锁屏画廊依赖至少一个有效的 `App Group` 容器权限。请使用支持保留或注入 App Group 的个人 Apple ID 自签工具（如 **SideStore / AltStore / Feather / Sideloadly / Impactor / iLoader**）或带 App Group 权限的开发者证书签名安装（应用会在运行时自动探测重签后的 `App Group`；无 `App Group` 环境下仍可 100% 正常创作并导出标准 `.tendies` 壁纸包）。

### 方式一：订阅官方自动更新源（推荐 · 支持一键升级）

在 iPhone / iPad 浏览器中点击下方按钮即可一键添加官方软件源（每次新 Release 发布自动同步，内含 `App Group` 权限声明与 `SHA-256` 校验）：

<p>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json&r=sidestore"><img alt="Add to SideStore" src="https://img.shields.io/badge/%E4%B8%80%E9%94%AE%E6%B7%BB%E5%8A%A0%E8%87%B3-SideStore-7C3AED?style=for-the-badge"></a>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json&r=altstore"><img alt="Add to AltStore" src="https://img.shields.io/badge/%E4%B8%80%E9%94%AE%E6%B7%BB%E5%8A%A0%E8%87%B3-AltStore-0284C7?style=for-the-badge"></a>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json&r=feather"><img alt="Add to Feather" src="https://img.shields.io/badge/%E4%B8%80%E9%94%AE%E6%B7%BB%E5%8A%A0%E8%87%B3-Feather-EC4899?style=for-the-badge"></a>
  <a href="https://altdirect.app/?url=https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json"><img alt="More Clients" src="https://img.shields.io/badge/%E6%9B%B4%E5%A4%9A%E7%AD%BE%E5%90%8D%E5%B7%A5%E5%85%B7-LiveContainer%20%2F%20%E5%A4%8D%E5%88%B6-475569?style=for-the-badge"></a>
</p>

手动添加官方源地址（兼容 SideStore / AltStore / Feather / LiveContainer / ESign）：
```text
https://raw.githubusercontent.com/Kianuni/Camlo/main/apps.json
```

### 方式二：手动下载 IPA 签名安装

1. 前往 [Releases 页面](https://github.com/Kianuni/Camlo/releases/latest) 下载最新的 `Camlo_v1.2.3_Bilingual.ipa`。
2. 使用上述签名工具安装至设备；安装后也可在 App 内 **「设备与设置 → 软件源订阅与在线更新」** 切换国内加速镜像或一键检查更新。

---

## 本地构建

环境要求：macOS + Xcode 26 / 27+

```bash
chmod +x ./ipabuild.sh
./ipabuild.sh
```

编译完成后将在项目根目录生成 `Camlo_v1.2.3_Bilingual.ipa`，并自动同步刷新软件源清单（`apps.json` / `repo.json` / `esign.json` / `repo_cn.json` / `esign_cn.json`）。

---

## 三步上锁屏指南（iOS 26 / iOS 27）

1. 打开 **Camlo · 开幕**，进入「滑动解锁变身工坊」或「动态视频工坊」（也可直接点选首页内置的 **11 套高清双态预设画廊**），点击 **「一键应用到锁屏」**，随后在弹窗点击 **「立即注销桌面生效」**（或打开 `PosterBoard` 后在后台多任务界面将其上滑关闭）以刷新系统缓存；
2. 锁屏或下拉通知中心，**长按锁屏空白处**进入编辑模式，点击右下角蓝色 **`+`** 号；
3. **不要点顶部的「照片」**！请直接查看系统画廊里的 **「专为你的 iPhone 设计的墙纸」** 横排（紧挨系统默认粉色壁纸右侧第 2 张起），老机型或部分系统版本则一直向下滑动到底部的 **「收藏」（英文系统为 `Collections`）** 横向专区——点击「添加」即可享受亮屏开幕、上滑变身。

---

## 关联项目

同作者维护的 iOS / iPadOS 26–27 配套开源工具矩阵：

- **[Erosion-CN](https://github.com/Kianuni/Erosion-CN)**：基于 `worse_query` 的 iOS / iPadOS 系统配置、跨容器管理与防白苹果安全加固版 `MobileGestalt` 研究工具箱（中英双语，支持国行 Apple 智能与海外 eSIM 解锁、应用存档备份、缓存清理与锁屏自定义）；
- **[AppleFlow](https://github.com/Kianuni/AppleFlow)**：零 MitM 的 Apple Intelligence、PCC 相册「高质量消除」与中文 Siri 极简分流方案及在线配置体检工作台；
- **[WQGuard](https://github.com/Kianuni/WQGuard)**：面向 iOS 26.2+ / 27.x 的零依赖、100% 物理只读沙盒逃逸静态审计与固件 CVE 防护系统。

---

## 开源许可与致谢

本项目基于 **[GNU General Public License v3.0 (GPLv3)](./LICENSE)** 开源发布，v1.1.0+ 核心机制均为 **100% Camlo 原生独立实现**。特此向以下外部开源项目与研究者致谢：
- **[frs0n/placard](https://github.com/frs0n/placard)**：提供 App Group 缓存守卫、已装锁屏管理、多扩展识别与社区壁纸聚合等**产品功能与交互灵感**；
- **[jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion)**（by `jailbreakdotparty`、`lunginspector`、`neonmodder123`、`skadz108`）：提供 `CSStore2` 容器路径解析、`PosterBoard` 锁屏画廊注入与免越狱注销参考；
- **[forcequitOS/worse_query](https://github.com/forcequitOS/worse_query)**（by `forcequit` & `0xjohnnydev`）：提供 iOS 应用沙盒跨容器读写核心研究；
- **[CAPlayground](https://github.com/CAPlayground/CAPlayground)**、**[CAPlayground/wallpapers](https://github.com/CAPlayground/wallpapers)**、**[Nugget](https://github.com/leminlimez/Nugget)** & **[SerStars/nugget-wallpapers](https://github.com/SerStars/nugget-wallpapers)**：推动 Core Animation `CAML` / `.tendies` 开放格式与开源社区壁纸库；
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)**（by `Thomas Zoechling`）：高性能 Swift 压缩与归档支持。
