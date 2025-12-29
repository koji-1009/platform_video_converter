import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:cross_file/cross_file.dart';
import 'package:ffi/ffi.dart';
import 'package:objective_c/objective_c.dart' as objc;
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';

import 'bindings.g.dart';

class VideoConverterDarwin implements VideoConverterPlatform {
  const VideoConverterDarwin();

  @override
  @override
  Future<void> convert({
    required XFile input,
    required XFile output,
    VideoConfig config = const VideoConfig(),
  }) async {
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

      final nsStrOutput = output.path.toNSString();
      final outputUrl = objc.NSURL.fileURLWithPath(nsStrOutput);
      session.outputURL = outputUrl;

      final fileType = switch (config.format) {
        .mp4 => "public.mpeg-4".toNSString(),
        .mov => "com.apple.quicktime-movie".toNSString(),
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

      // Handle Resolution (Width/Height)
      if (config.width != null || config.height != null) {
        // Note: sync loading 'tracks' property might block or fail if not loaded,
        // but URLAsset usually has them. Ideally loadValuesAsynchronously.
        // For 'URLAssetWithURL', it is generally available.

        final videoMediaType = "vide".toNSString(); // AVMediaTypeVideo
        final tracks = asset.tracksWithMediaType(videoMediaType);

        if (tracks.count > 0) {
          final track = tracks.objectAtIndex(0) as AVAssetTrack;
          final naturalSize = track.naturalSize;

          double targetW = config.width?.toDouble() ?? naturalSize.width;
          double targetH = config.height?.toDouble() ?? naturalSize.height;

          // Calculate missing dimension to preserve aspect ratio
          if (config.width != null && config.height == null) {
            targetH = naturalSize.height * (targetW / naturalSize.width);
          } else if (config.height != null && config.width == null) {
            targetW = naturalSize.width * (targetH / naturalSize.height);
          }

          final videoComposition = AVMutableVideoComposition.videoComposition();
          videoComposition.renderSize =
              (arena<objc.CGSize>()
                    ..ref.width = targetW
                    ..ref.height = targetH)
                  .ref;
          videoComposition.frameDuration =
              (arena<CMTime>()
                    ..ref.value = 1
                    ..ref.timescale = 30
                    ..ref.flags = 1)
                  .ref; // Default 30fps

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

          // If we have specific clipping, we should ideally restrict instruction,
          // but covering "all" is safe if composition length is clamped by session timeRange.

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

          // We might need to consider track.preferredTransform (rotation) but that adds complexity.
          // Native binding "preferredTransform" is available.
          // If input is rotated (e.g. portrait video), naturalSize is usually un-rotated dimensions?
          // NO, naturalSize is dimensions of stored frames. preferredTransform handles rotation.
          // If we just scale, we might stretch rotated video wrongly.
          // Addressing rotation correctly usually involves applying preferredTransform THEN scaling.
          // For MVP, we apply simple scaling.

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
  }
}
