# Camlo · 开幕 — 详细功能与技术文档

<p>
  <a href="../README.md">← 返回首页简介</a> ·
  <a href="./FEATURES_EN.md">English Detailed Guide</a> ·
  <a href="../wallpapers/README.md">🎨 官方 70 套云端壁纸目录</a>
</p>

---

## 核心技术能力概览

- **iPhone Duo 原生内外双屏渲染引擎 (`Inner` + `Outer` `<wallpapers>`)**：单包编译写入统一 `WallpaperKit` `ParameterizedCA`（`Marble` / `requiresLandscapeScaling = true`），内嵌外屏 `466×678` pt（`BACKGROUND`/`FLOATING`）与展开内屏 `951×669` pt 横屏书本画布（`BACKGROUND_INNER`/`FLOATING_INNER`）两套独立图层树、陀螺仪视差组与状态属性组；支持工坊双屏选图裁剪、双面 AI 抠图破框与 120Hz 实时交互切换预览；
- **120Hz 原生 `.ca` 实时交互预览 (`LiveCAPreviewView`)**：通过纯原创异常安全 Objective-C `CamloCAStageController`（`CAPackage` + `CAStateController`）与 `MotionTiltManager` 120Hz `CADisplayLink`，在金库透视与云端下载页以真实原生 Core Animation 渲染树试穿 `.tendies`（同时兼容 `LayeredAnimation`、`ParameterizedCA` 与 `Still`），支持 `Sleep`/`Locked`/`Unlock` 过渡、iPhone Duo 外屏/展开内屏即时切换、手指横向摆动视差、日夜间切换与主屏对照预览；
- **陀螺仪 3D 裸眼视差 (`ParameterizedCA`)**：滑动变身与视频工坊支持开启 3D 裸眼空间视差、调节立体深度（`25%–100%`）并一键 3D 摆动演示；导出包含 `wantsDeviceMotion = true`、6 组 `<wallpaperParallaxGroups>` 及完整 `<wallpaperPropertyGroups>`（`v_sleep`/`v_lock`/`v_home` 解锁变身与前景破框三态插值）的 `wallpaper.ca`（背景层自动超采样放大防露边，前景破框与粒子平面反相位移）；
- **昼夜双生壁纸 (`appearanceAware`)**：支持在「滑动解锁变身工坊」开启昼夜双生模式，一键生成 `CoreImage` 月色夜景调色或分别定制夜间双态底图、夜间 Vision 主体破框与夜间粒子，`Wallpaper.plist` 自动声明 `appearanceAware = true` 并打包 `default` / `dark` 双态变体；
- **智能时钟配色字体 & 主屏柔焦配套 (`PosterStyleGenerator`)**：自动采样壁纸顶部 `09:41` 区域亮度与全画幅主题色，提供 6 款 `PosterKit` 字体（`Soft` / `Default` / `Rounded` / `NewYork` / `Stencil` / `Rail`）、8 种对比/取色策略及 4 种主屏配套方案（原生柔焦虚化 / 清晰直通 / 同色渐变 / 暗调纯色），通过二进制 `NSKeyedArchiver` 直接写入 `titleStyleConfiguration.plist`、`homescreenConfiguration.plist` 与 `RuntimeSnapshotMetadata`；
- **iOS 26 / iOS 27 Liquid Glass 原生交互界面**：全站采用原生分组圆角卡片与单层液态玻璃（Liquid Glass）导航状态胶囊，深浅色模式自适应融合。

---

## 四大核心模块详解

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
- **内置 6 套获奖风光像素级对齐高清预设 (`PresetGallery.bundle`)**：精选 **6 套获奖摄影级自然风光**（多洛米蒂日照金山、纳米布光影沙丘、冰岛黑沙玄光、优胜美地熔岩火瀑、富士山破晓云海、凛冬雪峰极光），附带预提取 8-bit 天际线/山峰破框蒙版，零选图直接上锁屏（保持极限 ~9 MB 超轻量安装包，70 套官方云端壁纸全量托管于云端仓库）。
- **云端 `.tendies` 壁纸广场（4 大频道 395+ 套 · [`wallpapers/`](../wallpapers/README.md) 零体积 OTA）**：支持 **Camlo 官方（70 套官方精选：含 10 套真机 `ParameterizedCA` 3D 陀螺仪 + 景深挡时间原创「次元 3D」二次元壁纸、10 套 iPhone Duo 内外双屏专享壁纸与 50 套馆藏殿堂级古典油画、外光印象派、东方宋画敦煌、宇宙极境，全量托管于仓库 `wallpapers/`，零安装包体积占用，支持动画 WebP 实时预览、`120Hz 原生交互试穿` 与 SHA-256 校验）** + **CAPlayground（183+ 动画库）** + **Nugget 创意（111+ 社区作品）** + **Apple 原厂机型库（32+ 原生包）**，采用 Camlo 原生 `CamloEndpointRanker`（5 分钟 host EWMA 延迟缓存 + `Range: bytes=0-1` 轻量探测）、`CamloRemotePreview` Core Animation 离散关键帧动画预览，并彻底修复 iOS `/var -> /private/var` 解压路径规范化及外源壁纸跨 `versions/0` / `.wallpaperCollection` 打包兼容。
- **系统已装锁屏视觉管理与通用 `.tendies` 引擎**：基于 100% Camlo 原生 `SystemPosterStore` 与 ImageIO 磁盘缩略图缓存预览已安装的锁屏模板与配置、按 `RoleIndex` 批量安全清理并自动追踪中文名称；兼容单遍流式解压、多扩展（含 `*CollectionsPoster*` / `*MercuryPoster*`）镜像注入，以及纯 POSIX C `worse_query` App Group `Library/Caches` 原生守卫。
- **实况动态 × 滑动变身融合 & 交互式锁屏取景裁剪**：支持在「锁屏常态 / 解锁变身」槽位直接导入 **Live Photo 实况照片** 或短视频实现边动边变身（自适应 Jetsam 安全内存预算）；内置真实 `09:41` 时钟与底栏避让预览的交互式拖拽/双指缩放裁剪工作台（支持「超界自由挪动」柔焦延展填充与双槽位一键同步裁剪）。

