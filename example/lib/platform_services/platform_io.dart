import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

import 'platform_interface.dart';

class PlatformServicesIO extends PlatformServices {
  const PlatformServicesIO();

  @override
  VideoPlayerController createVideoPlayerController(XFile file) {
    return VideoPlayerController.file(File(file.path));
  }

  @override
  Future<String> saveResult(XFile resultFile) async {
    await Gal.putVideo(resultFile.path);
    return 'Saved to Gallery: ${resultFile.path}';
  }

  @override
  bool get canSaveToGallery => true;
}

PlatformServices getPlatformServices() => const PlatformServicesIO();
