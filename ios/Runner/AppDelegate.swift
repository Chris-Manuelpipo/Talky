import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set up audio session early
    AudioSessionManager.shared.setupAudioSession()
    
    let controller = window?.rootViewController as! FlutterViewController
    let audioChannel = FlutterMethodChannel(
      name: "com.example.talky/audio",
      binaryMessenger: controller.binaryMessenger
    )
    
    audioChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setSpeaker":
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          AudioSessionManager.shared.setSpeaker(enabled: enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled parameter", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
