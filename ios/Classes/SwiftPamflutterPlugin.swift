import Flutter
import UIKit

public class SwiftPamflutterPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ai.pams.flutter", binaryMessenger: registrar.messenger())
        let instance = SwiftPamflutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        instance.setMethodChannel(channel: channel)
    }
    
    var channel:FlutterMethodChannel?
    var application: UIApplication?
    
    public func setMethodChannel(channel: FlutterMethodChannel){
        self.channel = channel
        channel.setMethodCallHandler { call, result in
            if call.method == "askNotificationPermission" {
                self.askNotificationPermission()
            }else if call.method == "getPlatformVersion" {
              result("iOS " + UIDevice.current.systemVersion)
            }else if(call.method == "getPlatform"){
              result("iOS")
            }
        }
    }
    
    private func askNotificationPermission(){
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            if #available(iOS 12.0, *) {
                center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) {granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            self.registerForRemoteNotifications()
                        }
                    }
                }
            } else {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            self.registerForRemoteNotifications()
                        }
                    }
                }
            }
        }
    }
    
    private func registerForRemoteNotifications(){
        self.application?.registerForRemoteNotifications()
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        self.application = application
        return true
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        channel?.invokeMethod("onToken", arguments: token)
    }
    
}