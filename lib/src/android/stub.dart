import 'package:cross_file/cross_file.dart';
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';

final class VideoConverterAndroid implements VideoConverterPlatform {
  const VideoConverterAndroid();

  @override
  Future<void> convert({
    required XFile input,
    required XFile output,
    VideoConfig config = const VideoConfig(),
  }) async => throw UnimplementedError();
}
