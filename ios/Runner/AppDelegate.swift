import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Direct share channel. Only Instagram Stories has a public direct-image
    // hand-off on iOS; everything else returns false so Dart falls back to the
    // system share sheet.
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: "com.nida.nida/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "shareImageToApp" {
        result(AppDelegate.shareImageToApp(call.arguments))
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Home-screen widget bridge: write the pushed data into the App Group so the
    // WidgetKit extension can read it, then reload all widget timelines.
    let widgetChannel = FlutterMethodChannel(name: "nida/widget", binaryMessenger: messenger)
    widgetChannel.setMethodCallHandler { call, result in
      if call.method == "update", let args = call.arguments as? [String: Any] {
        let defaults = UserDefaults(suiteName: "group.com.nida.nida")
        for (key, value) in args {
          defaults?.set("\(value)", forKey: key)
        }
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func shareImageToApp(_ arguments: Any?) -> Bool {
    guard let args = arguments as? [String: Any],
          let target = args["target"] as? String,
          let path = args["path"] as? String,
          let image = UIImage(contentsOfFile: path),
          let data = image.pngData() else { return false }
    guard target == "instagram",
          let url = URL(string:
            "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "")"),
          UIApplication.shared.canOpenURL(url) else { return false }
    let items: [String: Any] = ["com.instagram.sharedSticker.backgroundImage": data]
    let options = [UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(300)]
    UIPasteboard.general.setItems([items], options: options)
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }
}
