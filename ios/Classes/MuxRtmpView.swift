import AVFoundation
import Flutter
import HaishinKit
import Logboard
import UIKit
import VideoToolbox

class MuxRtmpViewFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return MuxRtmpView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      binaryMessenger: messenger
    )
  }
}

class MuxRtmpView: NSObject, FlutterPlatformView, RTMPStreamDelegate {
  private var viewId: Int64
  private var methodChannel: FlutterMethodChannel
  private var broadcastUrl: String?
  private var rtmpConnection = RTMPConnection()
  private var rtmpStream: RTMPStream!
  private var previewView: MTHKView!
  private var cameraPosition = AVCaptureDevice.Position.front

  init(
    frame: CGRect,
    viewIdentifier: Int64,
    arguments _: Any?,
    binaryMessenger: FlutterBinaryMessenger?
  ) {
    previewView = MTHKView(frame: frame)
    viewId = viewIdentifier
    methodChannel = FlutterMethodChannel(name: "mux_rtmp_view/\(viewId)", binaryMessenger: binaryMessenger!)
    super.init()
    // iOS views can be created here
    methodChannel.setMethodCallHandler {
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      self?.handle(call: call, result: result)
    }
  }

  func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "configure":
      if let args = call.arguments as? [String: Any] {
        configure(broadcastUrl: args["broadcastUrl"] as! String)
      }
      result(nil)
    case "startStream":
      var width = 480
      var height = 640
        if let args = call.arguments as? [String: Any] {
            if args["width"] is Int {
                width = args["width"] as! Int
            }
            if args["height"] is Int {
                height = args["height"] as! Int
            }
        }
        startStream(width: width, height: height)
      result(true)
    case "endStream":
      endStream()
      result(false)
    case "changeCamera":
      changeCamera()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func view() -> UIView {
    return previewView
  }

  func configure(broadcastUrl: String) {
    log("configure(\(broadcastUrl))")
    self.broadcastUrl = broadcastUrl
    initAVFoundation()
    initStream()
  }

