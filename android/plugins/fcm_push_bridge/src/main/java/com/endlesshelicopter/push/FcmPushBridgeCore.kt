package com.endlesshelicopter.push

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import java.security.MessageDigest
import java.lang.ref.WeakReference

object FcmPushBridgeCore {
    private const val PREFS_NAME = "fcm_push_bridge"
    private const val KEY_PENDING_TOKEN = "pending_token"
    private const val KEY_LATEST_TOKEN = "latest_token"
    private const val KEY_PENDING_OPEN_PAYLOAD = "pending_open_payload"
    private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 47821
    private const val INVALID_ANDROID_ID = "9774d56d682e549c"

    @Volatile
    private var lastFirebaseStatus: String = "Firebase has not been checked yet."

    @Volatile
    private var cachedApplicationContext: Context? = null

    @Volatile
    private var cachedActivityRef: WeakReference<Activity>? = null

    fun rememberContext(context: Context?) {
        if (context != null) {
            cachedApplicationContext = context.applicationContext
        }
    }

    fun rememberActivity(activity: Activity?) {
        if (activity != null) {
            cachedActivityRef = WeakReference(activity)
            rememberContext(activity.applicationContext)
        }
    }

    fun storeToken(context: Context, token: String) {
        rememberContext(context)
        preferences(context).edit()
            .putString(KEY_PENDING_TOKEN, token)
            .putString(KEY_LATEST_TOKEN, token)
            .apply()
    }

    fun consumeStoredToken(context: Context): String {
        rememberContext(context)
        val prefs = preferences(context)
        val token = prefs.getString(KEY_PENDING_TOKEN, "") ?: ""
        if (token.isNotEmpty()) {
            prefs.edit().remove(KEY_PENDING_TOKEN).apply()
        }
        return token
    }

    fun getLatestToken(context: Context): String {
        rememberContext(context)
        return preferences(context).getString(KEY_LATEST_TOKEN, "") ?: ""
    }

    fun storeLaunchPayload(context: Context, payloadJson: String) {
        rememberContext(context)
        preferences(context).edit()
            .putString(KEY_PENDING_OPEN_PAYLOAD, payloadJson)
            .apply()
    }

    fun consumeLaunchPayload(activity: Activity): String {
        rememberActivity(activity)
        val prefs = preferences(activity.applicationContext)
        val intentPayload = activity.intent?.getStringExtra(FcmPushBridge.EXTRA_NOTIFICATION_PAYLOAD).orEmpty()
        val storedPayload = prefs.getString(KEY_PENDING_OPEN_PAYLOAD, "") ?: ""
        val payload = if (intentPayload.isNotEmpty()) intentPayload else storedPayload

        if (payload.isNotEmpty()) {
            activity.intent?.removeExtra(FcmPushBridge.EXTRA_NOTIFICATION_PAYLOAD)
            activity.intent?.removeExtra(FcmPushBridge.EXTRA_OPEN_LEADERBOARD)
            prefs.edit().remove(KEY_PENDING_OPEN_PAYLOAD).apply()
        }

        return payload
    }

    fun isFirebaseConfigured(context: Context?): Boolean {
        if (context == null) {
            lastFirebaseStatus = "Android context is unavailable."
            return false
        }
        rememberContext(context)
        return ensureFirebaseInitialized(context)
    }

    fun getFirebaseStatus(context: Context?): String {
        isFirebaseConfigured(context)
        return lastFirebaseStatus
    }

    fun isFirebaseConfigured(): Boolean = isFirebaseConfigured(resolveApplicationContext())

    fun getFirebaseStatus(): String = getFirebaseStatus(resolveApplicationContext())

    fun hasNotificationPermission(activity: Activity?): Boolean {
        rememberActivity(activity)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }

        if (activity == null) {
            return false
        }

        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun hasNotificationPermission(): Boolean = hasNotificationPermission(resolveCurrentActivity())

    fun requestNotificationPermission(activity: Activity?) {
        rememberActivity(activity)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }

        if (activity == null || hasNotificationPermission(activity)) {
            return
        }

        activity.runOnUiThread {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        }
    }

    fun requestNotificationPermission() {
        requestNotificationPermission(resolveCurrentActivity())
    }

    fun fetchToken(activity: Activity?) {
        rememberActivity(activity)
        val context = activity?.applicationContext ?: resolveApplicationContext()
        if (context == null || !isFirebaseConfigured(context)) {
            return
        }

        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful && !task.result.isNullOrBlank()) {
                storeToken(context, task.result)
            }
        }
    }

    fun fetchToken() {
        fetchToken(resolveCurrentActivity())
    }

    fun consumeStoredToken(): String {
        val context = resolveApplicationContext() ?: return ""
        return consumeStoredToken(context)
    }

    fun getLatestToken(): String {
        val context = resolveApplicationContext() ?: return ""
        return getLatestToken(context)
    }

    fun getStablePlayerId(context: Context): String = buildStableIdentity(
        context,
        "player",
        "android-player-",
    )

    fun getStablePlayerId(): String {
        val context = resolveApplicationContext() ?: return ""
        return getStablePlayerId(context)
    }

    fun getStableDeviceId(context: Context): String = buildStableIdentity(
        context,
        "device",
        "android-device-",
    )

    fun getStableDeviceId(): String {
        val context = resolveApplicationContext() ?: return ""
        return getStableDeviceId(context)
    }

    fun consumeLaunchPayload(): String {
        val activity = resolveCurrentActivity() ?: return ""
        return consumeLaunchPayload(activity)
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

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

    private fun resolveApplicationContext(): Context? {
        cachedApplicationContext?.let { return it }
        FcmPushBridge.currentContextOrNull()?.let { return it }
        return try {
            val activityThreadClass = Class.forName("android.app.ActivityThread")
            val currentApplication = activityThreadClass
                .getMethod("currentApplication")
                .invoke(null) as? Application
            currentApplication?.applicationContext
        } catch (_error: Throwable) {
            null
        }
    }

    private fun resolveCurrentActivity(): Activity? {
        cachedActivityRef?.get()?.let { return it }
        FcmPushBridge.currentActivityOrNull()?.let { return it }
        return try {
            val activityThreadClass = Class.forName("android.app.ActivityThread")
            val currentActivityThread = activityThreadClass
                .getMethod("currentActivityThread")
                .invoke(null)
                ?: return null

            val activitiesField = activityThreadClass.getDeclaredField("mActivities")
            activitiesField.isAccessible = true
            val activities = activitiesField.get(currentActivityThread) as? Map<*, *> ?: return null

            for (record in activities.values) {
                if (record == null) {
                    continue
                }

                val recordClass = record.javaClass
                val pausedField = recordClass.getDeclaredField("paused")
                pausedField.isAccessible = true
                val isPaused = pausedField.getBoolean(record)
                if (isPaused) {
                    continue
                }

                val activityField = recordClass.getDeclaredField("activity")
                activityField.isAccessible = true
                val activity = activityField.get(record) as? Activity
                if (activity != null) {
                    return activity
                }
            }
            null
        } catch (_error: Throwable) {
            null
        }
    }

    private fun buildStableIdentity(context: Context, purpose: String, prefix: String): String {
        rememberContext(context)
        val androidId = resolveAndroidId(context)
        if (androidId.isEmpty()) {
            return ""
        }

        val packageName = context.packageName.trim()
        if (packageName.isEmpty()) {
            return ""
        }

        val rawValue = "$purpose:$packageName:$androidId"
        return prefix + sha256Hex(rawValue).take(24)
    }

    private fun resolveAndroidId(context: Context): String {
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID,
        ).orEmpty().trim()

        if (
            androidId.isEmpty() ||
            androidId == "0000000000000000" ||
            androidId.equals("unknown", ignoreCase = true) ||
            androidId == INVALID_ANDROID_ID
        ) {
            return ""
        }

        return androidId
    }

    private fun sha256Hex(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }
}
