package com.endlesshelicopter.push

import android.app.Activity
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class FcmPushBridge(godot: Godot) : GodotPlugin(godot) {
    companion object {
        const val EXTRA_NOTIFICATION_PAYLOAD = "score_beaten_payload"
        const val EXTRA_OPEN_LEADERBOARD = "open_leaderboard"

        @Volatile
        private var activeInstance: FcmPushBridge? = null

        fun storeToken(context: Context, token: String) {
            FcmPushBridgeCore.storeToken(context, token)
            activeInstance?.emitSignal("push_token_received", token)
        }

        fun storeLaunchPayload(context: Context, payloadJson: String) {
            FcmPushBridgeCore.storeLaunchPayload(context, payloadJson)
            activeInstance?.emitSignal("push_notification_opened", payloadJson)
        }

        internal fun currentActivityOrNull(): Activity? = activeInstance?.activity

        internal fun currentContextOrNull(): Context? = activeInstance?.activity?.applicationContext
    }

    init {
        activeInstance = this
        FcmPushBridgeCore.rememberActivity(activity)
    }

    override fun getPluginName(): String = "FCMPushBridge"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("push_token_received", String::class.java),
        SignalInfo("push_notification_opened", String::class.java),
    )

    override fun onMainResume() {
        super.onMainResume()
        FcmPushBridgeCore.rememberActivity(activity)
        emitPendingToken()
        emitPendingLaunchPayload()
    }

    override fun onMainDestroy() {
        if (activeInstance === this) {
            activeInstance = null
        }
        super.onMainDestroy()
    }

    @UsedByGodot
    fun isPushSupported(): Boolean {
        FcmPushBridgeCore.rememberActivity(activity)
        return FcmPushBridgeCore.isFirebaseConfigured(activity?.applicationContext)
    }

    @UsedByGodot
    fun getFirebaseStatus(): String {
        FcmPushBridgeCore.rememberActivity(activity)
        return FcmPushBridgeCore.getFirebaseStatus(activity?.applicationContext)
    }

    @UsedByGodot
    fun hasNotificationPermission(): Boolean {
        FcmPushBridgeCore.rememberActivity(activity)
        return FcmPushBridgeCore.hasNotificationPermission(activity)
    }

    @UsedByGodot
    fun requestNotificationPermission() {
        FcmPushBridgeCore.rememberActivity(activity)
        FcmPushBridgeCore.requestNotificationPermission(activity)
    }

    @UsedByGodot
    fun fetchToken() {
        FcmPushBridgeCore.rememberActivity(activity)
        FcmPushBridgeCore.fetchToken(activity)
    }

    @UsedByGodot
    fun consumeStoredToken(): String {
        val currentActivity = activity ?: return ""
        FcmPushBridgeCore.rememberActivity(currentActivity)
        return FcmPushBridgeCore.consumeStoredToken(currentActivity.applicationContext)
    }

    @UsedByGodot
    fun getLatestToken(): String {
        val currentActivity = activity ?: return ""
        FcmPushBridgeCore.rememberActivity(currentActivity)
        return FcmPushBridgeCore.getLatestToken(currentActivity.applicationContext)
    }

    @UsedByGodot
    fun consumeLaunchPayload(): String {
        val currentActivity = activity ?: return ""
        FcmPushBridgeCore.rememberActivity(currentActivity)
        return consumeLaunchPayload(currentActivity)
    }

    private fun emitPendingToken() {
        val token = consumeStoredToken()
        if (token.isNotEmpty()) {
            emitSignal("push_token_received", token)
        }
    }

    private fun emitPendingLaunchPayload() {
        val currentActivity = activity ?: return
        val payload = FcmPushBridgeCore.consumeLaunchPayload(currentActivity)
        if (payload.isNotEmpty()) {
            emitSignal("push_notification_opened", payload)
        }
    }

    private fun consumeLaunchPayload(currentActivity: android.app.Activity): String {
        return FcmPushBridgeCore.consumeLaunchPayload(currentActivity)
    }
}
