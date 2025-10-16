---
title: Multimedia入门知识
date: 2021-11-19
lastmod: 2021-11-26
slug: 44db14a
draft: false
author:
  name: tryao
tags: ["media"]
collections: []
toc: true
math: true
lightgallery: false
---

毕业之后基本没搞过图像，最近做视频相关项目，复习补充一下基本知识。

<!--more-->

## 图像

任意色彩都可以用三个基色的强度来描述，最常用的就是RGB三原色，通过红黄蓝三种颜色调整强度来叠加出所有其他颜色。

CYM则是另一种描述的思路：人类在自然界中能看到颜色，是因为有光（太阳光是白色）照射到物体表面，物体吸收了其中一部分波，剩下的被物体反射到人眼中。人眼看到的颜色=白色-物体吸收的颜色，因此如果要打印一张照片，需要考虑的不是rgb，而是CYM。实际使用中一般是C(青)Y(黄)M(酒红)K(黑色)，即所谓的印刷四分色（这是因为CYM无法混合出纯黑）。需要注意的是CYMK能描述的色彩空间比RGB小得多，这也是为啥打印出来经常会失真的原因。

在计算机中，二维图像由像素矩阵构成（即对图像进行数字化采样），每个像素点对应着色彩空间中RGB的信息，每种基色一个字节(0~255)，因此每个像素点需要3个字节。直接用RGB存放图像，缺点是图像体积过大，带宽/硬盘/内存资源消耗较大。特别地，当R=G=B=0时，显示黑色；R=G=B=255时，显示白色。如果在三原色基础上加上透明度(alpha, 0表示不透明)通道，即所谓的RGBA色彩空间，png使用该色彩空间描述。

YUV（Y:明亮度，UV:色度）是另外一种图片编码方法，也是默认的图片/视频压缩编码。对于YUV图像来说，并不是每个像素点都需要包含Y、U、V三个分量，常用的有`4:2:2`,`4:4:4`和`4:2:0`，这决定了Y分量和UV分量的比例，如果没有UV分量，图片是黑白的。最常用的是`4:2:0`和`4:1:1`. 所谓`4:2:0`，指的是在`每一行`扫描时，只`扫描`一种`U/V其中一种色度分量`，而`Y`按照`2:1`的方式采样。YCC(YCbCr)是YUV家族的一员，也是数字时代实际使用最常用的编码方案，jpg一般采用YCC描述。模拟时代的YPP基本已经不提了。

需要注意的是，在硬件设备真正渲染显示时，YUV需要转换为RGB。

图像深度(depth)，指的是图像里用来表示一个像素点的颜色由几位构成，比如24位图像深度的1920x1080的高清图像，就表示这个高清图像它所占空间是（1920x1080x24bit/8）kb，也就是：1920x1080x3 kb；

图像通道(channels)，channels*8=depth，也就说图像深度除8Bit就是图像通道数；

图像跨度(stride)就是图像一行所占长度，一般大于等于图像的宽度；

## 声音

声波是一种一维机械波，声波通过声电转换器转换为电波（模拟量），并经过采样变成数字信号（模数转换），数字信号经过调制(PCM/PDM)之后进行存储，就是我们常见的音频文件。其中PCM对应的音频文件就是WAV格式，PDM对应DSD格式，后者比较少见。

PCM的音质在频率上受限于其采样率，根据Nyquist采样定理，两倍以上的采样率可以真实还原出原波形，所以考虑到人耳的听力最高到20kHz，通常PCM音频的采样率都在40kHz以上（如常见的44.1kHz和48kHz）；在振幅上受限于其采样位深。因此采样率低会导致声音高频被裁掉，而采样位深低会导致振幅分辨率下降，音频的动态范围下降，这两者共同导致音频的失真。

原始wav格式体积过大，因此需要压缩。无损压缩的音频格式包括常见的FLAC/AALC/APE/TAK/WavPack，而有损的则包括常见的AAC/MP3/OGG/WMA等。

声音在采样之后，需要进行量化，即声音的分辨率，指的是声音的连续强度被数字表示后可以分为多少级。一般用8/16bit表示，2个字节已经是cd音质了。将量化后的结果进行二进制编码，可以选用整数或者浮点数，显然后者的精度更高。

