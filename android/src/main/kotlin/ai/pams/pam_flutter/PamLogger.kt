package ai.pams.pam_flutter

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class PamLogger : MethodChannel.MethodCallHandler {
    @Volatile var enabled = false
        private set

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                enabled = call.argument<Boolean>("enabled") == true
                result.success(null)
            }
            "log" -> {
                val category = call.argument<String>("category") ?: "General"
                val level = call.argument<String>("level") ?: "info"
                val lines = call.argument<List<String>>("lines") ?: emptyList()
                // Dart already checks enableLog before submitting an entry.
                write(category, level, lines)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun attentionError(error: Throwable) {
        if (enabled) write("Attention", "error",
            listOf("Tracking pixel failed type=${error.javaClass.simpleName} message=${error.message}",
                Log.getStackTraceString(error)))
    }

    private fun write(category: String, level: String, lines: List<String>) {
        val priority = when (level) {
            "debug" -> Log.DEBUG
            "warning" -> Log.WARN
            "error" -> Log.ERROR
            else -> Log.INFO
        }
        val label = if (level == "warning") "WARN" else level.uppercase(java.util.Locale.ROOT)
        for (text in lines) {
            for (line in text.lineSequence()) {
                // Native exceptions may contain long lines too. Chunk by code
                // point so UTF-8 text and emoji remain intact.
                var chunk = StringBuilder()
                var bytes = 0
                for (codePoint in line.codePoints().toArray()) {
                    val character = String(Character.toChars(codePoint))
                    val length = character.toByteArray(Charsets.UTF_8).size
                    if (bytes + length > 800) {
                        Log.println(priority, "PAM", "[PAM][$category][$label] $chunk")
                        chunk = StringBuilder()
                        bytes = 0
                    }
                    chunk.append(character)
                    bytes += length
                }
                Log.println(priority, "PAM", "[PAM][$category][$label] $chunk")
            }
        }
    }
}
