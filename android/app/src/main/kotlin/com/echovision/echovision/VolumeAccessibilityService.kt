package com.echovision.echovision

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * Accessibility Service to detect triple volume button press.
 * When user presses volume up or down 3 times quickly, it launches EchoVision.
 * This helps blind users open the app without seeing the screen.
 */
class VolumeAccessibilityService : AccessibilityService() {

    private var volumePressCount = 0
    private var lastPressTime = 0L
    private val TRIPLE_PRESS_TIMEOUT = 500L // 500ms between presses

    override fun onServiceConnected() {
        super.onServiceConnected()

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false

        // Only handle volume up or volume down key press (not release)
        if (event.action == KeyEvent.ACTION_DOWN) {
            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {

                val currentTime = System.currentTimeMillis()

                // Check if this press is within the timeout window
                if (currentTime - lastPressTime < TRIPLE_PRESS_TIMEOUT) {
                    volumePressCount++
                } else {
                    // Reset counter if too much time has passed
                    volumePressCount = 1
                }

                lastPressTime = currentTime

                // Triple press detected!
                if (volumePressCount >= 3) {
                    volumePressCount = 0
                    launchEchoVision()
                    return true // Consume the event
                }
            }
        }

        return false // Don't consume, let system handle volume change
    }

    private fun launchEchoVision() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(launchIntent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used, but required
    }

    override fun onInterrupt() {
        // Service interrupted
    }
}
