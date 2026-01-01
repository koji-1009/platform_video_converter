import 'package:cross_file/cross_file.dart';
import 'package:platform_video_converter/src/models.dart';

abstract interface class VideoConverterPlatform {
  /// Perform the video conversion.
  ///
  /// Implementations should handle the platform-specific conversion logic
  /// and return an [XFile] representing the result.
  Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  });

  /// Cleanup the output file/resource.
  Future<void> cleanup(XFile file);
}
