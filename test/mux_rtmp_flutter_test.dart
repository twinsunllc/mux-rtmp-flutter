import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mux_rtmp_flutter/mux_rtmp_flutter.dart';

void main() {
  const MethodChannel channel = MethodChannel('mux_rtmp_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await MuxRtmpFlutter.platformVersion, '42');
  });
}