音频数据是流式的，本身没有明确的一帧帧的概念，在实际的应用中，为了音频算法处理/传输的方便，一般约定俗成取2.5ms~60ms为单位的数据量为一帧音频。这个时间被称之为“采样时间”，其长度没有特别的标准，它是根据编解码器和具体应用的需求来决定的。

多声道音频，体积是单声道的N倍，因为每个声道需要单独存储，最后输出到音响中。多声道是人头模拟技术，为了制造更好的临场感。

## 视频

视频是对图像、音频和时间轴的整合（这里不讨论字幕）。视频编码常见的包括：

![截屏2021-11-19 17.00.39](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNly1gwkkeqgxiuj30uy0l4ad2.jpg)

在监控领域常见的是H.264/H.265.

视频画面原始的图像显然是YUV格式，H264对原始流再次编码压缩。播放器播放的时候需要将其还原成YUV（进一步还原成RGB）才能被人眼感知。

视频帧中真正的图像数据，被称为I帧（即**Intra**关键帧）；除了I帧之外，还有P（**predictive**，前向预测）帧和B帧（**bi-directional**，双向预测帧）。可以理解P/B帧都是为了进一步压缩视频，存储的不是全量数据，而是差量。

有一种特殊的I帧，称为IDR帧（**Instantaneous Decoding Refresh**），作用是立即刷新图像，不再使用P/B帧解码。

音视频同步编码，需要保证在解码时二者一致，这涉及两个概念：

- **DTS**，英文全称**Decoding Time Stamp**，即解码时间戳，这个时间戳的意义在于告诉解码器该在什么时候解码这一帧的数据。
- **PTS**，英文全称**Presentation Time Stamp**，即显示时间戳，这个时间戳用来告诉播放器该在什么时候显示这一帧的数据。

GOP：Group Of Pictures，即一组图像。在码率不变的前提下，GOP值越大，P帧、B帧的数量会越多，平均每个I帧、P帧、B帧所占用的字节数就越多，也就更容易获取较好的图像质量；Reference越大，B帧的数量越多，同理也更容易获得较好的图像质量。

将音视频和字幕元素按时间轨进行组合存储，再加上一些播放信息、头尾描述等，就是所谓的封装。视频封装格式就是我们常见的文件名后缀，如mp4, avi, mkv等。

流媒体协议：如RTP/RTMP，指的是基于TCP/UDP网络协议传输流媒体数据的网络协议。RTP是基于UDP的，配合RTCP对服务质量进行控制，SRTCP在RTCP的基础上加入加密/身份认证功能。RTSP则是构建于RTP/RTCP之上，不同的是它还可以选择用TCP传输数据。

RTMP/MMS是上个世代的主要流媒体传输协议，前者是Flash时代最重要的流媒体传输协议，后者则是微软的发明。HLS则是苹果的发明，但是其基于HTTP协议，所以具有天然的跨平台能力，也是web前端最容易使用的协议，只是延迟会比其他协议都要高。

## 框架

多媒体相关，最有名的库就是FFmpeg和OpenCV，前者主要是各种解码/转码；后者主要是各种算法处理。

多媒体涉及的数据量极大，所以相关计算非常耗费CPU，所有框架目前还是以C++为主。但是目前公司研发主要以Java为主，所以下面的描述主要是参考了JavaCV的实现，后者封装了FFMpeg/OpenCV的一些通用操作，并进行了抽象。

对流媒体的一般处理流程如下：

> 视频源—->帧抓取器（FrameGabber） —->抓取视频帧（Frame）—->帧录制器（FrameRecorder）—->推流/录制—>帧过滤器(FrameFilter，滤镜)—->流媒体服务/录像文件

为了方便调试，可以使用CanvasFrame工具类预览图像。

### FFMpeg

Frame表示一帧数据(其实就是FFMpeg中的AVFrame)，上面已经说过，一帧其实就是一段数据。默认情况下，一帧数据里面包括音频的PCM采样和视频的YUV4:2:0按jpg存储的数据。JavaCV的Frame对象里面含有音视频的基本属性，其`opaque`对象对应原始的FFMpeg帧。

