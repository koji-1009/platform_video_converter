import 'package:cross_file/cross_file.dart';
import 'package:video_player/video_player.dart';

import 'platform_interface.dart';

class PlatformServicesWeb extends PlatformServices {
  const PlatformServicesWeb();

  @override
  VideoPlayerController createVideoPlayerController(XFile file) {
    // On Web, file.path is a Blob URL
    return VideoPlayerController.networkUrl(Uri.parse(file.path));
  }

  @override
  Future<XFile> prepareOutputFile() async {
    // On Web, we can't write to arbitrary paths. Use a placeholder.
    return XFile('output.mp4');
  }

  @override
  Future<String> saveResult(XFile resultFile) async {
    // Web implementation handles download automatically.
    return 'Downloaded automatically.';
  }

  @override
  bool get canSaveToGallery => false;
}

PlatformServices getPlatformServices() => const PlatformServicesWeb();
