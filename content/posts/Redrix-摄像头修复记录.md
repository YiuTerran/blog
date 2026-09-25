---
title: Deepin 25 上 Intel IPU6 / hi556 摄像头修复与按需虚拟摄像头指南
date: 2026-09-25T00:00:00+08:00
slug: 3797d98
draft: false
author:
  name: tryao
tags: ["linux", "deepin", "Redrix", "IPU6", "libcamera"]
collections: []
toc: true
math: true
lightgallery: false
---

> 最后验证日期：2026-09-25  
> 本机环境：Deepin 25（crimson）、Linux `6.18.48-amd64-desktop-rolling`、Intel Alder Lake IPU6 `8086:465d`、hi556 MIPI 摄像头。  
> 最终效果：应用可在 `IPU6 Camera 360p`（`/dev/video42`，640×360）和 `IPU6 Camera 720p`（`/dev/video43`，1280×720）之间手动选择；空闲时不打开物理摄像头，停止取流 3 秒后自动释放。

<!--more-->

## 1. 问题与最终架构

这台电脑的摄像头不是普通 USB UVC 摄像头，而是通过 Intel IPU6 连接的 MIPI hi556。Linux 会为 IPU6 媒体拓扑生成大量 `/dev/video*` 节点；腾讯会议等软件看到的几十个 `ipu6(n)` 多数是媒体图中的原始节点，不是可直接显示的成品摄像头，所以选中后没有画面。

本机的物理摄像头可以被 libcamera 正常驱动，但部分传统应用只接受标准 V4L2 Capture 设备。最终方案如下：

```text
hi556 / Intel IPU6
        │
        │ 仅在任一虚拟设备执行 V4L2 STREAMON 时启动
        ▼
单一共享按需代理 ipu6-camera-demand
        │
        ├── 仅 360p 被读取：libcamera 640×360
        ├── 仅 720p 被读取：libcamera 1280×720
        └── 两路同时读取：单个 720p 流经 tee 输出 720p 并缩放出 360p
                    │
                    ▼
              v4l2loopback
        ├── /dev/video42：IPU6 Camera 360p
        └── /dev/video43：IPU6 Camera 720p
                    │
                    ├── 腾讯会议（需兼容层，见第 13 节）
                    ├── 微信
                    ├── 浏览器/WebRTC
                    └── 其他 V4L2 软件
```

按需代理常驻时只持有 `/dev/video42` 和 `/dev/video43` 的写端，并各放入一帧黑色占位图，使 `exclusive_caps=1` 的虚拟设备始终以纯 Capture 摄像头出现。它订阅 v4l2loopback 0.15.4 的 `V4L2_EVENT_PRI_CLIENT_USAGE` 私有事件：

- 仅枚举或查询摄像头不会启动物理相机；
- 软件真正执行 `STREAMON` 后才启动 `libcamerasrc`；
- 读取结束 3 秒后停止 GStreamer 并释放物理相机；
- 双设备空闲实测约 2–4 MB，且没有 `gst-launch-1.0` 子进程；
- 单路 360p 取流约 47 MB，单路或双路含 720p 时约 62 MB，退出后回落；
- 第一次取流可能短暂出现 1–2 帧黑色占位帧，之后进入真实画面。

最终方案不依赖 `pw-v4l2` 或 `gstreamer1.0-pipewire`。此前 `pw-v4l2` 能让腾讯会议出现 hi556 条目，但腾讯会议处理 PipeWire 提供的 BGRx 画面时仍显示黑屏，因此没有采用。

进一步跟踪腾讯会议的 V4L2 调用后确认：其 `libxcast.so` 在 `VIDIOC_DQBUF` 和 `VIDIOC_QBUF` 前把 `v4l2_buffer.memory` 留成 0，而 MMAP 队列要求 `V4L2_MEMORY_MMAP=1`。内核因此返回 `EINVAL`，日志会循环出现 `Could not requeue buffer`，最终表现为黑屏。第 13 节的兼容库只对 `/dev/video42` 和 `/dev/video43` 修正这两个调用，不会修改其他摄像头或其他程序。

## 2. 已验证的软件版本

以下版本是本机成功运行时的基线。重装后不要求版本号完全一致，但 libcamera 相关包应来自同一套仓库版本。

| 组件 | 已验证版本 |
|---|---:|
| Deepin | 25 / crimson |
| Linux 内核 | 6.18.48-amd64-desktop-rolling |
| libcamera / libcamera-tools | 0.7.0-2deepin1 |
| gstreamer1.0-libcamera | 0.7.0-2deepin1 |
| GStreamer base/good | 1.24.13 |
| v4l-utils | 1.30.1 |
| DKMS | 3.1.0 |
| v4l2loopback | 0.15.4（上游源码 DKMS） |

本机 Secure Boot 为关闭状态。若重装后启用了 Secure Boot，必须签名并信任 DKMS 模块，否则 `modprobe v4l2loopback` 会失败。

## 3. 安装基础组件

先在终端缓存一次 sudo 凭据，避免每条命令都要求密码：

```bash
sudo -v
```

安装依赖。Deepin 软件仓库未来可能调整包名；以下包名已在 Deepin 25 验证：

```bash
sudo apt update
sudo apt install \
  build-essential git dkms "linux-headers-$(uname -r)" \
  libcamera-tools libcamera-ipa \
  gstreamer1.0-libcamera gstreamer1.0-tools \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  v4l-utils
```

如果系统限制直接使用 `apt`，通过 Deepin 应用商店或系统软件管理器安装同名包即可。

最终按需方案不需要安装以下两个包：

```text
pipewire-v4l2
gstreamer1.0-pipewire
```

它们可以保留，但不是本方案的依赖。

## 4. 确认内核已经识别 IPU6 和 hi556

查看硬件：

```bash
lspci -nn | grep -iE 'image|camera|multimedia|ipu'
```

本机应出现：

```text
00:05.0 Multimedia controller [0480]: Intel Corporation Alder Lake Imaging Signal Processor [8086:465d]
```

检查内核模块：

```bash
modinfo intel-ipu6
modinfo intel-ipu6-isys
modinfo hi556
dmesg | grep -iE 'ipu6|hi556|camera'
```

