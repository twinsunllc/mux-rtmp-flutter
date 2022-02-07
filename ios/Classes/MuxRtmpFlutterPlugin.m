#import "MuxRtmpFlutterPlugin.h"
#if __has_include(<mux_rtmp_flutter/mux_rtmp_flutter-Swift.h>)
#import <mux_rtmp_flutter/mux_rtmp_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "mux_rtmp_flutter-Swift.h"
#endif

@implementation MuxRtmpFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMuxRtmpFlutterPlugin registerWithRegistrar:registrar];
}
@end
