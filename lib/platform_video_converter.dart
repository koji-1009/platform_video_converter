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
  /// Converts the [input] video based on the provided [config].
  ///
  /// Returns a [Future] that resolves to an [XFile] pointing to the converted video.
  ///
  /// **Platform Specific notes:**
  ///
  /// *   **Android/iOS/macOS**: The returned [XFile] points to a temporary file on the device.
  ///     The file is located in the application's temporary directory and should be managed
  ///     or cleaned up using [cleanup] when no longer needed.
  ///
  /// *   **Web**: The returned [XFile] contains a **Blob URL** in its `path` property.
  ///     **Important**: To prevent memory leaks, you must clean up this URL using [cleanup]
  ///     when it is no longer needed.
  static Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  }) async {
    final platform = _getPlatformForTarget(defaultTargetPlatform);
    return platform.convert(input: input, config: config);
  }

  /// Cleans up the output file/resource.
  ///
  /// Call this method when the converted video file is no longer needed.
  ///
  /// *   **Android/iOS/macOS**: Deletes the temporary file from the device storage.
  /// *   **Web**: Revokes the Blob URL to release memory.
  static Future<void> cleanup(XFile file) async {
    final platform = _getPlatformForTarget(defaultTargetPlatform);
    return platform.cleanup(file);
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
