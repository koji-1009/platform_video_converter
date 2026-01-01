import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:platform_video_converter/platform_video_converter.dart';
import 'package:video_player/video_player.dart' hide VideoFormat;

import 'platform_services/platform_services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const MyPage());
  }
}

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  XFile? _inputVideo;
  XFile? _outputVideo;

  bool _isConverting = false;
  String _statusMessage = '';
  VideoPlayerController? _controller;

  // Config State
  int? _fps;
  bool _isMuted = false;
  double _volume = 1.0;

  final _platformServices = getPlatformServices();

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      if (_controller != null) {
        await _controller!.dispose();
      }
      setState(() {
        _inputVideo = picked;

        _statusMessage = 'Selected: ${picked.path}';
      });
      _playVideo(_inputVideo!);
    }
  }

  Future<void> _playVideo(XFile file) async {
    _controller = _platformServices.createVideoPlayerController(file);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    await _controller!.play();
    setState(() {});
  }

  Future<void> _convertVideo() async {
    if (_inputVideo == null) return;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Converting...';
    });

    try {
      // Cleanup previous output if exists
      if (_outputVideo != null) {
        await VideoConverter.cleanup(_outputVideo!);
        _outputVideo = null;
      }

      final config = VideoConfig(
        format: VideoFormat.mp4,
        startTime: const Duration(seconds: 0),
        endTime: const Duration(seconds: 5), // Clip to 5s for example
        width: 640,
        height: 360,
        bitrate: 1000000,
        fps: _fps,
        isMuted: _isMuted,
        scale: _volume,
      );

      // Perform conversion
      final resultFile = await VideoConverter.convert(
        input: _inputVideo!,
        config: config,
      );

      // Save/Handle Result
      final resultMessage = await _platformServices.saveResult(resultFile);

      setState(() {
        _isConverting = false;
        _outputVideo = resultFile;
        _statusMessage = 'Success! $resultMessage';
      });

      // Play output
      if (_controller != null) {
        await _controller!.pause();
        await _controller!.dispose();
      }
      _playVideo(resultFile);
    } catch (e) {
      setState(() {
        _isConverting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_outputVideo != null) {
      VideoConverter.cleanup(_outputVideo!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Converter Example')),
      body: SingleChildScrollView(
        child: Column(
          spacing: 20,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            SelectableText(_statusMessage),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isConverting ? null : _pickVideo,
                  child: const Text('Pick Video'),
                ),
                ElevatedButton(
                  onPressed: _isConverting || _inputVideo == null
                      ? null
                      : _convertVideo,
                  child: const Text('Convert'),
                ),
              ],
            ),
            // Config Controls
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                Column(
                  children: [
                    const Text("FPS"),
                    DropdownButton<int?>(
                      value: _fps,
                      items: const [
                        DropdownMenuItem(value: null, child: Text("Default")),
                        DropdownMenuItem(value: 15, child: Text("15")),
                        DropdownMenuItem(value: 24, child: Text("24")),
                        DropdownMenuItem(value: 30, child: Text("30")),
                        DropdownMenuItem(value: 60, child: Text("60")),
                      ],
                      onChanged: (v) => setState(() => _fps = v),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text("Mute"),
                    Switch(
                      value: _isMuted,
                      onChanged: (v) => setState(() => _isMuted = v),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text("Volume: ${_volume.toStringAsFixed(1)}x"),
                    Slider(
                      value: _volume,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      onChanged: _isMuted
                          ? null
                          : (v) => setState(() => _volume = v),
                    ),
                  ],
                ),
              ],
            ),
            if (_isConverting)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Web Note: Works on Chrome/Edge/Safari (MP4). Firefox not supported.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