### 2. AI 神经网络抠图破框 + 硬件粒子流光 (`Depth Cutout & Particles`)

充分利用苹果 `WallpaperKit.CollectionsPoster` 的三层 `LayeredAnimation` 原生渲染管线：

- **AI 主体破框遮挡时钟 (`Floating.ca`)**：端侧调用 Apple Neural Engine (`VNGenerateForegroundInstanceMaskRequest`) 一键分离人物、角色或萌宠前景，自动编译入位于**锁屏时间上层**的 `Floating.ca` 包，在动态变身的同时实现**真实遮挡 `09:41` 时钟下半部**的立体破框景深。
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

## 系统兼容性与直写原理

- **iOS / iPadOS 26.0 – 26.7.2**（完整支持免电脑直写）
- **iOS / iPadOS 27.0 – 27.2.1 / 27.3 beta 1**（完整支持免电脑直写）

> 💡 由于锁屏管理进程 `com.apple.PosterBoard` 属于标准应用数据容器（`/var/mobile/Containers/Data/Application/<UUID>`），基于 `CSStore2` + `worse_query` 的跨容器沙盒桥接在 **iOS 26 与 iOS 27 全系**均可稳定免电脑直写（需由 SideStore / AltStore / Feather / 个人或企业证书等签名工具保留至少一个有效 `App Group` 权限；无 `App Group` 环境下仍可 100% 正常创作并导出标准 `.tendies` 壁纸包）。

---

## 详细上锁屏步骤与常见排障

1. 打开 **Camlo · 开幕**，挑选云端壁纸、内置 **6 套获奖风光预设** 或用相册素材创作完成后，点击 **「一键应用到锁屏」**；
2. 根据弹窗提示点击 **「立即注销桌面生效」**（或点击「唤起 PosterBoard」后在后台多任务上滑划掉 `PosterBoard`）以刷新系统缓存；
3. 锁屏或下拉通知中心，**长按锁屏空白处**进入编辑模式，点击右下角蓝色 **`+`** 号；
4. **不要点顶部的「照片」**！请直接查看系统画廊里的 **「专为你的 iPhone 设计的墙纸」** 横排（紧挨系统默认粉色壁纸右侧第 2 张起），老机型或部分系统版本则向下滑动到底部的 **「收藏」（英文系统为 `Collections`）** 横向专区——点击「添加」即可生效。

---

## 本地从源码构建

环境要求：macOS + Xcode 26 / 27+

```bash
chmod +x ./ipabuild.sh
./ipabuild.sh
```

编译完成后将在项目根目录生成 `Camlo_v1.3.0_Bilingual.ipa`，并自动同步刷新软件源清单（[`apps.json`](../apps.json) / [`repo.json`](../repo.json) / [`esign.json`](../esign.json) / [`repo_cn.json`](../repo_cn.json) / [`esign_cn.json`](../esign_cn.json)）。

---

## 关联项目

同作者维护的 iOS / iPadOS 26–27 配套开源工具矩阵：

- **[Erosion-CN](https://github.com/Kianuni/Erosion-CN)**：基于 `worse_query` 的 iOS / iPadOS 系统配置、跨容器管理与防白苹果安全加固版 `MobileGestalt` 研究工具箱（中英双语，支持国行 Apple 智能与海外 eSIM 解锁、应用存档备份、缓存清理与锁屏自定义）；
- **[AppleFlow](https://github.com/Kianuni/AppleFlow)**：零 MitM 的 Apple Intelligence、PCC 相册「高质量消除」与中文 Siri 极简分流方案及在线配置体检工作台；
- **[WQGuard](https://github.com/Kianuni/WQGuard)**：面向 iOS 26.2+ / 27.x 的零依赖、100% 物理只读沙盒逃逸静态审计与固件 CVE 防护系统。

---

## 开源许可与致谢

本项目基于 **[GNU General Public License v3.0 (GPLv3)](../LICENSE)** 开源发布，v1.1.0+ 核心机制均为 **100% Camlo 原生独立实现**。特此向以下外部开源项目与研究者致谢：

- **[frs0n/placard](https://github.com/frs0n/placard)**：提供 App Group 缓存守卫、已装锁屏管理、多扩展识别与社区壁纸聚合等**产品功能与交互灵感**；
- **[jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion)**（by `jailbreakdotparty`、`lunginspector`、`neonmodder123`、`skadz108`）：提供 `CSStore2` 容器路径解析、`PosterBoard` 锁屏画廊注入与免越狱注销参考；
- **[forcequitOS/worse_query](https://github.com/forcequitOS/worse_query)**（by `forcequit` & `0xjohnnydev`）：提供 iOS 应用沙盒跨容器读写核心研究；
- **[CAPlayground](https://github.com/CAPlayground/CAPlayground)**、**[CAPlayground/wallpapers](https://github.com/CAPlayground/wallpapers)**、**[Nugget](https://github.com/leminlimez/Nugget)** & **[SerStars/nugget-wallpapers](https://github.com/SerStars/nugget-wallpapers)**：推动 Core Animation `CAML` / `.tendies` 开放格式与开源社区壁纸库；
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)**（by `Thomas Zoechling`）：高性能 Swift 压缩与归档支持。
