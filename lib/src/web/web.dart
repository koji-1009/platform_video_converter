import 'dart:async';
import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';
import 'package:web/web.dart' as web;

final class VideoConverterWeb implements VideoConverterPlatform {
  const VideoConverterWeb();

  @override
  Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  }) async {
    final bytes = await input.readAsBytes();
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);

    final videoElement =
        web.document.createElement('video') as web.HTMLVideoElement
          ..src = url
          ..muted = true
          ..autoplay = false
          ..crossOrigin = "anonymous";

    // Wait for metadata to load
    final metadataCompleter = Completer<void>();
    StreamSubscription<web.Event>? metadataSub;
    metadataSub = web.EventStreamProviders.loadedMetadataEvent
        .forTarget(videoElement)
        .listen((_) {
          metadataSub?.cancel();
          metadataCompleter.complete();
        });
    // In case of error
    StreamSubscription<web.Event>? errorSub;
    errorSub = web.EventStreamProviders.errorEvent
        .forTarget(videoElement)
        .listen((_) {
          errorSub?.cancel();
          metadataCompleter.completeError(
            Exception("Failed to load video metadata"),
          );
        });

    await metadataCompleter.future;
    errorSub.cancel();

    final originalWidth = videoElement.videoWidth;
    final originalHeight = videoElement.videoHeight;
    final durationMs = (videoElement.duration * 1000).toInt();

    // Determine target resolution
    int targetWidth = config.width ?? originalWidth;
    int targetHeight = config.height ?? originalHeight;

    // Aspect ratio calculation if one dimension is missing
    if (config.width != null && config.height == null) {
      targetHeight = (originalHeight * (targetWidth / originalWidth)).toInt();
    } else if (config.height != null && config.width == null) {
      targetWidth = (originalWidth * (targetHeight / originalHeight)).toInt();
    }

    // Ensure even dimensions for some encoders
    if (targetWidth % 2 != 0) targetWidth++;
    if (targetHeight % 2 != 0) targetHeight++;

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = targetWidth
      ..height = targetHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;

    // Determine start/end time
    final startMs = config.startTime?.inMilliseconds ?? 0;
    final endMs = config.endTime?.inMilliseconds ?? durationMs;
    final startSeconds = startMs / 1000.0;
    final endSeconds = endMs / 1000.0;

    videoElement.currentTime = startSeconds;

    // Create Stream from Canvas
    final stream = canvas.captureStream(30);

    // Setup MediaRecorder
    const mimeType = 'video/mp4';

    // Check support
    if (!web.MediaRecorder.isTypeSupported(mimeType)) {
      throw Exception(
        "MIME type 'video/mp4' is not supported by this browser.",
      );
    }

    final options = web.MediaRecorderOptions(
      mimeType: mimeType,
      videoBitsPerSecond: config.bitrate ?? 2500000, // Default 2.5Mbps
    );

    final recorder = web.MediaRecorder(stream, options);
    final chunks = <web.Blob>[];

    recorder.ondataavailable = (web.BlobEvent event) {
      if (event.data.size > 0) {
        chunks.add(event.data);
      }
    }.toJS;

    final recordingCompleter = Completer<void>();
    recorder.onstop = (web.Event _) {
      recordingCompleter.complete();
    }.toJS;

    recorder.start();

    // Playback and process loop
    videoElement.play();

    final processingCompleter = Completer<void>();

    void processFrame(num time) {
      if (videoElement.paused || videoElement.ended) {
        if (!processingCompleter.isCompleted) {
          recorder.stop();
          processingCompleter.complete();
        }
        return;
      }

      final currentTime = videoElement.currentTime;
      if (currentTime >= endSeconds) {
        videoElement.pause();
        if (!processingCompleter.isCompleted) {
          recorder.stop();
          processingCompleter.complete();
        }
        return;
      }

      ctx.drawImage(videoElement, 0, 0, targetWidth, targetHeight);

      web.window.requestAnimationFrame(processFrame.toJS);
    }

    web.window.requestAnimationFrame(processFrame.toJS);

    await processingCompleter.future;
    await recordingCompleter.future;

    // Create final blob
    final finalBlob = web.Blob(
      chunks.toJS,
      web.BlobPropertyBag(type: mimeType),
    );

    web.URL.revokeObjectURL(url);

    // Create new URL for the result
    final resultUrl = web.URL.createObjectURL(finalBlob);

    // Return result as XFile using Blob URL
    return XFile(resultUrl, name: 'output.mp4', mimeType: mimeType);
  }
}
