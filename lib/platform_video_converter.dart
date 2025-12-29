library;

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_video_converter/src/android/shared.dart';
import 'package:platform_video_converter/src/darwin/shared.dart';
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';
import 'package:platform_video_converter/src/web/shared.dart';

export 'package:cross_file/cross_file.dart';

export 'src/models.dart';

abstract final class VideoConverter {
  static Future<void> convert({
    required XFile input,
    required XFile output,
    VideoConfig config = const VideoConfig(),
  }) async {
    final platform = _getPlatformForTarget(defaultTargetPlatform);
    await platform.convert(input: input, output: output, config: config);
  }
}

VideoConverterPlatform _getPlatformForTarget(TargetPlatform platform) {
  if (kIsWeb) {
    return const VideoConverterWeb();
  }

  return switch (platform) {
    TargetPlatform.android => const VideoConverterAndroid(),
    TargetPlatform.iOS || TargetPlatform.macOS => const VideoConverterDarwin(),
    _ => throw UnsupportedError(
      'Video conversion is not supported on this platform: $platform',
    ),
  };
}
