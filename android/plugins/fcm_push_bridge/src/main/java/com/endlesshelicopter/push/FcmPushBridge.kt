package com.endlesshelicopter.push

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class FcmPushBridge(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val PREFS_NAME = "fcm_push_bridge"
        private const val KEY_PENDING_TOKEN = "pending_token"
        private const val KEY_LATEST_TOKEN = "latest_token"
        private const val KEY_PENDING_OPEN_PAYLOAD = "pending_open_payload"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 47821

        const val EXTRA_NOTIFICATION_PAYLOAD = "score_beaten_payload"
        const val EXTRA_OPEN_LEADERBOARD = "open_leaderboard"

        @Volatile
        private var activeInstance: FcmPushBridge? = null

        @Volatile
        private var lastFirebaseStatus: String = "Firebase has not been checked yet."

        fun storeToken(context: Context, token: String) {
            val prefs = preferences(context)
            prefs.edit()
                .putString(KEY_PENDING_TOKEN, token)
                .putString(KEY_LATEST_TOKEN, token)
                .apply()
            activeInstance?.emitSignal("push_token_received", token)
        }

        fun storeLaunchPayload(context: Context, payloadJson: String) {
            preferences(context).edit()
                .putString(KEY_PENDING_OPEN_PAYLOAD, payloadJson)
                .apply()
            activeInstance?.emitSignal("push_notification_opened", payloadJson)
        }

        private fun preferences(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    init {
        activeInstance = this
    }

    override fun getPluginName(): String = "FCMPushBridge"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("push_token_received", String::class.java),
        SignalInfo("push_notification_opened", String::class.java),
    )

    override fun onMainResume() {
        super.onMainResume()
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
    fun isPushSupported(): Boolean = isFirebaseConfigured()

    @UsedByGodot
    fun getFirebaseStatus(): String {
        isFirebaseConfigured()
        return lastFirebaseStatus
    }

    @UsedByGodot
    fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }

        val currentActivity = activity ?: return false
        return ContextCompat.checkSelfPermission(
            currentActivity,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }

        val currentActivity = activity ?: return
        if (hasNotificationPermission()) {
            return
        }

        currentActivity.runOnUiThread {
            ActivityCompat.requestPermissions(
                currentActivity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        }
    }

    @UsedByGodot
    fun fetchToken() {
        val currentActivity = activity ?: return
        if (!isFirebaseConfigured()) {
            return
        }

        FirebaseMessaging.getInstance().token.addOnCompleteListener(currentActivity) { task ->
            if (task.isSuccessful && !task.result.isNullOrBlank()) {
                storeToken(currentActivity.applicationContext, task.result)
            }
        }
    }

    @UsedByGodot
    fun consumeStoredToken(): String {
        val currentActivity = activity ?: return ""
        val prefs = preferences(currentActivity.applicationContext)
        val token = prefs.getString(KEY_PENDING_TOKEN, "") ?: ""
        if (token.isNotEmpty()) {
            prefs.edit().remove(KEY_PENDING_TOKEN).apply()
        }
        return token
    }

    @UsedByGodot
    fun getLatestToken(): String {
        val currentActivity = activity ?: return ""
        return preferences(currentActivity.applicationContext)
            .getString(KEY_LATEST_TOKEN, "") ?: ""
    }

    @UsedByGodot
    fun consumeLaunchPayload(): String {
        val currentActivity = activity ?: return ""
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
        val payload = consumeLaunchPayload(currentActivity)
        if (payload.isNotEmpty()) {
            emitSignal("push_notification_opened", payload)
        }
    }

    private fun consumeLaunchPayload(currentActivity: android.app.Activity): String {
        val prefs = preferences(currentActivity.applicationContext)
        val intentPayload = currentActivity.intent?.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD).orEmpty()
        val storedPayload = prefs.getString(KEY_PENDING_OPEN_PAYLOAD, "") ?: ""
        val payload = if (intentPayload.isNotEmpty()) intentPayload else storedPayload

        if (payload.isNotEmpty()) {
            currentActivity.intent?.removeExtra(EXTRA_NOTIFICATION_PAYLOAD)
            currentActivity.intent?.removeExtra(EXTRA_OPEN_LEADERBOARD)
            prefs.edit().remove(KEY_PENDING_OPEN_PAYLOAD).apply()
        }

        return payload
    }

    private fun isFirebaseConfigured(): Boolean {
        val currentActivity = activity ?: return false
        return ensureFirebaseInitialized(currentActivity.applicationContext)
    }

    private fun ensureFirebaseInitialized(context: Context): Boolean {
        try {
            if (FirebaseApp.getApps(context).isEmpty()) {
                FirebaseApp.initializeApp(context)
            }
            if (FirebaseApp.getApps(context).isNotEmpty()) {
                lastFirebaseStatus = "Firebase initialized from Android resources."
                return true
            }
        } catch (_error: Throwable) {
            lastFirebaseStatus = "Firebase automatic initialization failed: ${_error.message.orEmpty()}"
        }

        return initializeFirebaseFromResources(context)
    }

    private fun initializeFirebaseFromResources(context: Context): Boolean {
        return try {
            val appId = resourceString(context, "google_app_id")
            val senderId = resourceString(context, "gcm_defaultSenderId")
            val apiKey = resourceString(context, "google_api_key")
            val projectId = resourceString(context, "project_id")
            val storageBucket = resourceString(context, "google_storage_bucket")

            if (appId.isBlank() || senderId.isBlank() || apiKey.isBlank() || projectId.isBlank()) {
                lastFirebaseStatus = "Firebase resources missing. appId=${appId.isNotBlank()} senderId=${senderId.isNotBlank()} apiKey=${apiKey.isNotBlank()} projectId=${projectId.isNotBlank()}"
                return false
            }

            val optionsBuilder = FirebaseOptions.Builder()
                .setApplicationId(appId)
                .setGcmSenderId(senderId)
                .setApiKey(apiKey)
                .setProjectId(projectId)

            if (storageBucket.isNotBlank()) {
                optionsBuilder.setStorageBucket(storageBucket)
            }

            FirebaseApp.initializeApp(context, optionsBuilder.build())
            val initialized = FirebaseApp.getApps(context).isNotEmpty()
            lastFirebaseStatus = if (initialized) {
                "Firebase initialized from embedded config."
            } else {
                "Firebase initialization returned no app instance."
            }
            initialized
        } catch (_error: Throwable) {
            lastFirebaseStatus = "Firebase manual initialization failed: ${_error.javaClass.simpleName}: ${_error.message.orEmpty()}"
            false
        }
    }

    private fun resourceString(context: Context, name: String): String {
        val resourceId = context.resources.getIdentifier(name, "string", context.packageName)
        if (resourceId == 0) {
            return ""
        }
        return context.getString(resourceId)
    }
}