  func initAVFoundation() {
    let session = AVAudioSession.sharedInstance()
    do {
      // https://stackoverflow.com/questions/51010390/avaudiosession-setcategory-swift-4-2-ios-12-play-sound-on-silent
      if #available(iOS 10.0, *) {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      } else {
        session.perform(NSSelectorFromString("setCategory:withOptions:error:"), with: AVAudioSession.Category.playAndRecord, with: [
          AVAudioSession.CategoryOptions.allowBluetooth,
          AVAudioSession.CategoryOptions.defaultToSpeaker,
        ])
        try session.setMode(.default)
      }
      try session.setActive(true)
    } catch {
      log("initAVFoundation error: \(error)")
    }
  }

  func initStream() {
    guard let url = broadcastUrl else {
      log("initStream error: no broadcast url")
      return
    }
//    Logboard.with(HaishinKitIdentifier).level = .trace
    rtmpStream = RTMPStream(connection: rtmpConnection)

    rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
    rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)

    rtmpStream.delegate = self

    rtmpStream.captureSettings = [
      .fps: 30, // FPS
      .sessionPreset: AVCaptureSession.Preset.medium, // input video width/height
      .continuousExposure: true,
      .continuousAutofocus: true,
      // .isVideoMirrored: false,
      // .continuousAutofocus: false, // use camera autofocus mode
      // .continuousExposure: false, //  use camera exposure mode
      // .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
    ]
    rtmpStream.audioSettings = [
      .muted: false, // mute audio
      .bitrate: 32 * 1000,
    ]
    
      // "0" means the same of input
    rtmpStream.recorderSettings = [
      AVMediaType.audio: [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 0,
        AVNumberOfChannelsKey: 0,
        // AVEncoderBitRateKey: 128000,
      ],
      AVMediaType.video: [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoHeightKey: 0,
        AVVideoWidthKey: 0,
        /*
          AVVideoCompressionPropertiesKey: [
              AVVideoMaxKeyFrameIntervalDurationKey: 2,
              AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
              AVVideoAverageBitRateKey: 512000
          ]
          */
      ],
    ]

    rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio), automaticallyConfiguresApplicationAudioSession: false) { error in
      self.log("initStream audio error \(error)")
    }
    rtmpStream.attachCamera(DeviceUtil.device(withPosition: cameraPosition)) { error in
      self.log("initStream camera error \(error)")
    }

    previewView.videoGravity = AVLayerVideoGravity.resizeAspectFill
    previewView.attachStream(rtmpStream)

    // add ViewController#view

    var bits = url.components(separatedBy: "/")
    bits.removeLast()
    rtmpConnection.connect(bits.joined(separator: "/"))
  }

    func startStream(width: Int, height: Int) {
    let uri = URL(string: broadcastUrl!)
    log("Starting stream")
  rtmpStream.videoSettings = [
    .width: width, // video output width
    .height: height, // video output height
    .bitrate: 1200 * 1000, // video output bitrate
    .profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel, // H264 Profile require "import VideoToolbox"
    .maxKeyFrameIntervalDuration: 2, // key frame / sec
  ]
    rtmpStream.publish(uri?.pathComponents.last)
  }

  func endStream() {
    log("Ending stream")
    rtmpStream.close()
  }

  func changeCamera() {
    log("Changing camera")
    switch cameraPosition {
    case .back:
      cameraPosition = .front
    case .front:
      cameraPosition = .back
    default:
      cameraPosition = .back
    }

    rtmpStream.attachCamera(DeviceUtil.device(withPosition: cameraPosition)) { error in
      self.log("initStream camera error \(error)")
    }
  }

  @objc
  private func rtmpStatusHandler(_ notification: Notification) {
    log("RTMP Status Handler called.")

    let e = Event.from(notification)
    guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
      return
    }

    log("RTMP Status: " + code)

    switch code {
    case RTMPConnection.Code.connectSuccess.rawValue:
      log("RTMP Connected")
      methodChannel.invokeMethod("rtmpStatusChange", arguments: "connected")

    case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
      log("RTMP Connection was not successful.")
      methodChannel.invokeMethod("rtmpStatusChange", arguments: "notConnected")
    default:
      break
    }
  }

  // Called when there's an RTMP Error
  @objc
  private func rtmpErrorHandler(_ notification: Notification) {
    log("RTMP Error Handler called. \(notification)")
    methodChannel.invokeMethod("rtmpError", arguments: "An error occurred.")
  }

  func rtmpStreamDidClear(_: RTMPStream) {}

  // Statistics callback
  func rtmpStream(_ stream: RTMPStream, didStatics connection: RTMPConnection) {
    log("Stats: \(String(stream.currentFPS)) fps; \(String(connection.currentBytesOutPerSecond / 125)) kbps")
  }

  private var lastBwChange = 0

  // Insufficient bandwidth callback
  func rtmpStream(_ stream: RTMPStream, didPublishInsufficientBW _: RTMPConnection) {
    log("ABR: didPublishInsufficientBW")

    // If we last changed bandwidth over 10 seconds ago
    if (Int(NSDate().timeIntervalSince1970) - lastBwChange) > 5 {
      log("ABR: Will try to change bitrate")

      // Reduce bitrate by 30% every 10 seconds
      let b = Double(stream.videoSettings[.bitrate] as! UInt32) * Double(0.7)
      log("ABR: Proposed bandwidth: " + String(b))
      stream.videoSettings[.bitrate] = b
      lastBwChange = Int(NSDate().timeIntervalSince1970)

      log("Insuffient Bandwidth, changing video bandwidth to: \(String(b))")
    } else {
      log("ABR: Still giving grace time for last bandwidth change")
    }
  }

  // Today this example doesn't attempt to increase bandwidth to find a sweet spot.
  // An implementation might be to gently increase bandwidth by a few percent, but that's hard without getting into an aggressive cycle.
  func rtmpStream(_: RTMPStream, didPublishSufficientBW _: RTMPConnection) {}

  private func log(_ message: String) {
    NSLog("[MuxRtmpView] \(message)")
  }
}
