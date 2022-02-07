import Flutter
import UIKit

public class SwiftMuxRtmpFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "mux_rtmp_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftMuxRtmpFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let factory = MuxRtmpViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "MuxRtmpView")
  }

  public func handle(_: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }
}
