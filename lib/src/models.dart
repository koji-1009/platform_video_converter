/// Supported output video formats.
enum VideoFormat {
  /// MPEG-4 Part 14 container (.mp4).
  /// Supported on all platforms.
  mp4,

  /// QuickTime File Format (.mov).
  /// Primarily for Apple platforms. Support on Web/Android varies.
  mov,
}

/// Configuration options for video conversion.
class VideoConfig {
  /// Creates a new configuration.
  const VideoConfig({
    this.format = VideoFormat.mp4,
    this.width,
    this.height,
    this.bitrate,
    this.startTime,
    this.endTime,
  });

  /// The output container format. Defaults to [VideoFormat.mp4].
  final VideoFormat format;

  /// The target video width in pixels.
  ///
  /// If [width] is provided but [height] is null, the height is calculated
  /// to maintain the original aspect ratio.
  final int? width;

  /// The target video height in pixels.
  ///
  /// If [height] is provided but [width] is null, the width is calculated
  /// to maintain the original aspect ratio.
  final int? height;

  /// The target video bitrate in bits per second (bps).
  ///
  /// If null, the platform default or original bitrate is used.
  final int? bitrate;

  /// The start time for clipping the video.
  ///
  /// If provided, the video will be trimmed to start from this duration.
  final Duration? startTime;

  /// The end time for clipping the video.
  ///
  /// If provided, the video will be trimmed to end at this duration.
  final Duration? endTime;
}
