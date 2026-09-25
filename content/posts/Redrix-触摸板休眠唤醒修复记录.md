# Redrix 触摸板休眠唤醒修复记录

> 记录日期：2026-09-25  
> 适用机器：HP Elite Dragonfly Chromebook / Google Redrix  
> 当时系统：Deepin 25，X11，内核 `6.18.48-amd64-desktop-rolling`  
> 触摸板：`ELAN2703:00 04F3:323B Touchpad`  
> 触摸屏：`ELAN2513:00 04F3:2F71`（不要误操作）

## 1. 故障现象

合盖休眠后再开盖，触摸板偶发完全失灵。系统仍能枚举触摸板，但触摸板与其 I²C 控制器的中断停止增长，说明不是桌面设置关闭了触摸板，而是 `ELAN2703` 在恢复后没有正确重新初始化。

第一次加入“恢复后重新绑定驱动”的钩子后，触摸板可以恢复，但出现合盖后几秒钟便听到恢复提示音的现象。进一步确认这不是“成功休眠后立即唤醒”，而是内核根本没有进入休眠：

```text
/sys/power/suspend_stats/success = 0
/sys/power/suspend_stats/fail = 4
last_failed_errno = -16 (EBUSY)
last_failed_step = suspend
```

ACPI 同时显示触摸板 `H015 / i2c-ELAN2703:00` 是启用状态的唤醒源。触摸板的待处理中断会中止休眠。因此最终方案包括两部分：

1. 禁止 `ELAN2703` 唤醒系统；开盖仍由 `LID0` 唤醒。
2. 系统恢复后，只重新绑定 `ELAN2703`，不影响 `ELAN2513` 触摸屏。

## 2. 重装后先确认硬件

运行：

```bash
cat /sys/class/dmi/id/product_name
grep -B4 -A10 -i 'ELAN2703' /proc/bus/input/devices
ls -l /sys/bus/i2c/drivers/i2c_hid_acpi
```

预期看到：

```text
Redrix
ELAN2703:00 04F3:323B Touchpad
i2c-ELAN2703:00
```

如果机器型号或设备名不同，不要直接套用本文脚本。

## 3. 安装修复

### 3.1 安装休眠恢复钩子

复制并执行整个命令块：

```bash
sudo install -D -m 0755 /dev/stdin \
  /usr/lib/systemd/system-sleep/99-redrix-touchpad-resume <<'EOF'
#!/bin/sh
# Reinitialize only the ELAN2703 touchpad after system resume.
# The ELAN2513 touchscreen is intentionally left untouched.

driver=/sys/bus/i2c/drivers/i2c_hid_acpi
device=i2c-ELAN2703:00
wakeup=/sys/bus/i2c/devices/$device/power/wakeup

if [ ! -e "/sys/bus/i2c/devices/$device" ]; then
    logger -t redrix-touchpad "ELAN2703 device is absent; skipping"
    exit 0
fi

case "$1" in
    pre)
        # LID0 remains enabled, so opening the lid can still wake the system.
        [ ! -w "$wakeup" ] || printf '%s' disabled > "$wakeup"
        exit 0
        ;;
    post)
        ;;
    *)
        exit 0
        ;;
esac

# Let the I2C controller finish resuming before reinitializing the touchpad.
sleep 1

if [ -e "$driver/$device" ]; then
    printf '%s' "$device" > "$driver/unbind" || {
        logger -t redrix-touchpad "failed to unbind $device"
        exit 1
    }
    sleep 1
fi

printf '%s' "$device" > "$driver/bind" || {
    logger -t redrix-touchpad "failed to bind $device"
    exit 1
}

# Rebinding may restore wakeup=enabled, so disable it again.
[ ! -w "$wakeup" ] || printf '%s' disabled > "$wakeup"

logger -t redrix-touchpad "reinitialized $device after resume"
EOF
```

### 3.2 安装 udev 唤醒规则

```bash
sudo install -D -m 0644 /dev/stdin \
  /etc/udev/rules.d/99-redrix-touchpad-wakeup.rules <<'EOF'
# ELAN2703 can leave a wake event pending and abort deep suspend on Redrix.
# Lid-open (LID0) remains enabled as the normal wake source.
ACTION=="add", SUBSYSTEM=="i2c", KERNEL=="i2c-ELAN2703:00", ATTR{power/wakeup}="disabled"
EOF

sudo udevadm control --reload-rules
echo disabled | sudo tee \
  /sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup
```

### 3.3 立即恢复当前已经失灵的触摸板

只有在确认设备名是 `i2c-ELAN2703:00` 后才运行：

```bash
echo i2c-ELAN2703:00 | sudo tee \
  /sys/bus/i2c/drivers/i2c_hid_acpi/unbind
sleep 1
echo i2c-ELAN2703:00 | sudo tee \
  /sys/bus/i2c/drivers/i2c_hid_acpi/bind
echo disabled | sudo tee \
  /sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup
```

不要重新加载整个 `i2c_hid_acpi` 模块，因为同一模块还管理 `ELAN2513` 触摸屏。

## 4. 验证

### 4.1 验证唤醒源

```bash
cat /sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup
cat /proc/acpi/wakeup | grep -E 'LID0|H015'
```

预期：

```text
disabled
LID0 ... enabled
H015 ... disabled ... i2c:i2c-ELAN2703:00
```

### 4.2 验证真实休眠

先记录统计：

```bash
for f in success fail failed_suspend last_failed_errno last_failed_step; do
  printf '%s=' "$f"
  cat "/sys/power/suspend_stats/$f"
done
```

合盖至少 15 秒，再开盖并重复命令。正常情况下：

- `success` 增加 1；
- `fail` 不增加；
- 触摸板恢复后可以正常使用；
- `power/wakeup` 仍为 `disabled`。

本次实际验证结果是 `success: 0 → 1`，`fail` 保持为 `4`。`fail=4` 是修复前的历史累计，不会自动清零。

检查恢复钩子日志：

```bash
journalctl -b -t redrix-touchpad --no-pager
```

## 5. 卸载

```bash
sudo rm -f \
  /usr/lib/systemd/system-sleep/99-redrix-touchpad-resume \
  /etc/udev/rules.d/99-redrix-touchpad-wakeup.rules
sudo udevadm control --reload-rules
```

如果希望重新允许触摸板唤醒系统：

```bash
echo enabled | sudo tee \
  /sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup
```

## 6. 内核升级后的安全注意事项

本次使用的 6.18.48 内核没有启用 `CONFIG_HID_HAPTIC`，因此对 `ELAN2703` 做设备级 unbind/bind 不会触发当时已知的 HID haptic 生命周期问题。重装系统或更换内核后，先检查：

```bash
if [ -r /proc/config.gz ]; then
  zgrep '^CONFIG_HID_HAPTIC' /proc/config.gz
else
  grep '^CONFIG_HID_HAPTIC' "/boot/config-$(uname -r)"
fi
```

如果输出为 `CONFIG_HID_HAPTIC=y`，应先确认所用内核已经修复相关 use-after-free，再启用自动 unbind/bind；否则先只安装 udev 唤醒规则，或使用已经包含修复的新内核。

## 7. 参考资料

- Redrix 同型号问题与 `ELAN2703` 设备级重置说明：<https://www.cnblogs.com/acd407/articles/19669407>
- Redrix 的 libinput 参数记录：<https://github.com/chrultrabook/docs/issues/72>
- HID haptic 设备解绑生命周期问题报告（2026-07）：<https://lists.openwall.net/linux-kernel/2026/07/24/2274>

