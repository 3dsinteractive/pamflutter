#import "PamflutterPlugin.h"
#if __has_include(<pamflutter/pamflutter-Swift.h>)
#import <pamflutter/pamflutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "pamflutter-Swift.h"
#endif

@implementation PamflutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPamflutterPlugin registerWithRegistrar:registrar];
}
@end
