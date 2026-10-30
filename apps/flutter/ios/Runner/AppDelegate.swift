import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Antes de terminar de arrancar, para no perder el toque que abrió la app.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VocesApns") {
      ApnsPlugin.register(with: registrar)
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let historia = response.notification.request.content.userInfo["story_id"] as? String {
      ApnsPlugin.abrir(historia)
    }
    completionHandler()
  }
}

/// Avisos por APNs sin Firebase: pide permiso, da el token a Dart y le dice
/// qué historia abrir al tocar un aviso. Canal `voces/apns`.
class ApnsPlugin: NSObject, FlutterPlugin {
  private static var instancia: ApnsPlugin?
  /// Toque que llegó antes de que Dart escuchara (el que abrió la app).
  private static var pendiente: String?
  /// Dart ya pidió el toque pendiente: desde entonces escucha «abrir».
  private static var dartEscucha = false

  private let canal: FlutterMethodChannel
  private var esperandoToken: FlutterResult?

  init(canal: FlutterMethodChannel) {
    self.canal = canal
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(name: "voces/apns", binaryMessenger: registrar.messenger())
    let plugin = ApnsPlugin(canal: canal)
    instancia = plugin
    registrar.addMethodCallDelegate(plugin, channel: canal)
    registrar.addApplicationDelegate(plugin)
  }

  static func abrir(_ historia: String) {
    if dartEscucha, let plugin = instancia {
      plugin.canal.invokeMethod("abrir", arguments: historia)
    } else {
      pendiente = historia
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "registrar":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { concedido, _ in
        DispatchQueue.main.async {
          guard concedido else {
            result(nil)
            return
          }
          self.esperandoToken?(nil)
          self.esperandoToken = result
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    case "historiaInicial":
      ApnsPlugin.dartEscucha = true
      result(ApnsPlugin.pendiente)
      ApnsPlugin.pendiente = nil
    case "olvidar":
      UIApplication.shared.unregisterForRemoteNotifications()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    esperandoToken?(token)
    esperandoToken = nil
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    esperandoToken?(FlutterError(code: "apns", message: error.localizedDescription, details: nil))
    esperandoToken = nil
  }
}
