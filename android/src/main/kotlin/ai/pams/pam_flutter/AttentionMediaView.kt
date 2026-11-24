package ai.pams.pam_flutter

import android.content.Context
import android.graphics.SurfaceTexture
import android.graphics.drawable.Drawable
import android.media.MediaPlayer
import android.net.Uri
import android.util.AttributeSet
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ProgressBar
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.resource.bitmap.DownsampleStrategy
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

// The outer view never changes size when metadata arrives. Only hidden media
// is laid out, then revealed in its final position without a crossfade.
internal class AttentionMediaView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : FrameLayout(context, attrs), TextureView.SurfaceTextureListener {
    private val imageView = ImageView(context).apply {
        scaleType = ImageView.ScaleType.FIT_XY
        alpha = 0f
    }
    private val videoView = TextureView(context).apply {
        isOpaque = false
        alpha = 0f
        surfaceTextureListener = this@AttentionMediaView
    }
    private val loading = ProgressBar(context)
    private var imageTarget: CustomTarget<Drawable>? = null
    private val videoWorker = Executors.newSingleThreadExecutor()
    private var player: MediaPlayer? = null
    private var surface: Surface? = null
    private var imageURL: String? = null
    private var videoURL: String? = null
    private var mediaWidth = 0f
    private var mediaHeight = 0f
    private var videoMode = false
    private var renderingStarted = false
    private var imageReady = false
    @Volatile private var closed = false
    private var full = false
    private var contentLeft = 0
    private var contentTop = 0
    private var contentRight = 0
    private var contentBottom = 0
    private var maximumWidth = Int.MAX_VALUE
    private var maximumHeight = Int.MAX_VALUE