FFMpeg中`AVPacket`是原始帧，未经解码（即H264等编码帧），包含数据为：

- pts: 显示时间
- dts: 解码时间
- duration: 持续时长
- stream_index: 表示音视频流的通道，音频和视频一般是分开的，通过stream_index来区分是视频帧还是音频帧
- flags: AV_PKT_FLAG_KEY，1-关键帧，2-损坏数据，4-丢弃数据
- pos: 在流媒体中的位置
- size：帧大小

对应的，AVFrame就是解码后的帧（含有YUV/PCM数据），其包含的数据在AVPacket的基础上多了一些解码后的属性数据。

使用`FFmpegFrameRecorder`进行音视频的录制、编解码、封装和推流。

转封装流程如下：

> FFmpegFrameRecorder初始化–>start()–>循环recordPacket(AVPacket)–>close()

编码流程如下：

> FFmpegFrameRecorder初始化–>start()–>循环record(Frame)/recordImage()/recordSamples()–>close()

### OpenCV

JavaCV的封装是按着接口的思路来的，因此OpenCV的处理逻辑和FFMpeg其实是一致的，但是需要注意OpenCV不处理音频数据。显然OpenCV抓取的Frame，其`opaque`对象应该是一个OpenCV中的`Mat`，也可以通过`OpenCVFrameConverter`手动将`Mat`转换为`Frame`。

### 基本流程

```
//解码流程
FFmpegFrameGrabber grabber = new FFmpegFrameGrabber(url); //创建一个拉流器，url可以是音视频文件后者流媒体地址
grabber.start();//初始化，网络不好可能会阻塞，会读取一些音视频分析得到音视频格式编码信息等
for(;;){
  //该操作完成了解协议，解封装/解复用和解码操作，默认得到的图像是yuv像素，音频则是pcm采样。
  Frame frame=grabber.grab();
  //如果仅仅是转封装
  AVPacket avFrame = grabber.grabPacket();
}
```

上面是简单的抓流、解码过程。如果需要推流，也很简单，增加一个Recorder即可：

```
//推流转码流程
FFmpegFrameGrabber grabber = new FFmpegFrameGrabber(url);//创建一个拉流器，url可以是音视频文件
FFmpegFrameRecorder recorder = new FFmpegFrameRecorder(url);//创建一个推流器，url可以是音视频文件后者流媒体地址
grabber.start();//初始化，网络不好可能会阻塞，会读取一些音视频分析得到音视频格式编码信息等
recorder.start();//初始化，会读取一些推流地址信息
for(;;){
  //该操作完成了解协议，解封装/解复用和解码操作，默认得到的图像是yuv像素，音频则是pcm采样。
  Frame frame=grabber.grab();
  //将解码后的帧推流到recorder中指定的url地址
  recorder.record(frame);
}
```

上文中奖url改成本地文件地址，就是录制成文件了。如果仅仅需要推流，不需要解码，那就是完全复用grabber中的上下文：

```
//推流封装流程
FFmpegFrameGrabber grabber = new FFmpegFrameGrabber(url);//创建一个拉流器，url可以是音视频文件
FFmpegFrameRecorder recorder = new FFmpegFrameRecorder(url);//创建一个推流器，url可以是音视频文件后者流媒体地址
grabber.start();//初始化，网络不好可能会阻塞，会读取一些音视频分析得到音视频格式编码信息等
recorder.start(grabber.getFormatContext());//初始化，由于是复用/封装流程，推流器需要拉流器的格式上下文信息才能初始化

for(;;){
  //该操作完成了解协议，解封装操作
  AVPacket pkt=grabber.grabPacket();
  //该操作完成了复用/封装推流，并不涉及编解码
  recorder.recordPacket(pkt);
}
```

这里就没有解码的流程了。

上文中的Grabber参数中的url，都可以改成本地文件地址，这样就变成从文件中获取视频流了。recorder在推流之前可以设置各种编码格式，如：

```
recorder.setFormat("flv");//设置视频封装格式是flv
recorder.setVideoCodec(avcodec.AV_CODEC_ID_H264); // 设置h264编码
recorder.setAudioCodec(avcodec.AV_CODEC_ID_AAC);//设置aac编码
```
