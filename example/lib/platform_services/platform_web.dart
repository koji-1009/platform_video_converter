import 'package:cross_file/cross_file.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'platform_interface.dart';

class PlatformServicesWeb extends PlatformServices {
  const PlatformServicesWeb();

  @override
  VideoPlayerController createVideoPlayerController(XFile file) {
    // On Web, file.path is a Blob URL
    return VideoPlayerController.networkUrl(Uri.parse(file.path));
  }

  // prepareOutputFile removed

  @override
  Future<String> saveResult(XFile resultFile) async {
    // On Web, the XFile contains the Blob URL in its path (if valid) or we can just trigger download.
    // Assuming resultFile.path is a blob URL.
    final url = resultFile.path;
    final name = resultFile.name.isNotEmpty ? resultFile.name : 'output.mp4';

    web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..click();

    return 'Download started.';
  }

  @override
  bool get canSaveToGallery => false;
}

PlatformServices getPlatformServices() => const PlatformServicesWeb();
