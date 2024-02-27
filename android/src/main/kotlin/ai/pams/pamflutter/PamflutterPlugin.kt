package ai.pams.pamflutter

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import androidx.annotation.NonNull
import android.content.Context
import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import android.provider.Settings
import android.util.Log

/** PamflutterPlugin */
class PamflutterPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ai.pams.flutter")
    context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(this)
  }

  fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity;
  }

  private fun identifierForVendor(): String{
    context?.let{ context ->
      var deviceID = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
      return deviceID
    }
    return ""
  }


  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "identifierForVendor"-> {
        val uuid = identifierForVendor()
        result.success(uuid)
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}