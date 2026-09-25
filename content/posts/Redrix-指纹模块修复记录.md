---
title: Redrix 指纹模块修复记录
date: 2026-09-25T00:00:00+08:00
slug: 0e27c68
draft: false
author:
  name: tryao
tags: ["linux", "deepin", "Redrix", "指纹识别"]
collections: []
toc: true
math: true
lightgallery: false
---

> 记录日期：2026-09-25  
> 适用机器：HP Elite Dragonfly Chromebook / Google Redrix  
> 固件：MrChromebox `2603.1`  
> 当时系统：Deepin 25，内核 `6.18.48-amd64-desktop-rolling`  
> 驱动方案：实验性 `libfprint crfpmoc`，固定提交 `4df0591`

<!--more-->

## 1. 故障现象与结论

Deepin 设置和 `fprintd` 完全找不到指纹设备，但硬件本身没有消失。Redrix 的指纹模块不是普通 USB 读卡器，而是通过 SPI 连接的 ChromeOS 指纹 MCU（FPMCU）：

- ACPI 设备：`PRP0001:00`
- ACPI 路径：`\_SB_.PCI0.SPI1.CRFP`
- 兼容标识：`google,cros-ec-spi`
- 字符设备：`/dev/cros_fp`
- MCU：`bloonchipper`，STM32F412
- 指纹传感器：FPC1025

本次检查时，内核中的 `cros_ec_spi`、`cros_ec_dev` 和 `cros_ec_chardev` 均已工作，SPI 传输统计有数千次成功通信且没有错误。真正缺少的是 `libfprint` 中尚未正式合并的 `crfpmoc` 用户态驱动。

Deepin 当时已经安装：

```text
fprintd              1.94.5-2deepin1
libfprint-2-2        1:1.94.9-1deepin2
libpam-fprintd       1.94.5-2deepin1
```

因此无需更换内核或刷写 FPMCU 固件，也无需额外修改 PAM；只需让 `fprintd` 使用包含 `crfpmoc` 的定制 `libfprint`。

## 2. 重装后先确认硬件

运行：

```bash
cat /sys/class/dmi/id/product_name
ls -l /dev/cros_fp /sys/class/chromeos/cros_fp
cat /sys/class/chromeos/cros_fp/version
```

预期机器型号是 `Redrix`，并且 `/dev/cros_fp` 与版本文件均存在。本次设备版本为：

```text
RO version: bloonchipper_v2.0.5938-197506c1
RW version: bloonchipper-v2.0.25973-4e2e543
Chip vendor: ST
Chip name: STM32F412
```

如果 `/dev/cros_fp` 不存在，应先解决内核、ACPI 或 `cros_ec` 驱动问题，不要继续安装用户态补丁。

## 3. 安装文件

修复文件与本文一起保存在：

```text
~/Documents/markdown/Redrix-指纹模块修复文件/
├── install-redrix-fingerprint.sh
└── libfprint-crfpmoc-4df0591.tar.gz
```

源码快照信息：

```text
repository=https://github.com/acd407/libfprint
branch=feature/crfpmoc
commit=4df0591
sha256=b2f10a667283be06770937eded02de2817d2855c3950b7f8acf1831b700ce985
```

不要使用已经弃用的 AUR 包 `libfprint-crfpmoc-git`。该包曾在 2026 年 AUR 投毒事件中被接管；应使用本文固定并校验过的源码快照，或自行从可信源码构建。

## 4. 安装修复

进入归档目录并运行：

```bash
cd ~/Documents/markdown/Redrix-指纹模块修复文件
sudo ./install-redrix-fingerprint.sh
```

脚本会：

1. 检查 `/dev/cros_fp` 和 FPMCU 版本接口；
2. 校验源码快照 SHA-256；
3. 通过 Deepin 的包管理器安装 Meson、Ninja、GUsb 等构建依赖；
4. 编译 `crfpmoc` 驱动；
5. 把定制库安装到 `/var/lib/redrix-crfpmoc/lib/libfprint-2.so.2`；
6. 创建 `/etc/systemd/system/fprintd.service.d/90-redrix-crfpmoc.conf`，仅让 `fprintd` 加载定制库；
7. 重启 `fprintd` 并通过 D-Bus 检查设备是否枚举成功；
8. 如果枚举失败，自动删除覆盖配置并恢复系统自带 `libfprint`。

定制库不会覆盖 `/usr/lib` 中的 Deepin 系统库，系统升级与回滚更可控。

### Meson 兼容修正

该源码分支在关闭 introspection 时，测试目录里有一处字典遍历语法错误。脚本只把：

```meson
foreach driver_test: drivers_tests
```

改为合法的：

```meson
foreach driver_test, args: drivers_tests
```

此修正只影响被跳过的测试配置，不修改驱动逻辑。

## 5. 录入与验证

安装成功后，以普通用户身份录入右手食指，不要加 `sudo`：

```bash
fprintd-enroll -f right-index-finger
```

传感器需要五次有效采样，预期最后显示：

```text
Enroll result: enroll-completed
```

立即验证：

```bash
fprintd-verify
```

预期：

```text
Verify result: verify-match (done)
```

然后重启服务，再次验证模板持久化：

```bash
sudo systemctl restart fprintd.service
fprintd-verify
```

本次重启后仍然匹配成功，说明磁盘模板可以重新上传到 FPMCU。

Deepin 统一认证服务已经默认写入 `common-auth`，不需要运行 `pam-auth-update --enable fprintd`。可用以下命令确认 Deepin 能看到指纹：

```bash
busctl --system call \
  org.deepin.dde.Authenticate1 \
  /org/deepin/dde/Authenticate1/Fingerprint \
  org.deepin.dde.Authenticate1.Fingerprint \
  ListFingers s "$USER"
```

