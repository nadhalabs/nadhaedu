import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private let methodChannelName = "com.learningplatform/content_protection/methods"
  private let eventChannelName = "com.learningplatform/content_protection/events"
  private let storageChannelName = "com.learningplatform/storage"

  private var eventSink: FlutterEventSink?
  private var isProtectionEnabled: Bool = false
  private var activePolicy: String = "none"
  private let privacyCoverTag = 99901

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    setupContentProtectionChannels(messenger: controller.binaryMessenger)
    setupStorageChannel(messenger: controller.binaryMessenger)
    registerCaptureObservers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupStorageChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: storageChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "getAvailableBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let values = try FileManager.default.urls(
          for: .applicationSupportDirectory,
          in: .userDomainMask
        ).first!.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let bytes = values.volumeAvailableCapacityForImportantUsage else {
          result(FlutterError(code: "DISK_SPACE_UNAVAILABLE", message: "Available storage is unavailable.", details: nil))
          return
        }
        result(bytes)
      } catch {
        result(FlutterError(code: "DISK_SPACE_UNAVAILABLE", message: error.localizedDescription, details: nil))
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupContentProtectionChannels(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }

      switch call.method {
      case "enableProtection":
        let args = call.arguments as? [String: Any]
        self.activePolicy = args?["policy"] as? String ?? "blockCaptureWhereSupported"
        self.isProtectionEnabled = true
        result(nil)

      case "disableProtection":
        self.isProtectionEnabled = false
        self.activePolicy = "none"
        result(nil)

      case "getCaptureState":
        let isCaptured = self.checkIsCaptured()
        result([
          "isCaptured": isCaptured,
          "isProtected": self.isProtectionEnabled,
          "policy": self.activePolicy,
          "platform": "ios"
        ])

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    eventChannel.setStreamHandler(self)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  private func registerCaptureObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userTookScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
  }

  @objc private func screenCaptureChanged() {
    let isCaptured = checkIsCaptured()
    eventSink?([
      "event": "capture_state_changed",
      "isCaptured": isCaptured,
      "captureType": "screen_recording"
    ])
  }

  @objc private func userTookScreenshot() {
    eventSink?([
      "event": "screenshot_taken",
      "timestamp": ISO8601DateFormatter().string(from: Date())
    ])
  }

  private func checkIsCaptured() -> Bool {
    if #available(iOS 11.0, *) {
      return UIScreen.main.isCaptured
    }
    return false
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    if isProtectionEnabled {
      showPrivacyCover()
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyCover()
    screenCaptureChanged()
  }

  private func showPrivacyCover() {
    guard let window = self.window, window.viewWithTag(privacyCoverTag) == nil else { return }

    let coverView = UIView(frame: window.bounds)
    coverView.tag = privacyCoverTag
    coverView.backgroundColor = UIColor.systemBackground
    coverView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let blurEffect = UIBlurEffect(style: .systemThinMaterial)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = coverView.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    coverView.addSubview(blurView)

    window.addSubview(coverView)
  }

  private func hidePrivacyCover() {
    guard let window = self.window, let coverView = window.viewWithTag(privacyCoverTag) else { return }
    coverView.removeFromSuperview()
  }
}
