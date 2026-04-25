package com.endlesshelicopter.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

class ScoreBeatenFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        FcmPushBridgeCore.rememberContext(applicationContext)
        FcmPushBridge.storeToken(applicationContext, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        FcmPushBridgeCore.rememberContext(applicationContext)
        if (message.data.isEmpty()) {
            return
        }

        val payload = HashMap(message.data)
        val payloadJson = JSONObject(payload as Map<*, *>).toString()
        showNotification(payload, payloadJson)
    }

    private fun showNotification(payload: Map<String, String>, payloadJson: String) {
        createNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(FcmPushBridge.EXTRA_NOTIFICATION_PAYLOAD, payloadJson)
            putExtra(FcmPushBridge.EXTRA_OPEN_LEADERBOARD, true)
        } ?: return

        val pendingIntent = PendingIntent.getActivity(
            this,
            payloadJson.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notificationType = payload["type"].orEmpty()
        val title = resolveNotificationTitle(payload, notificationType)
        val body = resolveNotificationBody(payload, notificationType)
        val notificationIcon = when (notificationType) {
            "daily_missions" -> R.drawable.ic_stat_daily_missions
            "score_beaten" -> R.drawable.ic_stat_helicopter
            "app_update" -> R.drawable.ic_stat_helicopter
            else -> R.drawable.ic_stat_helicopter
        }
        val notification = NotificationCompat.Builder(this, getString(R.string.fcm_push_channel_id))
            .setSmallIcon(notificationIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(this).notify(payloadJson.hashCode(), notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            getString(R.string.fcm_push_channel_id),
            getString(R.string.fcm_push_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun resolveNotificationTitle(payload: Map<String, String>, notificationType: String): String {
        payload["title"]?.takeIf { it.isNotBlank() }?.let { return it }
        return when (notificationType) {
            "app_update" -> "Update Available"
            "daily_missions" -> "Daily Missions Ready"
            "score_beaten" -> "Score Beaten"
            else -> "Endless Helicopter"
        }
    }

    private fun resolveNotificationBody(payload: Map<String, String>, notificationType: String): String {
        payload["body"]?.takeIf { it.isNotBlank() }?.let { return it }
        return when (notificationType) {
            "app_update" -> buildAppUpdateFallbackBody(payload)
            "daily_missions" -> "New missions are live. Complete them to unlock vehicles and finishes."
            "score_beaten" -> buildScoreBeatenFallbackBody(payload) ?: "Someone beat one of your scores."
            else -> "Tap to open Endless Helicopter."
        }
    }

    private fun buildAppUpdateFallbackBody(payload: Map<String, String>): String {
        val versionName = payload["latest_version_name"]?.takeIf { it.isNotBlank() } ?: "a new version"
        val releaseSummary = payload["release_summary"]?.takeIf { it.isNotBlank() }
        return if (releaseSummary != null) {
            "Version $versionName is ready. $releaseSummary"
        } else {
            "Version $versionName is ready to install."
        }
    }

    private fun buildScoreBeatenFallbackBody(payload: Map<String, String>): String? {
        val challengerName = payload["challenger_name"]?.takeIf { it.isNotBlank() } ?: "Player"
        val beatenScore = payload["beaten_score"]?.toLongOrNull() ?: return null
        val challengerScore = payload["challenger_score"]?.toLongOrNull() ?: return null
        return "$challengerName beat your $beatenScore with $challengerScore"
    }
}
