import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:ffi/ffi.dart';
import 'package:objective_c/objective_c.dart' as objc;
import 'package:path_provider/path_provider.dart';
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';

import 'bindings.g.dart';

class VideoConverterDarwin implements VideoConverterPlatform {
  const VideoConverterDarwin();

  @override
  Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  }) async {
    // Generate internal temp file
    final tempDir = await getTemporaryDirectory();
    final outputName = 'converted_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final outputFilePath = '${tempDir.path}/$outputName';

    await using((arena) async {
      final nsStrInput = input.path.toNSString();
      final inputUrl = objc.NSURL.fileURLWithPath(nsStrInput);

      final emptyDict = objc.NSDictionary.dictionary();
      final asset = AVURLAsset.URLAssetWithURL(inputUrl, options: emptyDict);

      final preset = "AVAssetExportPresetHighestQuality".toNSString();

      final session = AVAssetExportSession.exportSessionWithAsset(
        asset,
        presetName: preset,
      );

      final nsStrOutput = outputFilePath.toNSString();
      final outputUrl = objc.NSURL.fileURLWithPath(nsStrOutput);
      session.outputURL = outputUrl;

      final fileType = switch (config.format) {
        VideoFormat.mp4 => "public.mpeg-4".toNSString(),
        VideoFormat.mov => "com.apple.quicktime-movie".toNSString(),
        VideoFormat.webm => throw UnsupportedError(
          "WebM is not supported on iOS/macOS",
        ),
      };
      session.outputFileType = fileType;

      // Handle Clipping
      if (config.startTime != null || config.endTime != null) {
        final startMs = config.startTime?.inMilliseconds ?? 0;
        final endMs = config.endTime?.inMilliseconds ?? 360000000;
        final durationMs = endMs - startMs;

        if (durationMs > 0) {
          final range = arena<CMTimeRange>();
          range.ref.start.value = startMs;
          range.ref.start.timescale = 1000;
          range.ref.start.flags = 1;
          range.ref.duration.value = durationMs;
          range.ref.duration.timescale = 1000;
          range.ref.duration.flags = 1;
          session.timeRange = range.ref;
        }
      }

      // Handle Resolution (Width/Height) and Frame Rate
      if (config.width != null || config.height != null || config.fps != null) {
        // Note: sync loading 'tracks' property might block or fail if not loaded,
        // but URLAsset usually has them. Ideally loadValuesAsynchronously.
        // For 'URLAssetWithURL', it is generally available.

        final videoMediaType = "vide".toNSString(); // AVMediaTypeVideo
        final tracks = asset.tracksWithMediaType(videoMediaType);

        if (tracks.count > 0) {
          final track = tracks.objectAtIndex(0) as AVAssetTrack;
          final naturalSize = track.naturalSize;
          final nominalFrameRate =
              track.nominalFrameRate; // Requires updated bindings

          double targetW = config.width?.toDouble() ?? naturalSize.width;
          double targetH = config.height?.toDouble() ?? naturalSize.height;

          // Aspect ratio calculation
          if (config.width != null && config.height == null) {
            targetH = naturalSize.height * (targetW / naturalSize.width);
          } else if (config.height != null && config.width == null) {
            targetW = naturalSize.width * (targetH / naturalSize.height);
          }

          // Determine FPS
          final sourceFps = nominalFrameRate > 0 ? nominalFrameRate : 30.0;
          final targetFps = config.fps?.toDouble() ?? sourceFps;
          final fpsInt = targetFps.toInt();

          final videoComposition = AVMutableVideoComposition.videoComposition();
          videoComposition.renderSize =
              (arena<objc.CGSize>()
                    ..ref.width = targetW
                    ..ref.height = targetH)
                  .ref;
          videoComposition.frameDuration =
              (arena<CMTime>()
                    ..ref.value = 1
                    ..ref.timescale = fpsInt
                    ..ref.flags = 1)
                  .ref;

          final instruction =
              AVMutableVideoCompositionInstruction.videoCompositionInstruction();
          instruction.timeRange =
              (arena<CMTimeRange>()
                    ..ref.start.value = 0
                    ..ref.start.timescale = 1000
                    ..ref.start.flags = 1
                    ..ref.duration.value =
                        360000000 // Covers long duration
                    ..ref.duration.timescale = 1000
                    ..ref.duration.flags = 1)
                  .ref;

          final layerInstruction =
              AVMutableVideoCompositionLayerInstruction.videoCompositionLayerInstructionWithAssetTrack(
                track,
              );

          // Calculate Transform
          // Scale = Target / Source
          final sx = targetW / naturalSize.width;
          final sy = targetH / naturalSize.height;

          final transform = arena<CGAffineTransform>();
          // MakeScale(sx, sy)
          transform.ref.a = sx;
          transform.ref.b = 0;
          transform.ref.c = 0;
          transform.ref.d = sy;
          transform.ref.tx = 0;
          transform.ref.ty = 0;

          final zeroTime = arena<CMTime>()
            ..ref.value = 0
            ..ref.timescale = 1000
            ..ref.flags = 1;
          layerInstruction.setTransform(transform.ref, atTime: zeroTime.ref);

          final instructionsArr = objc.NSMutableArray.array();
          instructionsArr.addObject(instruction);
          // layerInstructions
          final layerInstructionsArr = objc.NSMutableArray.array();
          layerInstructionsArr.addObject(layerInstruction);

          instruction.layerInstructions = layerInstructionsArr;

          videoComposition.instructions = instructionsArr;

          session.videoComposition = videoComposition;
        }
      }

      // Handle Audio Control (Mute/Volume)
      if (config.isMuted || config.scale != 1.0) {
        final audioMediaType = "soun".toNSString(); // AVMediaTypeAudio
        final audioTracks = asset.tracksWithMediaType(audioMediaType);

        if (audioTracks.count > 0) {
          final audioMix = AVMutableAudioMix.audioMix();
          final inputParamsArray = objc.NSMutableArray.array();

          for (int i = 0; i < audioTracks.count; i++) {
            final track = audioTracks.objectAtIndex(i) as AVAssetTrack;
            final inputParams =
                AVMutableAudioMixInputParameters.audioMixInputParametersWithTrack(
                  track,
                );

            final targetVolume = config.isMuted ? 0.0 : config.scale;
            final zeroTime = arena<CMTime>()
              ..ref.value = 0
              ..ref.timescale = 1000
              ..ref.flags = 1;

            inputParams.setVolume(
              targetVolume.toDouble(),
              atTime: zeroTime.ref,
            );
            inputParamsArray.addObject(inputParams);
          }

          audioMix.inputParameters = inputParamsArray;
          session.audioMix = audioMix;
        }
      }

      session.exportAsynchronouslyWithCompletionHandler(ffi.nullptr);

      // Polling loop since we didn't pass a completion block
      while (true) {
        switch (session.status) {
          case AVAssetExportSessionStatus.AVAssetExportSessionStatusCompleted:
            return;
          case AVAssetExportSessionStatus.AVAssetExportSessionStatusFailed:
            final error = session.error;
            throw Exception("Export failed: $error");
          case AVAssetExportSessionStatus.AVAssetExportSessionStatusCancelled:
            throw Exception("Export cancelled");
          default:
            // Wait a bit
            await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    });

    return XFile(outputFilePath);
  }

  @override
  Future<void> cleanup(XFile file) async {
    final ioFile = File(file.path);
    if (await ioFile.exists()) {
      await ioFile.delete();
    }
  }
}
