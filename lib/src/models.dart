enum VideoFormat { mp4, mov }

class VideoConfig {
  const VideoConfig({
    this.format = VideoFormat.mp4,
    this.width,
    this.height,
    this.bitrate,
    this.startTime,
    this.endTime,
  });

  final VideoFormat format;
  final int? width;
  final int? height;
  final int? bitrate;
  final Duration? startTime;
  final Duration? endTime;
}
