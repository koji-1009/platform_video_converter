import 'platform_interface.dart';
import 'platform_web.dart' if (dart.library.io) 'platform_io.dart' as impl;

export 'platform_interface.dart';

PlatformServices getPlatformServices() => impl.getPlatformServices();
