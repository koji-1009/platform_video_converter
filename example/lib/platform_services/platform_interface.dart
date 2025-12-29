import 'package:cross_file/cross_file.dart';
import 'package:video_player/video_player.dart';

abstract class PlatformServices {
  const PlatformServices();

  /// Create a VideoPlayerController appropriate for the platform
  VideoPlayerController createVideoPlayerController(XFile file);

  // Output file preparation is now handled internally by the package

  /// Save the converted file to the gallery or trigger download
  Future<String> saveResult(XFile resultFile);

  /// Whether the platform supports saving to gallery
  bool get canSaveToGallery;
}
