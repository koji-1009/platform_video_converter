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
          ..muted =
              true // Start muted, unmute for capture if needed
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

    // Create Stream from Canvas (Video)
    // If config.fps is set, use it for captureStream.
    final stream = canvas.captureStream(config.fps?.toDouble() ?? 30);

    // Audio Handling
    web.AudioContext? audioContext;
    web.MediaStreamAudioDestinationNode? audioDestination;

    if (!config.isMuted) {
      try {
        videoElement.muted = false; // Must be unmuted to capture audio
        videoElement.volume = 1.0;

        audioContext = web.AudioContext();
        final source = audioContext.createMediaElementSource(videoElement);
        final gainNode = audioContext.createGain();

        gainNode.gain.value = config.scale;

        audioDestination = audioContext.createMediaStreamDestination();

        source.connect(gainNode);
        gainNode.connect(audioDestination);

        // Add audio track to stream
        final audioTracks = audioDestination.stream.getAudioTracks();
        if (audioTracks.length > 0) {
          stream.addTrack(audioTracks[0]);
        }
      } catch (e) {
        // Fallback or ignore if AudioContext fails (e.g. strict autoplay policy)
        // print("Web Audio setup failed: $e");
      }
    }

    // Setup MediaRecorder
    final mimeType = switch (config.format) {
      VideoFormat.mp4 => 'video/mp4',
      VideoFormat.webm => 'video/webm',
      // Likely unsupported on many browsers
      VideoFormat.mov => 'video/quicktime',
    };

    // Check support
    if (!web.MediaRecorder.isTypeSupported(mimeType)) {
      // Fallback strategies or detailed error
      if (config.format == VideoFormat.mp4 &&
          web.MediaRecorder.isTypeSupported('video/webm')) {
        throw Exception(
          "MIME type '$mimeType' is not supported. Try using VideoFormat.webm.",
        );
      }
      throw Exception(
        "MIME type '$mimeType' is not supported by this browser.",
      );
    }

    final options = web.MediaRecorderOptions(
      mimeType: mimeType,
      videoBitsPerSecond: config.bitrate ?? 2500000,
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

    // FPS Control
    // FPS Control
    // If null, we want max speed (e.g. 60).
    final frameInterval = 1000.0 / (config.fps ?? 60.0);
    double lastFrameTime = 0;

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

      // Throttling
      if (time - lastFrameTime >= frameInterval) {
        ctx.drawImage(videoElement, 0, 0, targetWidth, targetHeight);
        lastFrameTime = time.toDouble();
      }

      web.window.requestAnimationFrame(processFrame.toJS);
    }

    web.window.requestAnimationFrame(processFrame.toJS);

    await processingCompleter.future;
    await recordingCompleter.future;

    // Cleanup Audio
    if (audioContext != null) {
      audioContext.close();
    }

    // Create final blob
    final finalBlob = web.Blob(
      chunks.toJS,
      web.BlobPropertyBag(type: mimeType),
    );

    web.URL.revokeObjectURL(url);

    // Create new URL for the result
    final resultUrl = web.URL.createObjectURL(finalBlob);

    // Return result as XFile using Blob URL
    final ext = switch (config.format) {
      VideoFormat.mp4 => 'mp4',
      VideoFormat.webm => 'webm',
      VideoFormat.mov => 'mov',
    };
    return XFile(resultUrl, name: 'output.$ext', mimeType: mimeType);
  }

  @override
  Future<void> cleanup(XFile file) async {
    web.URL.revokeObjectURL(file.path);
  }
}
