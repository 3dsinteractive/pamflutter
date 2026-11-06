package ai.pams.pam_flutter
import androidx.annotation.NonNull
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
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.activity.ActivityAware


class PamFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "pam_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "identifierForVendor"-> {
        val uuid = identifierForVendor()
        result.success(uuid)
      }
      "appAttentionPopup"->{
        val arguments = call.arguments as Map<String, Any>

        Handler(Looper.getMainLooper()).post {
          activity?.let {
              PopupDialog(it, arguments, result).show()
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
    channel.setMethodCallHandler(null)
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


  private fun identifierForVendor(): String{
    context?.let{ context ->
      var deviceID = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
      return deviceID
    }
    return ""
  }
}
