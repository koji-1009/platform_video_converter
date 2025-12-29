import 'package:cross_file/cross_file.dart';
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';

final class VideoConverterAndroid implements VideoConverterPlatform {
  const VideoConverterAndroid();

  @override
  Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  }) async => throw UnimplementedError();
}
