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
        FcmPushBridge.storeToken(applicationContext, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
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

        val title = payload["title"] ?: "Score Beaten"
        val body = payload["body"] ?: buildFallbackBody(payload)
        val notification = NotificationCompat.Builder(this, getString(R.string.fcm_push_channel_id))
            .setSmallIcon(R.drawable.ic_stat_score_beaten)
            .setContentTitle(title)
            .setContentText(body)
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

    private fun buildFallbackBody(payload: Map<String, String>): String {
        val challengerName = payload["challenger_name"] ?: "Player"
        val beatenScore = payload["beaten_score"] ?: "0"
        val challengerScore = payload["challenger_score"] ?: "0"
        return "$challengerName beat your $beatenScore with $challengerScore"
    }

}
