package ai.pams.pam_flutter

import kotlin.math.max
import kotlin.math.min

// Pure geometry, shared policy with AttentionMediaLayout.swift.
internal object AttentionMediaLayout {
    data class Frame(val x: Float, val y: Float, val width: Float, val height: Float)

    fun usesCover(mediaWidth: Float, mediaHeight: Float, width: Float, height: Float, full: Boolean): Boolean {
        if (!full || mediaWidth <= 0 || mediaHeight <= 0 || width <= 0 || height <= width) return false
        val mediaRatio = mediaWidth / mediaHeight
        val viewportRatio = width / height
        // At most 20% of the image area can be cropped on a portrait phone.
        return min(mediaRatio / viewportRatio, viewportRatio / mediaRatio) >= 0.8f
    }

    fun frame(mediaWidth: Float, mediaHeight: Float, width: Float, height: Float, cover: Boolean): Frame {
        if (mediaWidth <= 0 || mediaHeight <= 0 || width <= 0 || height <= 0) return Frame(0f, 0f, 0f, 0f)
        val scale = if (cover) max(width / mediaWidth, height / mediaHeight)
                    else min(width / mediaWidth, height / mediaHeight)
        val resultWidth = mediaWidth * scale
        val resultHeight = mediaHeight * scale
        return Frame((width - resultWidth) / 2, (height - resultHeight) / 2, resultWidth, resultHeight)
    }
}
