// Regenerate bindings with `dart run ffigen.dart`.
import 'package:ffigen/ffigen.dart';

final config = FfiGenerator(
  headers: Headers(entryPoints: [Uri.file('stub_headers/avfoundation_stub.h')]),
  objectiveC: ObjectiveC(
    interfaces: Interfaces.includeSet({
      'AVAsset',
      'AVURLAsset',
      'AVAssetExportSession',
      'AVAssetTrack',
      'AVVideoComposition',
      'AVMutableVideoComposition',
      'AVVideoCompositionInstruction',
      'AVMutableVideoCompositionInstruction',
      'AVVideoCompositionLayerInstruction',
      'AVMutableVideoCompositionLayerInstruction',
    }),
  ),
  structs: Structs.includeSet({'CMTime', 'CMTimeRange', 'CGAffineTransform'}),

  output: Output(dartFile: Uri.file('lib/src/darwin/bindings.g.dart')),
);

void main() => config.generate();
