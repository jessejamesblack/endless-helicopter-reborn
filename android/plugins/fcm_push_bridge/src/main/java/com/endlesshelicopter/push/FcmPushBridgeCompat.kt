package com.endlesshelicopter.push

import android.app.Activity
import android.content.Context

class FcmPushBridgeCompat {
    companion object {
        @JvmStatic
        fun isFirebaseConfigured(): Boolean = FcmPushBridgeCore.isFirebaseConfigured()

        @JvmStatic
        fun isFirebaseConfigured(context: Context?): Boolean = FcmPushBridgeCore.isFirebaseConfigured(context)

        @JvmStatic
        fun getFirebaseStatus(): String = FcmPushBridgeCore.getFirebaseStatus()

        @JvmStatic
        fun getFirebaseStatus(context: Context?): String = FcmPushBridgeCore.getFirebaseStatus(context)

        @JvmStatic
        fun hasNotificationPermission(): Boolean = FcmPushBridgeCore.hasNotificationPermission()

        @JvmStatic
        fun hasNotificationPermission(activity: Activity?): Boolean = FcmPushBridgeCore.hasNotificationPermission(activity)

        @JvmStatic
        fun requestNotificationPermission() {
            FcmPushBridgeCore.requestNotificationPermission()
        }

        @JvmStatic
        fun requestNotificationPermission(activity: Activity?) {
            FcmPushBridgeCore.requestNotificationPermission(activity)
        }

        @JvmStatic
        fun fetchToken() {
            FcmPushBridgeCore.fetchToken()
        }

        @JvmStatic
        fun fetchToken(activity: Activity?) {
            FcmPushBridgeCore.fetchToken(activity)
        }

        @JvmStatic
        fun consumeStoredToken(): String = FcmPushBridgeCore.consumeStoredToken()

        @JvmStatic
        fun consumeStoredToken(context: Context?): String {
            return if (context == null) "" else FcmPushBridgeCore.consumeStoredToken(context)
        }

        @JvmStatic
        fun getLatestToken(): String = FcmPushBridgeCore.getLatestToken()

        @JvmStatic
        fun getLatestToken(context: Context?): String {
            return if (context == null) "" else FcmPushBridgeCore.getLatestToken(context)
        }

        @JvmStatic
        fun getStablePlayerId(): String = FcmPushBridgeCore.getStablePlayerId()

        @JvmStatic
        fun getStablePlayerId(context: Context?): String {
            return if (context == null) "" else FcmPushBridgeCore.getStablePlayerId(context)
        }

        @JvmStatic
        fun getStableDeviceId(): String = FcmPushBridgeCore.getStableDeviceId()

        @JvmStatic
        fun getStableDeviceId(context: Context?): String {
            return if (context == null) "" else FcmPushBridgeCore.getStableDeviceId(context)
        }

        @JvmStatic
        fun consumeLaunchPayload(): String = FcmPushBridgeCore.consumeLaunchPayload()

        @JvmStatic
        fun consumeLaunchPayload(activity: Activity?): String {
            return if (activity == null) "" else FcmPushBridgeCore.consumeLaunchPayload(activity)
        }
    }
}
