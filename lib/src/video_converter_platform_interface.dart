import 'package:cross_file/cross_file.dart';
import 'package:platform_video_converter/src/models.dart';

abstract interface class VideoConverterPlatform {
  Future<void> convert({
    required XFile input,
    required XFile output,
    VideoConfig config = const VideoConfig(),
  });
}