Deepin 25 的 6.18 内核已自带 `intel-ipu6`、`intel-ipu6-isys` 和 `hi556`。不要一开始就盲目安装额外的 Intel IPU6 DKMS 驱动；先执行后面的 `cam -l`。只有内核确实缺少这些模块时，才参考 [intel/ipu6-drivers](https://github.com/intel/ipu6-drivers) 的 DKMS 说明。

本机也曾加入过 `ipu6-drivers/0.0.0` DKMS，但在 6.18 上核心 IPU6 与 hi556 都已有内核原生模块，DKMS 状态会提示 `original_module exists`。这不是最终虚拟摄像头方案的必要条件。

## 5. 给予桌面用户 `/dev/udmabuf` 权限

libcamera 的软件 ISP 需要访问 `/dev/udmabuf`。创建 udev 规则：

```bash
sudo tee /etc/udev/rules.d/70-libcamera-udmabuf.rules >/dev/null <<'EOF'
# Allow the active desktop user to use libcamera's software ISP allocator.
KERNEL=="udmabuf", TAG+="uaccess"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=misc
```

如果 ACL 没有立即更新，注销并重新登录，或直接重启。检查：

```bash
getfacl /dev/udmabuf
```

当前图形会话用户应具有读写权限。

## 6. 先用 libcamera 验证物理摄像头

列出摄像头：

```bash
cam -l
```

本机的正确结果包含：

```text
Available cameras:
1: 'hi556' (\_SB_.PCI0.I2C2.CAM0)
```

以下警告在本机存在，但不妨碍画面输出：

```text
No static properties available for 'hi556'
Configuration file 'hi556.yaml' not found
Failed to create camera sensor helper for hi556
```

libcamera 会回退到通用的 `uncalibrated.yaml` 和软件 ISP。

打开预览：

```bash
qcam
```

只有 `qcam` 能正常显示画面后，才继续配置虚拟摄像头。如果 `cam -l` 找不到 hi556，应先处理内核驱动、固件或 `/dev/udmabuf` 权限问题。

### 可选：让开始菜单“相机”直接启动 qcam

原 Deepin 相机程序只识别普通 V4L2 摄像头时，可能提示“未连接摄像头”。可建立用户级桌面入口覆盖：

```bash
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/deepin-camera.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Camera
Name[zh_CN]=相机
GenericName=Camera
GenericName[zh_CN]=相机
Comment=Camera preview and image capture using libcamera
Comment[zh_CN]=使用 libcamera 预览和拍摄照片
Exec=/usr/bin/qcam
TryExec=/usr/bin/qcam
Icon=deepin-camera
Categories=AudioVideo;Video;Utility;
Terminal=false
StartupNotify=true
X-Deepin-Vendor=deepin
X-MultipleArgs=false
EOF

update-desktop-database ~/.local/share/applications
```

## 7. 安装兼容 Linux 6.18 的 v4l2loopback

Deepin 仓库当时提供的 `v4l2loopback-dkms 0.14.0-1` 无法在 Linux 6.18 上编译，典型错误包括：

```text
implicit declaration of function 'del_timer_sync'
too few arguments to function 'v4l2_fh_add'
too few arguments to function 'v4l2_fh_del'
implicit declaration of function 'setup_timer'
```

上游 0.15.4 已在本机内核上编译和运行成功。先检查仓库版本：

```bash
apt-cache policy v4l2loopback-dkms
```

如果候选版本已经是 0.15.4 或更高，可优先直接安装发行版包。若仍是 0.14，按下面步骤安装固定的上游版本。

先移除可能处于半配置状态的旧包：

```bash
sudo dkms remove -m v4l2loopback -v 0.14.0 --all 2>/dev/null || true
sudo apt remove v4l2loopback-dkms
```

下载并放入 DKMS 源码目录：

```bash
workdir="$(mktemp -d)"
git clone --depth 1 --branch v0.15.4 \
  https://github.com/v4l2loopback/v4l2loopback.git \
  "$workdir/v4l2loopback"

sudo install -d -m 0755 /usr/src/v4l2loopback-0.15.4
sudo cp -a "$workdir/v4l2loopback/." /usr/src/v4l2loopback-0.15.4/
```

注册、编译并安装：

```bash
sudo dkms add -m v4l2loopback -v 0.15.4
sudo dkms build -m v4l2loopback -v 0.15.4 -k "$(uname -r)"
sudo dkms install -m v4l2loopback -v 0.15.4 -k "$(uname -r)"
sudo depmod -a "$(uname -r)"
```

检查：

```bash
dkms status | grep v4l2loopback
modinfo v4l2loopback | grep -E 'filename|version|signer|vermagic'
```

预期包含：

```text
v4l2loopback/0.15.4, <当前内核>, x86_64: installed
version: 0.15.4
```

若 Secure Boot 已开启且 `modprobe` 报签名错误，需要按系统提示注册 DKMS MOK 证书，或在固件设置中关闭 Secure Boot。可用以下命令确认状态：

```bash
mokutil --sb-state
```

## 8. 固定两个虚拟设备为 `/dev/video42` 和 `/dev/video43`

创建模块自动加载配置：

```bash
sudo tee /etc/modules-load.d/ipu6-virtual-camera.conf >/dev/null <<EOF
v4l2loopback
EOF

sudo tee /etc/modprobe.d/ipu6-virtual-camera.conf >/dev/null <<EOF
options v4l2loopback devices=2 video_nr=42,43 card_label="IPU6 Camera 360p,IPU6 Camera 720p" exclusive_caps=1,1 max_buffers=4
EOF
```

首次加载：

```bash
sudo modprobe v4l2loopback
```

如果模块已经按旧的单设备参数加载，先彻底退出使用摄像头的软件并停止代理，再重载：

```bash
systemctl --user stop ipu6-virtual-camera.service
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback
```

检查：

```bash
cat /sys/class/video4linux/video42/name
cat /sys/class/video4linux/video43/name
ls -l /dev/video42 /dev/video43
```

预期名称：

```text
IPU6 Camera 360p
IPU6 Camera 720p
```

配置文件中 `card_label` 必须用一组引号包住整个逗号分隔列表；分别给每个名称加引号会让引号字符进入设备名称。

`exclusive_caps=1,1` 很重要：它让 Chrome/WebRTC 等应用只看到标准 Capture 能力。共享代理会一直持有两个虚拟设备的 Output 写端，因此即使物理摄像头处于关闭状态，应用仍能发现两个设备。

## 9. 安装按需代理

代理只依赖 libc 和 Linux V4L2 头文件。保存以下源码到：

```text
~/.local/share/ipu6-camera/ipu6-camera-demand.c
```

```c
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define V4L2LOOPBACK_EVENT_OFFSET 0x08E00000U
#define V4L2_EVENT_PRI_CLIENT_USAGE \
	(V4L2_EVENT_PRIVATE_START + V4L2LOOPBACK_EVENT_OFFSET + 1U)
#define V4L2LOOPBACK_CID_BASE (V4L2_CID_USER_BASE | 0xf000)
#define CID_KEEP_FORMAT (V4L2LOOPBACK_CID_BASE + 0)

#define OUTPUT_COUNT 2
#define LOW_INDEX 0
#define HIGH_INDEX 1
#define LOW_MASK (1U << LOW_INDEX)
#define HIGH_MASK (1U << HIGH_INDEX)
#define FPS 30U
#define IDLE_GRACE_MS 3000
#define RESTART_DELAY_MS 1000

struct v4l2_event_client_usage {
	uint32_t count;
};

struct camera_output {
	const char *path;
	const char *name;
	unsigned int width;
	unsigned int height;
	size_t frame_size;
	int video_fd;
	int feeder_fd;
	uint8_t *frame;
	size_t frame_used;
	bool demanded;
};

static volatile sig_atomic_t stopping;
static pid_t feeder_pid = -1;
static unsigned int feeder_mask;
static struct camera_output outputs[OUTPUT_COUNT] = {
	{
		.path = "/dev/video42",
		.name = "360p",
		.width = 640,
		.height = 360,
		.video_fd = -1,
		.feeder_fd = -1,
	},
	{
		.path = "/dev/video43",
		.name = "720p",
		.width = 1280,
		.height = 720,
		.video_fd = -1,
		.feeder_fd = -1,
	},
};

static long long monotonic_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (long long)ts.tv_sec * 1000LL + ts.tv_nsec / 1000000LL;
}

static void on_signal(int signo)
{
	(void)signo;
	stopping = 1;
}

static int xioctl(int fd, unsigned long request, void *arg)
{
	int rc;

	do {
		rc = ioctl(fd, request, arg);
	} while (rc < 0 && errno == EINTR);
	return rc;
}

static int write_frame(const struct camera_output *output,
	const uint8_t *frame)
{
	int attempts = 0;

	while (!stopping) {
		ssize_t written = write(output->video_fd, frame,
			output->frame_size);

		if (written == (ssize_t)output->frame_size)
			return 0;
		if (written >= 0) {
			fprintf(stderr,
				"camera demand: %s short frame write (%zd)\n",
				output->name, written);
			return -1;
		}
		if (errno == EINTR)
			continue;
		if ((errno == EAGAIN || errno == EWOULDBLOCK) &&
		    attempts++ < 10) {
			struct pollfd pfd = {
				.fd = output->video_fd,
				.events = POLLOUT,
			};

			poll(&pfd, 1, 100);
			continue;
		}
		fprintf(stderr, "camera demand: %s write failed: %s\n",
			output->name, strerror(errno));
		return -1;
	}
	return -1;
}

static int open_writer(struct camera_output *output)
{
	struct v4l2_capability cap = { 0 };
	struct v4l2_control keep = {
		.id = CID_KEEP_FORMAT,
		.value = 0,
	};
	struct v4l2_format fmt = { 0 };
	struct v4l2_streamparm parm = { 0 };
	struct v4l2_event_subscription sub = { 0 };
	uint8_t *neutral_frame;
	size_t i;
	int fd;

	output->frame_size = (size_t)output->width * output->height * 2U;
	fd = open(output->path, O_RDWR | O_NONBLOCK | O_CLOEXEC);
	if (fd < 0) {
		fprintf(stderr, "camera demand: open %s failed: %s\n",
			output->path, strerror(errno));
		return -1;
	}
	output->video_fd = fd;

	if (xioctl(fd, VIDIOC_S_CTRL, &keep) < 0) {
		fprintf(stderr, "camera demand: clear keep_format on %s: %s\n",
			output->path, strerror(errno));
		goto fail;
	}
	if (xioctl(fd, VIDIOC_QUERYCAP, &cap) < 0) {
		fprintf(stderr, "camera demand: query %s: %s\n",
			output->path, strerror(errno));
		goto fail;
	}
	if (!(cap.device_caps & V4L2_CAP_VIDEO_OUTPUT)) {
		fprintf(stderr, "camera demand: %s has no output capability\n",
			output->path);
		goto fail;
	}

	fmt.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
	fmt.fmt.pix.width = output->width;
	fmt.fmt.pix.height = output->height;
	fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
	fmt.fmt.pix.field = V4L2_FIELD_NONE;
	fmt.fmt.pix.colorspace = V4L2_COLORSPACE_REC709;
	if (xioctl(fd, VIDIOC_S_FMT, &fmt) < 0) {
		fprintf(stderr, "camera demand: set format on %s: %s\n",
			output->path, strerror(errno));
		goto fail;
	}
	if (fmt.fmt.pix.width != output->width ||
	    fmt.fmt.pix.height != output->height ||
	    fmt.fmt.pix.pixelformat != V4L2_PIX_FMT_YUYV) {
		fprintf(stderr, "camera demand: unexpected format on %s\n",
			output->path);
		goto fail;
	}

	parm.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
	parm.parm.output.timeperframe.numerator = 1;
	parm.parm.output.timeperframe.denominator = FPS;
	if (xioctl(fd, VIDIOC_S_PARM, &parm) < 0)
		fprintf(stderr, "camera demand: set frame rate on %s: %s\n",
			output->path, strerror(errno));

	sub.type = V4L2_EVENT_PRI_CLIENT_USAGE;
	sub.flags = V4L2_EVENT_SUB_FL_SEND_INITIAL;
	if (xioctl(fd, VIDIOC_SUBSCRIBE_EVENT, &sub) < 0) {
		fprintf(stderr, "camera demand: subscribe usage on %s: %s\n",
			output->path, strerror(errno));
		goto fail;
	}

	neutral_frame = malloc(output->frame_size);
	if (!neutral_frame) {
		fprintf(stderr, "camera demand: allocate %s neutral frame: %s\n",
			output->name, strerror(errno));
		goto fail;
	}
	for (i = 0; i < output->frame_size; i += 4) {
		neutral_frame[i + 0] = 16;
		neutral_frame[i + 1] = 128;
		neutral_frame[i + 2] = 16;
		neutral_frame[i + 3] = 128;
	}
	if (write_frame(output, neutral_frame) < 0) {
		free(neutral_frame);
		goto fail;
	}
	free(neutral_frame);
	return 0;

fail:
	close(fd);
	output->video_fd = -1;
	return -1;
}

static void release_stream_buffers(void)
{
	unsigned int i;

	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (outputs[i].feeder_fd >= 0)
			close(outputs[i].feeder_fd);
		outputs[i].feeder_fd = -1;
		free(outputs[i].frame);
		outputs[i].frame = NULL;
		outputs[i].frame_used = 0;
	}
	feeder_mask = 0;
}

static int prepare_stream_buffers(unsigned int mask)
{
	unsigned int i;

	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (!(mask & (1U << i)))
			continue;
		outputs[i].frame = malloc(outputs[i].frame_size);
		if (!outputs[i].frame) {
			fprintf(stderr,
				"camera demand: allocate %s stream frame: %s\n",
				outputs[i].name, strerror(errno));
			release_stream_buffers();
			return -1;
		}
	}
	return 0;
}

static void close_child_pipe_fds(int pipes[OUTPUT_COUNT][2],
	unsigned int mask)
{
	unsigned int i;

	for (i = 0; i < OUTPUT_COUNT; ++i) {
		int end;

		for (end = 0; end < 2; ++end) {
			int fd = pipes[i][end];

			if (fd < 0 || fd == STDOUT_FILENO ||
			    (mask == (LOW_MASK | HIGH_MASK) && fd == 3))
				continue;
			close(fd);
		}
	}
}

static pid_t start_feeder(unsigned int mask)
{
	int pipes[OUTPUT_COUNT][2] = { { -1, -1 }, { -1, -1 } };
	unsigned int i;
	pid_t pid;

	if (prepare_stream_buffers(mask) < 0)
		return -1;
	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (!(mask & (1U << i)))
			continue;
		if (pipe2(pipes[i], O_CLOEXEC) < 0) {
			fprintf(stderr, "camera demand: create %s pipe: %s\n",
				outputs[i].name, strerror(errno));
			goto fail;
		}
	}

	pid = fork();
	if (pid < 0) {
		fprintf(stderr, "camera demand: fork feeder: %s\n",
			strerror(errno));
		goto fail;
	}
	if (pid == 0) {
		char *const low_argv[] = {
			"/usr/bin/gst-launch-1.0", "-q",
			"libcamerasrc",
			"!", "video/x-raw,width=640,height=360,framerate=30/1",
			"!", "videoconvert",
			"!", "video/x-raw,format=YUY2,width=640,height=360,framerate=30/1",
			"!", "fdsink", "fd=1", "sync=false",
			NULL,
		};
		char *const high_argv[] = {
			"/usr/bin/gst-launch-1.0", "-q",
			"libcamerasrc",
			"!", "video/x-raw,width=1280,height=720,framerate=30/1",
			"!", "videoconvert",
			"!", "video/x-raw,format=YUY2,width=1280,height=720,framerate=30/1",
			"!", "fdsink", "fd=1", "sync=false",
			NULL,
		};
		char *const dual_argv[] = {
			"/usr/bin/gst-launch-1.0", "-q",
			"libcamerasrc",
			"!", "video/x-raw,width=1280,height=720,framerate=30/1",
			"!", "tee", "name=t",
			"t.", "!", "queue", "!", "videoconvert", "!", "videoscale",
			"!", "video/x-raw,format=YUY2,width=640,height=360,framerate=30/1",
			"!", "fdsink", "fd=1", "sync=false",
			"t.", "!", "queue", "!", "videoconvert",
			"!", "video/x-raw,format=YUY2,width=1280,height=720,framerate=30/1",
			"!", "fdsink", "fd=3", "sync=false",
			NULL,
		};
		char *const *argv;

		if (mask & LOW_MASK) {
			if (dup2(pipes[LOW_INDEX][1], STDOUT_FILENO) < 0)
				_exit(126);
		} else if (dup2(pipes[HIGH_INDEX][1], STDOUT_FILENO) < 0) {
			_exit(126);
		}
		if (mask == (LOW_MASK | HIGH_MASK) &&
		    dup2(pipes[HIGH_INDEX][1], 3) < 0)
			_exit(126);
		close_child_pipe_fds(pipes, mask);
		prctl(PR_SET_PDEATHSIG, SIGTERM);
		setenv("LIBCAMERA_LOG_LEVELS", "*:ERROR", 1);

		argv = mask == LOW_MASK ? low_argv :
			mask == HIGH_MASK ? high_argv : dual_argv;
		execv(argv[0], argv);
		perror("exec gst-launch-1.0");
		_exit(127);
	}

	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (!(mask & (1U << i)))
			continue;
		close(pipes[i][1]);
		pipes[i][1] = -1;
		fcntl(pipes[i][0], F_SETFL,
			fcntl(pipes[i][0], F_GETFL) | O_NONBLOCK);
		outputs[i].feeder_fd = pipes[i][0];
		pipes[i][0] = -1;
	}
	feeder_mask = mask;
	fprintf(stderr,
		"camera demand: physical camera started (pid %ld, outputs=%s%s)\n",
		(long)pid, mask & LOW_MASK ? "360p" : "",
		mask == (LOW_MASK | HIGH_MASK) ? "+720p" :
		mask & HIGH_MASK ? "720p" : "");
	return pid;

fail:
	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (pipes[i][0] >= 0)
			close(pipes[i][0]);
		if (pipes[i][1] >= 0)
			close(pipes[i][1]);
	}
	release_stream_buffers();
	return -1;
}

static void stop_feeder(void)
{
	int status;
	int i;

	if (feeder_pid <= 0) {
		release_stream_buffers();
		return;
	}

	kill(feeder_pid, SIGTERM);
	for (i = 0; i < 20; ++i) {
		pid_t rc = waitpid(feeder_pid, &status, WNOHANG);

		if (rc == feeder_pid) {
			fprintf(stderr, "camera demand: physical camera stopped\n");
			feeder_pid = -1;
			release_stream_buffers();
			return;
		}
		usleep(100000);
	}
	kill(feeder_pid, SIGKILL);
	waitpid(feeder_pid, &status, 0);
	fprintf(stderr, "camera demand: physical camera killed after timeout\n");
	feeder_pid = -1;
	release_stream_buffers();
}

static bool reap_feeder(void)
{
	int status;
	pid_t rc;

	if (feeder_pid <= 0)
		return false;
	rc = waitpid(feeder_pid, &status, WNOHANG);
	if (rc != feeder_pid)
		return false;

	fprintf(stderr, "camera demand: physical camera exited (status %d)\n",
		status);
	feeder_pid = -1;
	release_stream_buffers();
	return true;
}

static int forward_available_frames(struct camera_output *output)
{
	while (output->feeder_fd >= 0) {
		ssize_t got = read(output->feeder_fd,
			output->frame + output->frame_used,
			output->frame_size - output->frame_used);

		if (got > 0) {
			output->frame_used += (size_t)got;
			if (output->frame_used == output->frame_size) {
				if (write_frame(output, output->frame) < 0)
					return -1;
				output->frame_used = 0;
			}
			continue;
		}
		if (got == 0)
			return 0;
		if (errno == EINTR)
			continue;
		if (errno == EAGAIN || errno == EWOULDBLOCK)
			return 0;
		fprintf(stderr, "camera demand: read %s feeder: %s\n",
			output->name, strerror(errno));
		return -1;
	}
	return 0;
}

static unsigned int demanded_mask(void)
{
	unsigned int mask = 0;
	unsigned int i;

	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (outputs[i].demanded)
			mask |= 1U << i;
	}
	return mask;
}

static void drain_usage_events(struct camera_output *output)
{
	struct v4l2_event ev;

	while (xioctl(output->video_fd, VIDIOC_DQEVENT, &ev) == 0) {
		if (ev.type == V4L2_EVENT_PRI_CLIENT_USAGE) {
			const struct v4l2_event_client_usage *usage =
				(const void *)&ev.u;
			bool demanded = usage->count > 0;

			if (demanded != output->demanded) {
				output->demanded = demanded;
				fprintf(stderr, "camera demand: %s readers %s\n",
					output->name,
					demanded ? "active" : "idle");
			}
		}
	}
}

int main(int argc, char **argv)
{
	long long stop_at = -1;
	long long restart_at = -1;
	unsigned int i;
	int exit_code = 0;

	if (argc > 1)
		outputs[LOW_INDEX].path = argv[1];
	if (argc > 2)
		outputs[HIGH_INDEX].path = argv[2];

	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);
	signal(SIGHUP, on_signal);

	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (open_writer(&outputs[i]) < 0) {
			exit_code = 1;
			goto out;
		}
		fprintf(stderr,
			"camera demand: %s ready on %s (%ux%u@%u)\n",
			outputs[i].name, outputs[i].path,
			outputs[i].width, outputs[i].height, FPS);
	}

	while (!stopping) {
		struct pollfd pfds[OUTPUT_COUNT * 2];
		int feeder_slot[OUTPUT_COUNT] = { -1, -1 };
		nfds_t count = OUTPUT_COUNT;
		unsigned int wanted;
		long long now = monotonic_ms();
		int timeout = 250;
		int rc;

		for (i = 0; i < OUTPUT_COUNT; ++i) {
			pfds[i].fd = outputs[i].video_fd;
			pfds[i].events = POLLPRI;
			pfds[i].revents = 0;
		}
		for (i = 0; i < OUTPUT_COUNT; ++i) {
			if (outputs[i].feeder_fd < 0)
				continue;
			feeder_slot[i] = (int)count;
			pfds[count].fd = outputs[i].feeder_fd;
			pfds[count].events = POLLIN | POLLHUP | POLLERR;
			pfds[count].revents = 0;
			++count;
		}

		if (stop_at >= 0 && stop_at - now < timeout)
			timeout = stop_at > now ? (int)(stop_at - now) : 0;
		if (restart_at >= 0 && restart_at - now < timeout)
			timeout = restart_at > now ?
				(int)(restart_at - now) : 0;

		rc = poll(pfds, count, timeout);
		if (rc < 0 && errno != EINTR) {
			fprintf(stderr, "camera demand: poll: %s\n",
				strerror(errno));
			exit_code = 1;
			break;
		}

		if (rc > 0) {
			for (i = 0; i < OUTPUT_COUNT; ++i) {
				if (pfds[i].revents & POLLPRI)
					drain_usage_events(&outputs[i]);
			}
		}

		now = monotonic_ms();
		wanted = demanded_mask();
		if (wanted) {
			stop_at = -1;
			if (feeder_pid > 0 && feeder_mask != wanted) {
				fprintf(stderr,
					"camera demand: switching output set %u -> %u\n",
					feeder_mask, wanted);
				stop_feeder();
				restart_at = now;
			} else if (feeder_pid <= 0 && restart_at < 0) {
				restart_at = now;
			}
		} else {
			restart_at = -1;
			if (feeder_pid > 0 && stop_at < 0)
				stop_at = now + IDLE_GRACE_MS;
		}

		if (rc > 0) {
			for (i = 0; i < OUTPUT_COUNT; ++i) {
				int slot = feeder_slot[i];

				if (slot >= 0 && outputs[i].feeder_fd >= 0 &&
				    (pfds[slot].revents & POLLIN) &&
				    forward_available_frames(&outputs[i]) < 0) {
					exit_code = 1;
					stopping = 1;
					break;
				}
			}
		}

		now = monotonic_ms();
		wanted = demanded_mask();
		if (reap_feeder() && wanted)
			restart_at = now + RESTART_DELAY_MS;
		if (wanted && feeder_pid <= 0 && restart_at >= 0 &&
		    now >= restart_at) {
			feeder_pid = start_feeder(wanted);
			restart_at = feeder_pid > 0 ?
				-1 : now + RESTART_DELAY_MS;
		}
		if (!wanted && feeder_pid > 0 && stop_at >= 0 &&
		    now >= stop_at) {
			stop_feeder();
			stop_at = -1;
		}
	}

out:
	stop_feeder();
	for (i = 0; i < OUTPUT_COUNT; ++i) {
		if (outputs[i].video_fd >= 0)
			close(outputs[i].video_fd);
	}
	return exit_code;
}
```

编译并安装：

```bash
mkdir -p ~/.local/share/ipu6-camera ~/.local/libexec

# 先把上面的源码保存为：
# ~/.local/share/ipu6-camera/ipu6-camera-demand.c

gcc -std=c11 -O2 -Wall -Wextra -Werror \
  ~/.local/share/ipu6-camera/ipu6-camera-demand.c \
  -o ~/.local/libexec/ipu6-camera-demand

chmod 0755 ~/.local/libexec/ipu6-camera-demand
```

## 10. 创建并启用用户服务

创建 `~/.config/systemd/user/ipu6-virtual-camera.service`：

```ini
[Unit]
Description=IPU6 dual virtual camera demand supervisor
ConditionPathExists=/dev/video42
ConditionPathExists=/dev/video43

[Service]
Type=simple
ExecStartPre=/usr/bin/test -e /dev/video42
ExecStartPre=/usr/bin/test -e /dev/video43
ExecStart=%h/.local/libexec/ipu6-camera-demand /dev/video42 /dev/video43
Restart=on-failure
RestartSec=2
TimeoutStopSec=5
Nice=5

[Install]
WantedBy=default.target
```

注意：本机实际安装的服务文件使用了绝对路径 `/home/tryao/.local/libexec/ipu6-camera-demand`。上面的 `%h` 写法更便于重装和迁移用户目录；systemd 用户服务支持 `%h`。

启用：

```bash
mkdir -p ~/.config/systemd/user
systemctl --user daemon-reload
systemctl --user enable --now ipu6-virtual-camera.service
```

如果服务文件刚刚才保存，确保保存后再执行 `daemon-reload`。

## 11. 验证空闲状态

```bash
systemctl --user status ipu6-virtual-camera.service
systemctl --user is-enabled ipu6-virtual-camera.service
systemctl --user is-active ipu6-virtual-camera.service

for d in 42 43; do
  cat /sys/class/video4linux/video$d/name
  cat /sys/class/video4linux/video$d/state
  cat /sys/class/video4linux/video$d/format
done
```

预期关键结果：

```text
IPU6 Camera 360p
capture
YUYV:640x360@30
IPU6 Camera 720p
capture
YUYV:1280x720@30
```

空闲时服务 cgroup 中应只有一个 `ipu6-camera-demand` 代理进程，不应存在 `gst-launch-1.0`：

```bash
systemctl --user status ipu6-virtual-camera.service
pgrep -a gst-launch-1.0
```

本机双设备空闲实测约 2–4 MB。代理只应持有 `/dev/video42` 和 `/dev/video43`，不应持有 `/dev/media0`、IPU6 原始视频节点或 `/dev/udmabuf`。

## 12. 验证按需启动和真实画面

先测试 360p：

```bash
v4l2-ctl -d /dev/video42   --stream-mmap=4   --stream-count=20   --stream-to=/tmp/ipu6-360-test.yuyv   --stream-poll
```

再等待约 3 秒释放物理摄像头，然后测试 720p：

```bash
v4l2-ctl -d /dev/video43   --stream-mmap=4   --stream-count=12   --stream-to=/tmp/ipu6-720-test.yuyv   --stream-poll
```

v4l2loopback 可能输出 `VIDIOC_CREATE_BUFS returned -1 (Inappropriate ioctl for device)`，但随后能正常抓满指定帧数时可以忽略。

抓帧期间执行：

```bash
systemctl --user status ipu6-virtual-camera.service
```

只读取 360p 时，子进程参数应包含 `width=640,height=360`；只读取 720p 时应包含 `width=1280,height=720`。抓帧结束约 3 秒后，`gst-launch-1.0` 子进程应自动消失，代理继续常驻。

若安装了 FFmpeg，可检查两路亮度：

```bash
ffmpeg -hide_banner -loglevel info   -f rawvideo -pixel_format yuyv422 -video_size 640x360 -framerate 30   -i /tmp/ipu6-360-test.yuyv   -vf signalstats,metadata=print -f null - 2>&1   | grep lavfi.signalstats.YAVG=

ffmpeg -hide_banner -loglevel info   -f rawvideo -pixel_format yuyv422 -video_size 1280x720 -framerate 30   -i /tmp/ipu6-720-test.yuyv   -vf signalstats,metadata=print -f null - 2>&1   | grep lavfi.signalstats.YAVG=
```

开始可能有一两帧 `YAVG=16` 的黑色占位帧，之后应明显高于 16。本机最终单路测试分别为 360p `YAVG=127.21`、720p `YAVG=144.64`。

可选的双路并发测试：

```bash
v4l2-ctl -d /dev/video42 --stream-mmap=4 --stream-count=90   --stream-to=/tmp/ipu6-dual-360.yuyv --stream-poll &
low_pid=$!

v4l2-ctl -d /dev/video43 --stream-mmap=4 --stream-count=90   --stream-to=/tmp/ipu6-dual-720.yuyv --stream-poll &
high_pid=$!

wait $low_pid
wait $high_pid
journalctl --user -u ipu6-virtual-camera.service -n 30 --no-pager
```

日志应出现 `outputs=360p+720p`，并且同一时刻只有一个 `gst-launch-1.0`/libcamera 子进程。本机并发末帧亮度分别为 `154.15` 和 `153.70`；双路含 720p 时内存约 62 MB。

测试完成后删除原始文件：

```bash
rm -f /tmp/ipu6-360-test.yuyv /tmp/ipu6-720-test.yuyv
rm -f /tmp/ipu6-dual-360.yuyv /tmp/ipu6-dual-720.yuyv
```

## 13. 在会议和聊天软件中使用

普通软件完全退出并重新启动后，按需要选择：

```text
IPU6 Camera 360p    # 640×360，资源占用较低
IPU6 Camera 720p    # 1280×720，画面更清晰
```

不要选择名为 `ipu6(0)`、`ipu6(1)`……的原始节点。它们是 IPU6 媒体拓扑中的处理节点，不是成品视频流。腾讯会议会把这些节点全部列出来，因此会看到约 32 个条目；不能用全局权限规则安全隐藏它们，否则 libcamera 和 qcam 也可能无法访问完成处理所需的节点。实际使用时忽略它们，只选上述两个名称清晰的虚拟设备之一。

微信、浏览器和正常遵循 V4L2 的应用不需要专用启动器。删除以前为微信创建过的兼容菜单覆盖：

```bash
rm -f ~/.local/share/applications/com.tencent.wechat.desktop
update-desktop-database ~/.local/share/applications
```

### 13.1 腾讯会议黑屏兼容层

本机腾讯会议的 `libxcast.so` 会在 MMAP 队列的 `VIDIOC_DQBUF`/`VIDIOC_QBUF` 调用中传入 `memory=0`，v4l2loopback 会正确返回 `EINVAL`。下面的 LD_PRELOAD 库只在文件描述符确实指向 `/dev/video42` 或 `/dev/video43`、请求确实为这两个 ioctl、缓冲区类型确实为 Video Capture 且 `memory==0` 时，将其修正为 `V4L2_MEMORY_MMAP`。

保存为 `~/.local/share/ipu6-camera/wemeet-v4l2-fix.c`：

```c
#define _GNU_SOURCE

#include <dlfcn.h>
#include <limits.h>
#include <linux/videodev2.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int (*next_ioctl)(int, unsigned long, ...);

static int is_virtual_camera(int fd)
{
	char link[64], path[PATH_MAX];
	ssize_t n;

	snprintf(link, sizeof(link), "/proc/self/fd/%d", fd);
	n = readlink(link, path, sizeof(path) - 1);
	if (n < 0)
		return 0;
	path[n] = '\0';
	return strcmp(path, "/dev/video42") == 0 ||
	       strcmp(path, "/dev/video43") == 0;
}

int ioctl(int fd, unsigned long request, ...)
{
	va_list ap;
	void *arg;
	unsigned int cmd = (unsigned int)request;

	if (!next_ioctl)
		next_ioctl = dlsym(RTLD_NEXT, "ioctl");
	va_start(ap, request);
	arg = va_arg(ap, void *);
	va_end(ap);

	if (arg && is_virtual_camera(fd) &&
	    (cmd == (unsigned int)VIDIOC_DQBUF ||
	     cmd == (unsigned int)VIDIOC_QBUF)) {
		struct v4l2_buffer *buf = arg;

		if (buf->type == V4L2_BUF_TYPE_VIDEO_CAPTURE &&
		    buf->memory == 0)
			buf->memory = V4L2_MEMORY_MMAP;
	}

	return next_ioctl(fd, request, arg);
}
```

编译安装：

```bash
mkdir -p ~/.local/lib/ipu6-camera ~/.local/share/ipu6-camera

gcc -shared -fPIC -O2 -Wall -Wextra -Werror   ~/.local/share/ipu6-camera/wemeet-v4l2-fix.c   -o ~/.local/lib/ipu6-camera/wemeet-v4l2-fix.so   -ldl

chmod 0755 ~/.local/lib/ipu6-camera/wemeet-v4l2-fix.so
```

复制系统菜单文件到用户目录，并仅替换启动命令：

```bash
mkdir -p ~/.local/share/applications
cp /opt/apps/com.qq.wemeet/entries/applications/com.qq.wemeet.desktop   ~/.local/share/applications/com.qq.wemeet.desktop

sed -i   "s|^Exec=.*|Exec=/usr/bin/env LD_PRELOAD=$HOME/.local/lib/ipu6-camera/wemeet-v4l2-fix.so /opt/apps/com.qq.wemeet/files/wemeetapp.sh %u|"   ~/.local/share/applications/com.qq.wemeet.desktop

update-desktop-database ~/.local/share/applications
```

完全退出腾讯会议后，从开始菜单重新打开。修复成功时，腾讯会议日志会出现与所选设备相符的 `config.succ.size.*`、`start.leave.succ` 和 `first.draw`，不再持续出现针对 `/dev/video42` 或 `/dev/video43` 的 `Could not requeue buffer`。

### 13.2 与 qcam 的互斥关系

hi556 物理摄像头一次只能由一个 libcamera 流占用。腾讯会议正在预览或开会时，按需代理会占用物理摄像头，此时 qcam 无法同时使用是正常现象。停止腾讯会议预览或完全退出，等待约 3 秒让代理释放物理相机，再启动 qcam。

如果关闭窗口后仍未释放，检查腾讯会议是否还有后台进程：

```bash
pgrep -a -f wemeetapp
```

只要某个应用仍对 `/dev/video42` 或 `/dev/video43` 保持 V4L2 Capture 流，代理就会继续运行真实摄像头取流。

## 14. 常用管理命令

查看状态：

```bash
systemctl --user status ipu6-virtual-camera.service
```

重启：

```bash
systemctl --user restart ipu6-virtual-camera.service
```

临时停用：

```bash
systemctl --user stop ipu6-virtual-camera.service
```

重新启用：

```bash
systemctl --user start ipu6-virtual-camera.service
```

查看日志：

```bash
journalctl --user -u ipu6-virtual-camera.service -b --no-pager
```

检查驱动：

```bash
dkms status
lsmod | grep v4l2loopback
modinfo v4l2loopback
```

## 15. 常见故障

### `/dev/video42` 或 `/dev/video43` 不存在

```bash
sudo modprobe v4l2loopback
dmesg | tail -100
dkms status | grep v4l2loopback
```

确认 `/etc/modules-load.d/ipu6-virtual-camera.conf` 和 `/etc/modprobe.d/ipu6-virtual-camera.conf` 内容正确。

### 服务显示 `ConditionPathExists` 未满足

先加载模块，再启动用户服务：

```bash
sudo modprobe v4l2loopback
systemctl --user restart ipu6-virtual-camera.service
```

### `cam -l` 找不到 hi556

这不是虚拟摄像头层的问题。优先检查：

```bash
modinfo intel-ipu6
modinfo intel-ipu6-isys
modinfo hi556
dmesg | grep -iE 'ipu6|hi556|camera'
ls -l /dev/udmabuf /dev/media* /dev/video*
```

确认当前内核和对应的 `linux-headers-$(uname -r)` 来自同一套 Deepin 更新。

### `qcam` 正常，但会议软件仍看不到虚拟设备

```bash
cat /sys/class/video4linux/video42/state
cat /sys/class/video4linux/video43/state
v4l2-ctl -d /dev/video42 --all
v4l2-ctl -d /dev/video43 --all
systemctl --user status ipu6-virtual-camera.service
```

`video42` 和 `video43` 的 `state` 都必须是 `capture`，能力中应只有 `Video Capture`，不能处于仅 `Video Output` 状态。完全退出会议软件后再重新打开。

### 虚拟设备出现但始终黑屏

若仅腾讯会议黑屏，先确认是从开始菜单启动，并检查用户菜单覆盖：

```bash
grep ^Exec= ~/.local/share/applications/com.qq.wemeet.desktop
ls -l ~/.local/lib/ipu6-camera/wemeet-v4l2-fix.so
```

`Exec` 应包含 `LD_PRELOAD=`。若腾讯会议日志持续出现针对 `/dev/video42` 或 `/dev/video43` 的 `Could not requeue buffer`，说明兼容库没有被加载，请按第 13 节重新安装并彻底退出后重启腾讯会议。

如果所有应用都黑屏，再检查 GStreamer 插件：

```bash
gst-inspect-1.0 libcamerasrc
gst-inspect-1.0 videoconvert
gst-inspect-1.0 fdsink
```

直接验证物理摄像头：

```bash
qcam
```

再查看服务日志：

```bash
journalctl --user -u ipu6-virtual-camera.service -b --no-pager
```

### 内核升级后 v4l2loopback 消失

```bash
sudo dkms autoinstall
sudo depmod -a
sudo modprobe v4l2loopback
```

若 0.15.4 不再兼容未来内核，从 [v4l2loopback 官方仓库](https://github.com/v4l2loopback/v4l2loopback) 选择支持该内核的新版本，并相应修改 `/usr/src/v4l2loopback-<版本>` 和 DKMS 版本号。

## 16. 完整卸载或回滚

停止并禁用用户服务：

```bash
systemctl --user disable --now ipu6-virtual-camera.service
rm -f ~/.config/systemd/user/ipu6-virtual-camera.service
rm -f ~/.local/libexec/ipu6-camera-demand
rm -rf ~/.local/share/ipu6-camera
rm -rf ~/.local/lib/ipu6-camera
rm -f ~/.local/share/applications/com.qq.wemeet.desktop
rm -f ~/.local/share/applications/com.tencent.wechat.desktop
update-desktop-database ~/.local/share/applications
systemctl --user daemon-reload
```

移除模块自动加载配置：

```bash
sudo rm -f /etc/modules-load.d/ipu6-virtual-camera.conf
sudo rm -f /etc/modprobe.d/ipu6-virtual-camera.conf
sudo modprobe -r v4l2loopback
```

若连手工安装的 DKMS 模块也要删除：

```bash
sudo dkms remove -m v4l2loopback -v 0.15.4 --all
sudo rm -rf /usr/src/v4l2loopback-0.15.4
sudo depmod -a
```

恢复 Deepin 原始“相机”菜单入口：

```bash
rm -f ~/.local/share/applications/deepin-camera.desktop
update-desktop-database ~/.local/share/applications
```

## 17. 最终文件清单

正常工作时应存在：

```text
/etc/udev/rules.d/70-libcamera-udmabuf.rules
/etc/modules-load.d/ipu6-virtual-camera.conf
/etc/modprobe.d/ipu6-virtual-camera.conf
~/.config/systemd/user/ipu6-virtual-camera.service
~/.local/libexec/ipu6-camera-demand
~/.local/share/ipu6-camera/ipu6-camera-demand.c
~/.local/lib/ipu6-camera/wemeet-v4l2-fix.so
~/.local/share/ipu6-camera/wemeet-v4l2-fix.c
~/.local/share/applications/com.qq.wemeet.desktop
~/.local/share/applications/deepin-camera.desktop    # 可选
```

## 18. Redrix 内置麦克风修复（独立于摄像头）

本机还有一条独立的 SOF 音频问题。Google Redrix rev3 的 ACPI 描述内置麦克风为 `2ch-pdm0`，内核日志会出现：

```text
NHLT table not found
DMICs detected in NHLT tables: 0
```

对 Alder Lake/Brya 而言，缺少 NHLT 不能单独证明是故障，不要注入其他平台的 NHLT 表。本机实测的根因是：通用 UCM 暴露了无效 `Mic2`，PipeWire/WirePlumber 对四通道 `hw:0,99` 的默认初始化不稳定，且真实人声只在原始通道 1。全局启用的 `filter-chain.service` 还会抢占错误输入。以下是腾讯会议已经实际确认可用的低风险修复。

### 18.1 安装 Chromebook 音频基础配置

```bash
cd ~/Documents
git clone --depth 1 https://github.com/WeirdTreeThing/chromebook-linux-audio
cd chromebook-linux-audio
./setup-audio
```

Deepin 不在该项目当前列出的官方支持发行版中，但本机已成功安装。如脚本提示缺包，先按其输出安装依赖。

### 18.2 指定真实 DMIC 数量

创建 `/etc/modprobe.d/99-redrix-sof-microphone.conf`：

```bash
sudo tee /etc/modprobe.d/99-redrix-sof-microphone.conf >/dev/null <<EOF
# Redrix declares a two-channel microphone array on PDM0.
options snd_sof_intel_hda_generic dmic_num=2
EOF

sudo update-initramfs -u
reboot
```

重启后验证：

```bash
cat /sys/module/snd_sof_intel_hda_generic/parameters/dmic_num
```

预期输出 `2`。日志里仍出现 `DMICs detected in NHLT tables: 0` 不代表参数无效；该参数也只负责让驱动按两个 DMIC 处理，并不能单独解决 PipeWire 取流和通道映射问题。

### 18.3 隐藏无效 Mic2，提高 Mic1 优先级

创建 `/etc/wireplumber/wireplumber.conf.d/52-redrix-microphone.conf`：

```ini
monitor.alsa.rules = [
  {
    matches = [
      {
        node.name = "alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic2__source"
      }
    ]
    actions = {
      update-props = {
        node.disabled = true
      }
    }
  }
  {
    matches = [
      {
        node.name = "alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source"
      }
    ]
    actions = {
      update-props = {
        priority.session = 2500
      }
    }
  }
]
```

应用并选择真实输入：

```bash
systemctl --user restart wireplumber
pactl set-default-source \
  alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source
```

### 18.4 阻止错误的降噪代理再次抢占输入

本机的 `filter-chain.service` 是全局启用的用户服务，普通 `disable` 仍可能在下次登录时被全局预设拉起。为当前用户建立 mask：

```bash
systemctl --user mask --now filter-chain.service
systemctl --user daemon-reload
pactl set-default-source \
  alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source
```

这只关闭额外的降噪/虚拟麦克风代理，不会关闭 PipeWire、扬声器或耳机。检查：

```bash
systemctl --user is-enabled filter-chain.service   # masked
systemctl --user is-active filter-chain.service    # inactive
systemctl --user is-active pipewire pipewire-pulse wireplumber
pactl get-default-source
pactl list short sources
```

正常时，三个音频核心服务都是 `active`，可见的原始内置麦克风只有 `Mic1`。

### 18.5 绕过不稳定的 UCM 四通道父节点

直接 ALSA 实测确认 `hw:0,99` 必须以 `S32_LE / 48000 Hz / 4ch` 打开：通道 1 含清晰人声，通道 0 非常小，通道 2/3 是无效直流电平。WirePlumber 默认 UCM 父节点曾使取流退化为底噪，因此创建 `~/.config/wireplumber/wireplumber.conf.d/53-redrix-direct-dmic.conf`：

```ini
monitor.alsa.rules = [
  {
    matches = [
      {
        node.name = "alsa_input.hw_sofrt5682_99"
      }
    ]
    actions = {
      update-props = {
        node.disabled = true
      }
    }
  }
]
```

### 18.6 按成功的 ALSA 参数创建单声道直连源

创建 `~/.config/pipewire/pipewire-pulse.conf.d/60-redrix-internal-microphone.conf`：

```ini
# Open the DMIC exactly like the successful direct ALSA capture, then export
# raw channel 1 as mono. Both layers suspend when no client is recording.
pulse.cmd = [
  {
    cmd = "load-module"
    args = "module-alsa-source device=hw:0,99 source_name=redrix_raw4 format=s32le rate=48000 channels=4 channel_map=aux0,aux1,aux2,aux3 fragments=4 fragment_size=4096 source_properties=device.description=Redrix_RAW_DO_NOT_SELECT"
    flags = [ nofail ]
  }
  {
    cmd = "load-module"
    args = "module-remap-source master=redrix_raw4 source_name=redrix_direct_mic channels=1 master_channel_map=aux1 channel_map=mono remix=no source_properties=device.description=Redrix_Direct_Microphone"
    flags = [ nofail ]
  }
]
```

应用配置，为最终源增加数字增益，并把它设为系统默认麦克风：

```bash
systemctl --user restart wireplumber.service pipewire-pulse.service
pactl set-source-volume redrix_direct_mic 400%
pactl set-default-source redrix_direct_mic
```

`400%` 在本机 PulseAudio 刻度上等于约 `+21.67 dB`，并会由 `module-device-restore` 记住，重启 PipeWire-Pulse 后仍能恢复。把 `redrix_direct_mic` 设为默认后，遵循系统默认输入源的普通应用也能使用有效通道；应用若提供麦克风列表，仍建议明确选择 `Redrix_Direct_Microphone`。

> **Deepin 语音记事本限制：** `redrix_direct_mic` 是没有 PulseAudio 硬件端口的 remap 源，而语音记事本只接受默认源中带硬件端口的设备，因此会提示“未检测到录音设备”。若临时把原始 Mic1 设为默认，按钮会出现，但应用会显式连接到错误的原始 Mic1，录音仍没有有效人声。实测在录制中执行 `pactl move-source-output` 也没有得到可靠录音，不能作为解决方案。本文最终支持范围是腾讯会议等允许选择麦克风、或能正确遵循系统默认输入源的应用。要兼容语音记事本，需要另行实现带 ALSA 硬件端口的 `snd-aloop` 虚拟麦克风。

检查：

```bash
pactl list short modules | grep -E 'module-alsa-source|module-remap-source'
pactl list short sources | grep -E 'Mic1|redrix'
pactl get-source-volume redrix_direct_mic
pactl get-default-source
```

预期同时出现：

- `redrix_raw4`：内部四通道源，名称为 `Redrix_RAW_DO_NOT_SELECT`，不要在应用中选它；
- `redrix_direct_mic`：最终 `1ch/48000 Hz` 麦克风，应用中显示为 `Redrix_Direct_Microphone`。

两层空闲时都是 `SUSPENDED`，`fuser /dev/snd/pcmC0D99c` 无输出；只有应用实际录音时才打开底层 DMIC。

### 18.7 腾讯会议选择与验证

腾讯会议中建议手动选择 `Redrix_Direct_Microphone`。不要选 `Redrix_RAW_DO_NOT_SELECT` 或原始 Mic1；当前“系统默认”也指向直连麦克风，但明确选择设备名可以避免应用缓存旧的默认源。

命令行单独录音验证：

```bash
timeout 10 pw-record \
  --target redrix_direct_mic \
  /tmp/redrix-mic-test.wav

ffmpeg -hide_banner -i /tmp/redrix-mic-test.wav \
  -af astats=metadata=1:reset=0 -f null - 2>&1 | \
  grep -E "Channel:|Peak level dB|RMS level dB"
```

本机在 2026-09-25 与腾讯会议并行录音时，实测人声峰值约 `-22.25 dB`、RMS 约 `-41.04 dB`。`Wemeet VoiceEngine/RecordStream` 显示 `target.object = redrix_direct_mic`、`pulse.corked = false`，用户已确认腾讯会议输入可用。

### 18.8 回滚麦克风修改

```bash
sudo rm -f /etc/modprobe.d/99-redrix-sof-microphone.conf
sudo rm -f /etc/wireplumber/wireplumber.conf.d/52-redrix-microphone.conf
rm -f ~/.config/wireplumber/wireplumber.conf.d/53-redrix-direct-dmic.conf
rm -f ~/.config/pipewire/pipewire-pulse.conf.d/60-redrix-internal-microphone.conf
systemctl --user unmask filter-chain.service
systemctl --user daemon-reload
systemctl --user restart pipewire-pulse.service
sudo update-initramfs -u
reboot
```

只有确定要恢复系统默认降噪代理时，才执行 `unmask`。

## 19. 最终麦克风文件清单

```text
/etc/modprobe.d/99-redrix-sof-microphone.conf
/etc/wireplumber/wireplumber.conf.d/52-redrix-microphone.conf
~/.config/wireplumber/wireplumber.conf.d/53-redrix-direct-dmic.conf
~/.config/pipewire/pipewire-pulse.conf.d/60-redrix-internal-microphone.conf
~/.config/systemd/user/filter-chain.service -> /dev/null
```