    init {
        clipChildren = true
        addView(imageView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(videoView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        val spinnerSize = (32 * resources.displayMetrics.density).roundToInt()
        addView(loading, LayoutParams(spinnerSize, spinnerSize, Gravity.CENTER))
    }

    fun load(image: String?, video: String?, full: Boolean) {
        this.full = full
        imageURL = image?.trim()?.takeIf { it.isNotEmpty() }
        videoURL = video?.trim()?.takeIf { it.isNotEmpty() }
        videoMode = videoURL != null
        if (videoMode) {
            if (videoView.isAvailable) videoView.surfaceTexture?.let { startVideo(it) }
        } else {
            loadImage()
        }
    }

    fun setContentArea(left: Int, top: Int, right: Int, bottom: Int, maxWidth: Int, maxHeight: Int) {
        contentLeft = left
        contentTop = top
        contentRight = right
        contentBottom = bottom
        maximumWidth = maxWidth
        maximumHeight = maxHeight
        layoutMedia()
    }

    private fun loadImage() {
        val url = imageURL
        if (closed || url == null) {
            loading.visibility = View.INVISIBLE
            return
        }
        // Decode off the UI thread, bounded to screen resolution. Glide also
        // applies EXIF orientation before reporting drawable dimensions.
        val metrics = resources.displayMetrics
        val edge = max(metrics.widthPixels, metrics.heightPixels).coerceAtLeast(1)
        val target = object : CustomTarget<Drawable>(edge, edge) {
            override fun onResourceReady(resource: Drawable, transition: Transition<in Drawable>?) {
                if (closed) return
                mediaWidth = resource.intrinsicWidth.toFloat()
                mediaHeight = resource.intrinsicHeight.toFloat()
                imageView.setImageDrawable(resource)
                imageReady = true
                layoutMedia()
            }

            override fun onLoadCleared(placeholder: Drawable?) {
                imageView.setImageDrawable(null)
            }

            override fun onLoadFailed(errorDrawable: Drawable?) {
                if (!closed) loading.visibility = View.INVISIBLE
            }
        }
        imageTarget = target
        Glide.with(context.applicationContext).load(url)
            .downsample(DownsampleStrategy.AT_MOST)
            .diskCacheStrategy(DiskCacheStrategy.AUTOMATIC)
            .dontTransform().dontAnimate().into(target)
    }

    private fun startVideo(texture: SurfaceTexture) {
        val url = videoURL ?: return
        if (closed || !videoMode || player != null) return
        val next = MediaPlayer()
        player = next
        surface = Surface(texture)
        try {
            next.setSurface(surface)
            next.setOnVideoSizeChangedListener { current, width, height ->
                if (closed || player !== current) return@setOnVideoSizeChangedListener
                mediaWidth = width.toFloat()
                mediaHeight = height.toFloat()
                layoutMedia()
            }
            next.setOnPreparedListener { current ->
                if (closed || player !== current) return@setOnPreparedListener
                mediaWidth = current.videoWidth.toFloat()
                mediaHeight = current.videoHeight.toFloat()
                current.isLooping = true
                layoutMedia()
                current.start()
            }
            next.setOnInfoListener { current, what, _ ->
                if (!closed && player === current && what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) {
                    renderingStarted = true
                    layoutMedia()
                }
                false
            }
            next.setOnErrorListener { current, _, _ ->
                if (!closed && player === current) videoFailed()
                true
            }
            videoWorker.execute {
                try {
                    if (!closed) {
                        // HTTP source setup can block, even with prepareAsync.
                        next.setDataSource(context.applicationContext, Uri.parse(url))
                        next.prepareAsync()
                    }
                } catch (_: Exception) {
                    post { if (!closed && player === next) videoFailed() }
                }
            }
        } catch (_: Exception) {
            videoFailed()
        }
    }

    private fun videoFailed() {
        releasePlayer()
        videoMode = false
        videoView.alpha = 0f
        mediaWidth = 0f
        mediaHeight = 0f
        loadImage()
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        layoutMedia()
    }

    private fun layoutMedia() {
        if (closed || width <= 0 || height <= 0 || mediaWidth <= 0 || mediaHeight <= 0) return
        val cover = AttentionMediaLayout.usesCover(mediaWidth, mediaHeight, width.toFloat(), height.toFloat(), full)
        val areaWidth = if (cover) width else (contentRight - contentLeft).coerceAtLeast(0).coerceAtMost(maximumWidth)
        val areaHeight = if (cover) height else (contentBottom - contentTop).coerceAtLeast(0).coerceAtMost(maximumHeight)
        if (areaWidth <= 0 || areaHeight <= 0) return
        val frame = AttentionMediaLayout.frame(mediaWidth, mediaHeight, areaWidth.toFloat(), areaHeight.toFloat(), cover)
        val originX = if (cover) 0f else (contentLeft + contentRight - areaWidth) / 2f
        val originY = if (cover) 0f else (contentTop + contentBottom - areaHeight) / 2f
        val x = (originX + frame.x).roundToInt()
        val y = (originY + frame.y).roundToInt()
        val mediaView = if (videoMode) videoView else imageView
        val w = frame.width.roundToInt().coerceAtLeast(1)
        val h = frame.height.roundToInt().coerceAtLeast(1)
        mediaView.measure(MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY))
        mediaView.layout(x, y, x + w, y + h)
        if ((videoMode && renderingStarted) || (!videoMode && imageReady)) {
            mediaView.alpha = 1f
            loading.visibility = View.INVISIBLE
        }
    }

    override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
        startVideo(texture)
    }

    override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {}

    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) {
        // Rendering readiness is reported by MediaPlayer before revealing the
        // TextureView. Alpha-zero views need not receive texture draw callbacks.
    }

    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        releasePlayer()
        videoView.alpha = 0f
        return true
    }

    private fun releasePlayer() {
        val previous = player
        val previousSurface = surface
        player = null
        surface = null
        if (previous != null || previousSurface != null) {
            // Serialize release with in-flight HTTP source setup.
            videoWorker.execute {
                previous?.release()
                previousSurface?.release()
            }
        }
        renderingStarted = false
    }

    fun release() {
        if (closed) return
        closed = true
        releasePlayer()
        videoWorker.shutdown()
        imageTarget?.let { Glide.with(context.applicationContext).clear(it) }
        imageTarget = null
    }

    override fun onDetachedFromWindow() {
        release()
        super.onDetachedFromWindow()
    }
}
