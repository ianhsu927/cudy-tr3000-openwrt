# Cudy TR3000 v1（128MB）OpenWrt Actions

仅适用于 **Cudy TR3000 v1、原厂 128MB 闪存、原厂分区布局**。设备配置为 `mediatek/filogic` 下的 `cudy_tr3000-v1`。256MB、`ubootmod` 和 TR3600 使用不同的镜像，不能混用。

参考 [ianhsu927/cudy-tr3600-openwrt](https://github.com/ianhsu927/cudy-tr3600-openwrt) 的 `41596930acb13b0f259203de12aa09f50f10eed3` 编译流程。TR3000 已由 OpenWrt `openwrt-25.12` 原生支持，因此直接构建稳定分支，不应用 TR3600 的设备适配、风扇、LED、MAC 和无线默认配置补丁。

## 固件内容

- 中文 LuCI 与 HTTPS 管理。
- Argon 主题、Argon 配置插件，以及 Bootstrap 备用主题。
- OpenClash 和其官方分发的 ARM64 Meta/Mihomo 内核，下载时记录源码提交、架构及 SHA256。
- SQM、CAKE、IFB、sched-core 和 nlbwmon 流量统计，均随同一份内核编译。
- 安卓 USB 共享驱动（RNDIS、CDC Ethernet、CDC NCM）和 iPhone USB 共享驱动（ipheth、usbmuxd、libimobiledevice）。
- 通用 USB 热点管理插件 `luci-app-usb-tethering` 和断网诊断插件 `luci-app-net-doctor`，沿用参考项目的固定提交。

已移除 TR3600 硬件管家 `luci-app-tr3600-manager`、其风扇/灯光控制服务，以及 TR3600 专用补丁和无线配置测试。TR3000 使用上游无线初始配置；首次使用请通过有线连接设置 Wi-Fi。

## 自动构建与下载

配置或脚本推送至 `main` 自动编译；每周六北京时间 **04:00** 定时编译；也可打开 [Actions](https://github.com/ianhsu927/cudy-tr3000-openwrt/actions) → **Build Cudy TR3000 v1 OpenWrt** → **Run workflow** 手动运行。

成功后下载 `cudy-tr3000-v1-128mb-运行编号` Artifact，保留 30 天，其中包括：

- `*-cudy_tr3000-v1-sysupgrade.bin`，以及上游生成的 initramfs 镜像。
- `sha256sums`、该机型软件包清单、`profiles.json`。
- `build.config`、`sources.txt`、`custom-plugin-sources.txt`、`openclash-core.txt` 和编译日志。
- `matching-packages.tar.gz`：本次实际编译的软件包，包括与固件内核 ABI 匹配的模块；并非全部可选包。

准备阶段检查最终配置只选择 `cudy_tr3000-v1`；收集阶段检查机型 metadata、必选软件包、无线驱动及 TR3600 插件是否被排除。失败的 Artifact 可能只有诊断文件，必须以对应 Action 的成功状态为准。完整固件是否可用仍需真机验证。

稳定分支、OpenClash 和 Argon 跟随上游更新，实际提交写入 `sources.txt`。这是自动更新构建，不是完全锁定的可复现构建。两个自研插件固定为：

| 插件 | 固定提交 |
| --- | --- |
| USB 热点管理 | `a752832a17261a6ccf2474defa6b3e5d7848427b` |
| 断网诊断助手 | `be42a485885ae112759702556d9961228559103c` |

## 使用

OpenClash 已带 ARM64 Meta 内核，首次使用导入自己的订阅或配置并启动；仓库不包含订阅、账号或密钥。

USB 热点通过 **网络 → USB 热点** 管理。安卓启用 USB 网络共享；iPhone 开启个人热点并信任设备。USB-A 接口连接手机，USB-C 用于供电。路由优先级可在插件中调整，不预设多 WAN 自动故障切换。

SQM 需设置实际 WAN 接口及上下行速率；启用时关闭流量卸载并实测性能。后续补装内核模块应使用与当前固件同一构建的归档，避免强制安装滚动仓库中的不匹配 kmod。

## 刷机

首次从原厂迁移请先阅读 [Cudy TR3000 1.0 下载中心](https://www.cudy.com/zh-cn/pages/download-center/tr3000-1-0) 和 [OpenWrt TR3000 设备说明](https://openwrt.org/toh/cudy/tr3000)。不要把 sysupgrade 镜像直接当作原厂升级镜像，也不要使用 256MB 或 `ubootmod` 的教程/镜像刷入原厂布局。

已经使用兼容 OpenWrt 时，按设备说明使用 sysupgrade，并先核对硬件版本、分区布局、备份及 SHA256。此仓库的 Actions 检查不能代替实际刷机验收。

## 来源

- [OpenWrt 25.12 TR3000 设备配置](https://github.com/openwrt/openwrt/blob/openwrt-25.12/target/linux/mediatek/image/filogic.mk)
- [OpenClash](https://github.com/vernesong/OpenClash)
- [Argon](https://github.com/jerrykuku/luci-theme-argon) / [Argon 配置](https://github.com/jerrykuku/luci-app-argon-config)
- [USB 热点管理](https://github.com/ianhsu927/luci-app-usb-tethering)
- [断网诊断助手](https://github.com/ianhsu927/luci-app-net-doctor)

上游补丁、软件及二进制保留各自的许可证与版权。
