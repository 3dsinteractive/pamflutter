package ai.pams.pam_flutter

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AttentionMediaLayoutTest {
    @Test
    fun fullPortraitKeepsPhoneCoverageWithBoundedCropping() {
        assertTrue(AttentionMediaLayout.usesCover(1080f, 1920f, 390f, 844f, true))
        assertFalse(AttentionMediaLayout.usesCover(1080f, 1920f, 360f, 900f, true))
        val frame = AttentionMediaLayout.frame(1080f, 1920f, 390f, 844f, true)
        assertTrue(frame.width >= 390f && frame.height >= 844f)
        assertTrue(frame.x <= 0f && frame.y <= 0f)
        assertTrue(390f * 844f / (frame.width * frame.height) >= 0.8f)
    }

    @Test
    fun squareWideAndLandscapeWindowsContainPortraitMedia() {
        for ((width, height) in listOf(800f to 800f, 760f to 800f, 844f to 390f, 1366f to 1024f, 768f to 1024f)) {
            assertFalse(AttentionMediaLayout.usesCover(1080f, 1920f, width, height, true))
        }
    }

    @Test
    fun largeAlwaysContainsEvenOnMatchingPortraitScreens() {
        assertFalse(AttentionMediaLayout.usesCover(1080f, 1920f, 1080f, 1920f, false))
    }

    @Test
    fun containPreservesWholeMediaAndCentersAcrossRatios() {
        for ((mw, mh) in listOf(1080f to 1920f, 900f to 1600f, 1080f to 2340f, 1920f to 1080f)) {
            for ((width, height) in listOf(390f to 844f, 800f to 800f, 844f to 390f, 1366f to 1024f)) {
                val frame = AttentionMediaLayout.frame(mw, mh, width, height, false)
                assertTrue(frame.x >= -0.001f && frame.y >= -0.001f)
                assertTrue(frame.width <= width + 0.001f && frame.height <= height + 0.001f)
                assertTrue(abs(frame.width / frame.height - mw / mh) < 0.0001f)
                assertTrue(abs(frame.x + frame.width / 2 - width / 2) < 0.001f)
                assertTrue(abs(frame.y + frame.height / 2 - height / 2) < 0.001f)
            }
        }
    }

    @Test
    fun unknownMetadataAndEmptyViewportsHaveNoVisibleFrame() {
        assertEquals(0f, AttentionMediaLayout.frame(0f, 0f, 800f, 800f, false).width)
        assertEquals(0f, AttentionMediaLayout.frame(1080f, 1920f, 0f, 390f, false).height)
        assertFalse(AttentionMediaLayout.usesCover(0f, 0f, 390f, 844f, true))
    }

    @Test
    fun resizingDoesNotDependOnMetadataArrivalOrder() {
        val first = AttentionMediaLayout.frame(1080f, 1920f, 390f, 844f, true)
        AttentionMediaLayout.frame(1080f, 1920f, 844f, 390f, false)
        assertEquals(first, AttentionMediaLayout.frame(1080f, 1920f, 390f, 844f, true))
    }
}
