import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

class MuxRtmpFlutter {
  static const MethodChannel _channel = MethodChannel('mux_rtmp_flutter');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}

class MuxRtmpController {
  Logger get _log => Logger('MuxRtmpController');

  MuxRtmpController({required this.url, this.onStatusChange, this.onError});

  String url;
  void Function(String status)? onStatusChange;
  void Function(String error)? onError;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  MethodChannel? _channel;

  void attachToChannel(MethodChannel channel) {
    _channel = channel;
    _channel?.setMethodCallHandler(_handle);
    configure();
  }

  Future<dynamic> _handle(MethodCall call) {
    _log.finest('${call.method}: ${call.arguments}');
    switch (call.method) {
      case 'rtmpStatusChange':
        onStatusChange?.call(call.arguments as String);
        return Future<dynamic>.value(true);
      case 'rtmpError':
        onError?.call(call.arguments as String);
        _isStreaming = false;
        return Future<dynamic>.value(true);
      default:
        return Future<dynamic>.value(null);
    }
  }

  Future<void> configure() async {
    await _channel?.invokeMethod('configure', {'broadcastUrl': url});
  }

  Future<void> startStream({double width = 480, double height = 640}) async {
    _isStreaming = await _channel?.invokeMethod('startStream', {'width': width.round(), 'height': height.round()});
  }

  Future<void> endStream() async {
    _isStreaming = await _channel?.invokeMethod('endStream');
  }

  Future<void> changeCamera() async {
    await _channel?.invokeMethod('changeCamera');
  }
}

class MuxRtmpView extends StatefulWidget {
  const MuxRtmpView({Key? key, required this.controller}) : super(key: key);

  final MuxRtmpController controller;

  @override
  State<MuxRtmpView> createState() => _MuxRtmpViewState();
}

class _MuxRtmpViewState extends State<MuxRtmpView> {
  // ignore: unused_element
  Logger get _log => Logger('MuxRtmpView');

  late final MethodChannel _channel;

  @override
  void initState() {
    super.initState();
  }

  void _handlePlatformViewCreated(int viewId) {
    _channel = MethodChannel('mux_rtmp_view/$viewId');
    widget.controller.attachToChannel(_channel);
  }

  @override
  Widget build(BuildContext context) {
    const String viewType = 'MuxRtmpView';
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    return UiKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _handlePlatformViewCreated,
    );
  }
}
