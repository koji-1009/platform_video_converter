import 'package:cross_file/cross_file.dart';
import 'package:platform_video_converter/src/models.dart';

abstract interface class VideoConverterPlatform {
  Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  });
}