本次实际返回：

```text
as 1 "right-index-finger"
```

最终实际测试均通过：

- `fprintd` 录入与验证；
- 重启 `fprintd` 后再次验证；
- Deepin 锁屏指纹解锁；
- 合盖休眠、开盖后指纹解锁；
- 休眠恢复后的触摸板功能。

密码认证始终保留，不要把指纹设为唯一恢复手段。

## 6. 卸载与回滚

```bash
cd ~/Documents/markdown/Redrix-指纹模块修复文件
sudo ./install-redrix-fingerprint.sh --uninstall
```

该命令会删除：

```text
/etc/systemd/system/fprintd.service.d/90-redrix-crfpmoc.conf
/var/lib/redrix-crfpmoc/lib/libfprint-2.so.2
/var/lib/redrix-crfpmoc/SOURCE
```

随后重载 systemd 并让 `fprintd` 恢复使用 Deepin 自带的 `libfprint`。已经录入的模板位于 `/var/lib/fprint`，卸载脚本不会删除它们。

## 7. 安全与维护注意事项

1. `crfpmoc` 仍是未正式合并的实验驱动，不属于当前稳定版 `libfprint`。
2. ChromeOS 会利用 TPM 派生 FPMCU 模板加密所需的上下文；当前 fork 为了让模板在 Linux 重启后仍可使用，改用了固定 seed/context。因此它不具备与 ChromeOS 原生方案相同的模板隔离强度。
3. 指纹适合便利解锁，不应替代强密码、恢复码或独立的 FIDO2 安全密钥。
4. Deepin 或 `fprintd` 大版本升级后，如果服务无法启动，先执行卸载命令恢复系统库，再检查上游 `crfpmoc` 是否已经合并或更新。
5. 如需升级实验驱动，应重新审查源码并固定新的提交与校验值，不要直接跟随滚动分支。

## 8. 浏览器、GitHub 与 Passkey

### 8.1 为什么系统指纹不能直接登录网站

Deepin 锁屏走的是 `libfprint/fprintd`：指纹 MCU 返回“匹配/不匹配”。GitHub 等网站走的是 WebAuthn/Passkey：认证器必须保存或调用私钥，并对网站挑战进行签名。

因此“系统能用指纹解锁”不等于“浏览器能把它当成网站认证器”。当前 Chrome/Edge on Linux 没有成熟、受支持的 `fprintd → WebAuthn` 系统桥接，Redrix 内置指纹不能直接注册成 GitHub Passkey。

### 8.2 Chrome 的推荐用法

Chrome on Linux 支持把 Passkey 存进 Google 密码管理工具，但在 Linux 上通常使用 Google 密码管理工具 PIN 解锁，而不是这块 `fprintd` 指纹。

GitHub 设置步骤：

1. 在 Chrome 中登录需要同步 Passkey 的 Google 账户；
2. 打开 GitHub；
3. 进入 `Settings → Password and authentication`；
4. 在 `Passkeys` 下点击 `Add a passkey`；
5. 选择 Google 密码管理工具；
6. 首次使用时按提示创建 Google 密码管理工具 PIN；
7. 保存 GitHub 恢复码，并保留密码/TOTP 后备方式。

以后登录 GitHub 时选择 `Sign in with a passkey`，再输入 Google 密码管理工具 PIN。

### 8.3 真正使用指纹确认网站登录

目前有两种成熟方案：

1. **手机 Passkey**：在 Android 或 iPhone 上保存 GitHub Passkey。电脑浏览器选择“使用其他设备/手机”，扫描二维码后在手机上用指纹确认。Chrome 与 Edge 均支持这种跨设备认证，通常要求两端开启蓝牙并联网。
2. **带生物识别的 FIDO2 硬件密钥**：购买支持 resident key、user verification 和指纹的安全密钥，在 GitHub 中把它注册为 Passkey。此时使用的是安全密钥自己的指纹传感器，而不是笔记本内置传感器。

普通无指纹的 FIDO2 安全密钥也可以使用 PIN 或触摸确认。

### 8.4 Edge on Linux

Edge 可以使用 WebAuthn，但不像 Chrome 那样提供 Google 密码管理工具。Linux 上建议使用：

- 手机上的 Passkey，通过二维码跨设备认证；
- FIDO2 硬件安全密钥；
- 明确支持 Passkey 的可信密码管理器及其浏览器扩展。

### 8.5 不建议的方案

社区存在把 `fprintd` 包装成虚拟 FIDO2 设备或通过扩展劫持 WebAuthn 的项目，但这类组件会接触网站认证私钥，安全影响远大于普通指纹解锁。在经过独立安全审计和长期维护之前，不应把它用于 GitHub 主账号。

## 9. 参考资料

- Redrix 同型号指纹实测及 AUR 投毒警告：<https://www.cnblogs.com/acd407/articles/19669407>
- `crfpmoc` 上游合并请求：<https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/512>
- libfprint 当前支持设备列表：<https://fprint.freedesktop.org/supported-devices.html>
- ChromiumOS FPMCU 硬件说明：<https://chromium.googlesource.com/chromiumos/platform/ec/+/HEAD/docs/fingerprint/fingerprint.md>
- GitHub Passkey 说明：<https://docs.github.com/en/authentication/authenticating-with-a-passkey/about-passkeys>
- GitHub 添加 Passkey：<https://docs.github.com/en/authentication/authenticating-with-a-passkey/managing-your-passkeys>
- Chrome/Linux Passkey 与 Google 密码管理工具：<https://developers.google.com/identity/passkeys/supported-environments?hl=zh-cn>
