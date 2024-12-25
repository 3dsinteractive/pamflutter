import AppTrackingTransparency
import Flutter
import UIKit

public class PamFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pam_flutter", binaryMessenger: registrar.messenger())
    let instance = PamFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "askNotificationPermission":
      self.askNotificationPermission()
    case "getPlatform":
      result("iOS")
    case "getTrackingAuthorizationStatus":
      self.getTrackingAuthorizationStatus(result: result)
    case "requestTrackingAuthorization":
      self.requestTrackingAuthorization(result: result)
    case "identifierForVendor":
      let uuid = self.identifierForVendor()
      result(uuid)
    case "appAttentionPopup":
      self.showNativePopup(call.arguments as? [String: Any], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showNativePopup(_ popup: [String: Any]?, result: @escaping FlutterResult) {
    guard let popup = popup else { return }

    DispatchQueue.main.async {
      let popupVC = PopupViewController()
      popupVC.result = result
      popupVC.popupData = popup
      popupVC.modalPresentationStyle = .overFullScreen  // ให้แสดงแบบเต็มจอ
      UIApplication.shared.keyWindow?.rootViewController?.present(
        popupVC, animated: false, completion: nil)
    }

  }

  private func identifierForVendor() -> String {
    let uuid = UIDevice.current.identifierForVendor?.uuidString ?? ""
    return uuid
  }

  private func requestTrackingAuthorization(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { status in
        result(Int(status.rawValue))
      }
    } else {
      result(Int(4))  // ค่า 4 หมายถึง 'notSupported'
    }
  }

  private func registerForRemoteNotifications() {
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  private func askNotificationPermission() {
    if #available(iOS 10.0, *) {
      let center = UNUserNotificationCenter.current()
      if #available(iOS 12.0, *) {
        center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, _ in
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

  private func getTrackingAuthorizationStatus(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      result(Int(ATTrackingManager.trackingAuthorizationStatus.rawValue))
    } else {
      // return notSupported
      result(Int(4))
    }
  }

}
