package ai.pams.pam_flutter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.content.Context
import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import android.provider.Settings
import android.os.Build
import io.flutter.embedding.engine.plugins.activity.ActivityAware


class PamFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private lateinit var loggingChannel: MethodChannel
  private val logger = PamLogger()
  private var context: Context? = null
  private var activity: Activity? = null
  private var activePopup: PopupDialog? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "pam_flutter")
    channel.setMethodCallHandler(this)
    loggingChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "pam_flutter/logging")
    loggingChannel.setMethodCallHandler(logger)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activePopup?.dismiss()
    activePopup = null
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activePopup?.dismiss()
    activePopup = null
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "identifierForVendor"-> {
        val uuid = identifierForVendor()
        result.success(uuid)
      }
      "appAttentionPopup"->{
        val arguments = call.arguments as? Map<String, Any?>
        val host = activity
        when {
          activePopup != null -> result.success(null)
          arguments == null -> result.error("INVALID_ARGUMENTS", "Expected popup data", null)
          host == null || host.isFinishing || host.isDestroyed ->
            result.error("NO_ACTIVITY", "No active Activity to display App Attention", null)
          else -> {
            var completed = false
            try {
              lateinit var dialog: PopupDialog
              dialog = PopupDialog(host, arguments, onTrackingError = logger::attentionError) { data ->
                if (activePopup === dialog) activePopup = null
                if (!completed) {
                  completed = true
                  result.success(data)
                }
              }
              activePopup = dialog
              dialog.show()
            } catch (error: Exception) {
              val dialog = activePopup
              activePopup = null
              if (!completed) {
                completed = true
                result.error("POPUP_FAILED", error.message, null)
              }
              dialog?.dismiss()
            }
          }
        }
      }
      "getPlatformVersion"->{
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "getTrackingAppInfo" -> {
        val appContext = context
        if (appContext == null) {
          result.error("NO_CONTEXT", "Application context is unavailable", null)
        } else {
          result.success(getTrackingAppInfo(appContext))
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    activePopup?.dismiss()
    activePopup = null
    channel.setMethodCallHandler(null)
    loggingChannel.setMethodCallHandler(null)
  }

  @Suppress("DEPRECATION")
  private fun getTrackingAppInfo(context: Context): Map<String, String> {
    val packageManager = context.packageManager
    val packageInfo = packageManager.getPackageInfo(context.packageName, 0)
    val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      packageInfo.longVersionCode
    } else {
      packageInfo.versionCode.toLong()
    }
    return mapOf(
      "osVersion" to "Android: ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
      "appName" to packageManager.getApplicationLabel(context.applicationInfo).toString(),
      "appVersion" to packageInfo.versionName.orEmpty(),
      "buildNumber" to buildNumber.toString()
    )
  }


  private fun identifierForVendor(): String? {
    val contentResolver = context?.contentResolver ?: return null
    return Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
  }
}
