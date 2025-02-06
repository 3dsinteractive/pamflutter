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
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel.Result
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class PopupDialog(context: Context, arguments: Map<String, Any?>, result: Result) : Dialog(context) {

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
        learnMoreButton.setOnClickListener {

            val args = arguments as Map<String, Any?>
            result.success(HashMap(args))

            dismiss()
        }

        // ตั้งค่า Close Button
        val closeButton: ImageButton = findViewById(R.id.closeButton)
        closeButton.setOnClickListener { 
            result.success(null)
            dismiss()
         }
    }

    fun trackPixel(trackingPixelUrl: String?) {
        val urlString = trackingPixelUrl ?: return
    
        thread {
            var connection: HttpURLConnection? = null
            try {
                val url = URL(urlString)
                connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()
            } catch (e: Exception) {
                
            } finally {
                connection?.disconnect()
            }
        }
    }


}
