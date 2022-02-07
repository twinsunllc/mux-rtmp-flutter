
import 'dart:async';

import 'package:flutter/services.dart';

class MuxRtmpFlutter {
  static const MethodChannel _channel = MethodChannel('mux_rtmp_flutter');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
