package com.nmg.xinmeisms

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentResolver
import android.net.Uri
import android.content.Context
import android.telephony.TelephonyManager
import android.telephony.SubscriptionManager
import android.telephony.SubscriptionInfo
import android.util.Log
import android.content.pm.PackageManager
import android.provider.Settings

class MainActivity: FlutterActivity() {
    private val SMS_CHANNEL = "com.nmg.xinmeisms/sms"
    private val DEVICE_CHANNEL = "com.nmg.xinmeisms/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 现有的短信删除通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MethodChannel", "Received method call: ${call.method}")
            when (call.method) {
                "deleteSms" -> {
                    val id = call.argument<String>("id")
                    Log.d("MethodChannel", "Deleting SMS with ID: $id")
                    val deleted = deleteSms(id)
                    result.success(deleted)
                }
                "getSmsSubscriptionId" -> {
                    val messageId = call.argument<String>("messageId")
                    Log.d("MethodChannel", "Getting subscription ID for message: $messageId")
                    val subId = getSmsSubscriptionId(messageId)
                    result.success(subId)
                }
                else -> {
                    Log.d("MethodChannel", "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        // 新增设备信息通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimInfo" -> {
                    result.success(getSimInfo())
                }
                "getDeviceId" -> {
                    val deviceId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(deviceId)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun deleteSms(messageId: String?): Boolean {
        if (messageId == null) return false
        
        try {
            val uri = Uri.parse("content://sms")
            val selection = "_id=?"
            val selectionArgs = arrayOf(messageId)
            val deletedRows = contentResolver.delete(uri, selection, selectionArgs)
            return deletedRows > 0
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun getSmsSubscriptionId(messageId: String?): Int {
        try {
            val uri = Uri.parse("content://sms/inbox")
            val cursor = contentResolver.query(
                uri,
                arrayOf("_id", "sub_id"),
                "_id = ?",
                arrayOf(messageId),
                null
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    val subIdColumn = it.getColumnIndex("sub_id")
                    if (subIdColumn != -1) {
                        val subId = it.getInt(subIdColumn)
                        Log.d("SmsInfo", "Message ID: $messageId, SubId: $subId")
                        return subId
                    }
                }
            }
            Log.d("SmsInfo", "No sub_id found for message: $messageId")
        } catch (e: Exception) {
            Log.e("SmsInfo", "Error getting sub_id for message: $messageId", e)
            e.printStackTrace()
        }
        return -1
    }

    private fun getSimInfo(): List<Map<String, Any>> {
        val simInfoList = mutableListOf<Map<String, Any>>()
        try {
            val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val subscriptionInfoList = subscriptionManager.activeSubscriptionInfoList

            Log.d("SimInfo", "Active SIM cards: ${subscriptionInfoList?.size ?: 0}")

            subscriptionInfoList?.forEach { info ->
                val simInfo = mapOf(
                    "slotIndex" to info.simSlotIndex,
                    "subscriptionId" to info.subscriptionId,
                    "number" to (info.number ?: "未知"),
                    "displayName" to (info.displayName ?: "SIM${info.simSlotIndex + 1}")
                )
                simInfoList.add(simInfo)
                Log.d("SimInfo", "SIM details: $simInfo")
            }
        } catch (e: Exception) {
            Log.e("SimInfo", "Error getting SIM info", e)
            e.printStackTrace()
        }
        
        return simInfoList
    }
}
