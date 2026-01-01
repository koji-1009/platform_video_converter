// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:io' as io;

import 'package:cross_file/cross_file.dart';
import 'package:jni/jni.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_video_converter/src/models.dart';
import 'package:platform_video_converter/src/video_converter_platform_interface.dart';

import 'bindings.g.dart';

class VideoConverterAndroid implements VideoConverterPlatform {
  const VideoConverterAndroid();

  @override
  Future<XFile> convert({
    required XFile input,
    VideoConfig config = const VideoConfig(),
  }) async {
    // Generate internal temp file
    final tempDir = await getTemporaryDirectory();
    final ext = switch (config.format) {
      VideoFormat.mp4 => 'mp4',
      VideoFormat.webm => 'webm',
      VideoFormat.mov => throw UnsupportedError(
        "MOV format is not supported on Android",
      ),
    };
    final outputName =
        'converted_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final outputFilePath = '${tempDir.path}/$outputName';

    // Use 'using' to manage JNI resources automatically
    await using((arena) async {
      final contextObj = Jni.androidApplicationContext;
      contextObj.releasedBy(arena);

      // 1. Create MediaItem
      final mediaItemBuilder = MediaItem$Builder()
        ..setUri(input.path.toJString()..releasedBy(arena))?.releasedBy(arena)
        ..releasedBy(arena);

      if (config.startTime != null || config.endTime != null) {
        final clippingBuilder = MediaItem$ClippingConfiguration$Builder()
          ..releasedBy(arena);

        if (config.startTime != null) {
          clippingBuilder.setStartPositionMs(config.startTime!.inMilliseconds);
        }
        if (config.endTime != null) {
          clippingBuilder.setEndPositionMs(config.endTime!.inMilliseconds);
        }

        final clippingConfig = clippingBuilder.build()!..releasedBy(arena);
        mediaItemBuilder.setClippingConfiguration(clippingConfig);
      }

      final mediaItem = mediaItemBuilder.build()!..releasedBy(arena);

      // 2. Prepare Effects (Resolution)
      final audioProcessors = JList.array(AudioProcessor.type)
        ..releasedBy(arena);
      final effectsList = JList.array(Effect.type)..releasedBy(arena);

      if (config.width != null && config.height != null) {
        final presentation = Presentation.createForWidthAndHeight(
          config.width!,
          config.height!,
          Presentation.LAYOUT_SCALE_TO_FIT,
        );
        if (presentation != null) {
          presentation.releasedBy(arena);
          effectsList.add(Effect.fromReference(presentation.reference));
        }
      } else if (config.height != null) {
        final presentation = Presentation.createForHeight(config.height!);
        if (presentation != null) {
          presentation.releasedBy(arena);
          effectsList.add(Effect.fromReference(presentation.reference));
        }
      }

      final effects = Effects(audioProcessors, effectsList)..releasedBy(arena);

      // 3. Prepare Audio Processors (Volume)
      // Note: Volume control requires more complex binding (ChannelMixingAudioProcessor matrix).
      // For now, only mute is supported.
      if (config.scale != 1.0 && !config.isMuted) {
        // Assume Stereo (2 channels) for scaling.
        // If input is not Stereo, this might fail or require different matrix.
        // Coefficients: [scale, 0, 0, scale] for 2x2 identity scaling.
        final coeffs = JFloatArray(4);
        coeffs[0] = config.scale.toDouble();
        coeffs[1] = 0.0;
        coeffs[2] = 0.0;
        coeffs[3] = config.scale.toDouble();

        final matrix = ChannelMixingMatrix(2, 2, coeffs)..releasedBy(arena);

        final processor = ChannelMixingAudioProcessor()..releasedBy(arena);
        processor.putChannelMixingMatrix(matrix);

        // ChannelMixingAudioProcessor implements AudioProcessor (interface), so we cast.
        audioProcessors.add(AudioProcessor.fromReference(processor.reference));
      }

      // 4. Create EditedMediaItem
      final editedMediaItemBuilder = EditedMediaItem$Builder(mediaItem)
        ..releasedBy(arena);

      editedMediaItemBuilder.setEffects(effects);

      if (config.isMuted) {
        editedMediaItemBuilder.setRemoveAudio(true);
      }

      final editedMediaItem = editedMediaItemBuilder.build()!
        ..releasedBy(arena);

      // 4. Create Transformer with Bitrate config
      final transformerBuilder = Transformer$Builder(contextObj)
        ..releasedBy(arena);

      if (config.bitrate != null || config.fps != null) {
        final encoderSettingsBuilder = VideoEncoderSettings$Builder()
          ..releasedBy(arena);

        if (config.bitrate != null) {
          encoderSettingsBuilder.setBitrate(config.bitrate!);
        }
        if (config.fps != null) {
          encoderSettingsBuilder.setFrameRate(config.fps!.toDouble());
        }

        final encoderSettings = encoderSettingsBuilder.build()!
          ..releasedBy(arena);

        final encoderFactoryBuilder = DefaultEncoderFactory$Builder(contextObj)
          ..releasedBy(arena);

        encoderFactoryBuilder.setRequestedVideoEncoderSettings(encoderSettings);

        final encoderFactory = encoderFactoryBuilder.build()!
          ..releasedBy(arena);

        transformerBuilder.setEncoderFactory(
          Codec$EncoderFactory.fromReference(encoderFactory.reference),
        );
      }

      final mime = switch (config.format) {
        VideoFormat.mp4 => MimeTypes.VIDEO_H264!,
        VideoFormat.webm => MimeTypes.VIDEO_VP9!,
        VideoFormat.mov => throw UnsupportedError(
          "MOV format is not supported on Android",
        ),
      }..releasedBy(arena);
      transformerBuilder.setVideoMimeType(mime);

      final transformer = transformerBuilder.build();
      if (transformer == null) {
        throw Exception("Failed to build Transformer");
      }
      transformer.releasedBy(arena);

      final completer = Completer<void>();

      final listener = Transformer$Listener.implement(
        $Transformer$Listener(
          onCompleted: (composition, result) {
            completer.complete();
          },
          onError: (composition, result, exception) {
            completer.completeError(
              Exception("Transformation failed: $exception"),
            );
          },
          onFallbackApplied: (composition, request1, request2) {
            // No-op
          },
        ),
      )..releasedBy(arena);

      transformer.addListener(listener);

      // Use start with EditedMediaItem
      transformer.start$1(
        editedMediaItem,
        outputFilePath.toJString()..releasedBy(arena),
      );

      await completer.future;
    });

    return XFile(outputFilePath);
  }

  @override
  Future<void> cleanup(XFile file) async {
    final ioFile = io.File(file.path);
    if (await ioFile.exists()) {
      await ioFile.delete();
    }
  }
}
