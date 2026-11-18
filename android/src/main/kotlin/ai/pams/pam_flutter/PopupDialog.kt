package ai.pams.pam_flutter

import android.app.Dialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import android.widget.VideoView
import android.view.View
import com.bumptech.glide.Glide
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.content.res.ColorStateList
import android.view.WindowManager
import android.os.Build
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class PopupDialog(
    context: Context,
    arguments: Map<String, Any?>,
    private val onTrackingError: (Throwable) -> Unit,
    onClosed: (Map<String, Any?>?) -> Unit
) : Dialog(context, R.style.PamAttentionDialogTheme) {
    private var clickData: Map<String, Any?>? = null
    private var completed = false

    init {
        // ดึงค่าจาก arguments
        val type = arguments["type"] as? String
        val size = arguments["size"] as? String
        val title = arguments["title"] as? String
        val description = arguments["description"] as? String
        val url = arguments["url"] as? String
        val video = arguments["video"] as? String
        val image = arguments["image"] as? String
        val trackingPixelUrl = arguments["tracking_pixel_url"] as? String
        
        trackPixel(trackingPixelUrl)
    
        if (size == "large") {
            setContentView(R.layout.popup_view_large)
        } else {
            setContentView(R.layout.popup_view_full)
        }
        
        window?.apply {
            setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT
            )
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            // The layout already supplies a 70% black overlay, matching iOS.
            // Disable theme-provided dimming on this dialog's window only.
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            setDimAmount(0f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                attributes = attributes.apply {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
        }

        // ตั้งค่า Title
        val titleView: TextView = findViewById(R.id.title)
        titleView.text = title

        // ตั้งค่า Description
        val descriptionView: TextView = findViewById(R.id.description)
        descriptionView.text = description


        val imageView: ImageView = findViewById(R.id.imageView)
        val videoView: VideoView = findViewById(R.id.videoView)

        imageView.visibility = View.INVISIBLE
        videoView.visibility = View.INVISIBLE

        // กรณีแสดง Image
        image?.let {
            imageView.scaleType = ImageView.ScaleType.CENTER_CROP
           
            // โหลดภาพด้วย Glide
            Glide.with(context).load(it).into(imageView)
            imageView.visibility = View.VISIBLE
        }

        // กรณีแสดง Video
        video?.let {
           if(video != ""){
                videoView.setVideoURI(Uri.parse(it))
                videoView.setOnPreparedListener { mp -> mp.isLooping = true } // ตั้งค่าให้เล่นซ้ำ
                videoView.start()
                videoView.visibility = View.VISIBLE
           }
        }

        // ตั้งค่า Learn More Button
        val learnMoreButton: Button = findViewById(R.id.learnMore)
        learnMoreButton.visibility = if (url.isNullOrBlank()) View.GONE else View.VISIBLE
        (arguments["action_button_label"] as? String)?.let {
            learnMoreButton.isAllCaps = false
            learnMoreButton.text = it
        }
        parseButtonColor(arguments["action_button_color"])?.let {
            learnMoreButton.backgroundTintList = ColorStateList.valueOf(it)
        }
        parseButtonColor(arguments["action_button_text_color"])?.let {
            learnMoreButton.setTextColor(it)
        }
        learnMoreButton.setOnClickListener {

            clickData = HashMap(arguments)
            dismiss()
        }

        // ตั้งค่า Close Button
        val closeButton: ImageButton = findViewById(R.id.closeButton)
        closeButton.setOnClickListener { dismiss() }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Keep controls clear of camera cutouts without insetting the backdrop/media.
            val closeMargins = closeButton.layoutParams as ViewGroup.MarginLayoutParams
            val closeTop = closeMargins.topMargin
            val closeEnd = closeMargins.marginEnd
            val buttonMargins = learnMoreButton.layoutParams as ViewGroup.MarginLayoutParams
            val buttonBottom = buttonMargins.bottomMargin
            window?.decorView?.setOnApplyWindowInsetsListener { _, insets ->
                val cutout = insets.displayCutout
                closeMargins.topMargin = closeTop + (cutout?.safeInsetTop ?: 0)
                val endInset = if (closeButton.layoutDirection == View.LAYOUT_DIRECTION_RTL) {
                    cutout?.safeInsetLeft ?: 0
                } else {
                    cutout?.safeInsetRight ?: 0
                }
                closeMargins.marginEnd = closeEnd + endInset
                closeButton.layoutParams = closeMargins
                buttonMargins.bottomMargin = buttonBottom + (cutout?.safeInsetBottom ?: 0)
                learnMoreButton.layoutParams = buttonMargins
                insets
            }
        }
        setOnDismissListener {
            videoView.stopPlayback()
            if (!completed) {
                completed = true
                onClosed(clickData)
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onStart() {
        super.onStart()
        window?.apply {
            // Apply after show(): a floating host theme must not constrain this window.
            setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT
            )
            decorView.setPadding(0, 0, 0, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                setDecorFitsSystemWindows(false)
                insetsController?.apply {
                    systemBarsBehavior =
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    hide(WindowInsets.Type.systemBars())
                }
            } else {
                decorView.systemUiVisibility =
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            }
            decorView.requestApplyInsets()
        }
    }

    private fun parseButtonColor(value: Any?): Int? {
        val hex = (value as? String)?.trim() ?: return null
        if (!Regex("^#[0-9a-fA-F]{6}$").matches(hex)) return null
        return Color.parseColor(hex)
    }

    fun trackPixel(trackingPixelUrl: String?) {
        val urlString = trackingPixelUrl ?: return
        thread {
            var connection: HttpURLConnection? = null
            try {
                val url = URL(urlString)
                connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 10000 // Optional: set a timeout
                connection.readTimeout = 10000
                
                connection.connect()
                
                // Force the network request to complete by reading the response code
                val responseCode = connection.responseCode
                if (responseCode !in 200..299) {
                    onTrackingError(IllegalStateException("Tracking pixel HTTP status=$responseCode"))
                    return@thread
                }
                
                // Optionally, read the input stream to ensure the request is fully processed
                connection.inputStream.bufferedReader().use { it.readText() }
            } catch (e: Exception) {
                onTrackingError(e)
            } finally {
                connection?.disconnect()
            }
        }
    }
    


}
