package com.example.jan_sarthi

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val SMS_CHANNEL = "com.example.jan_sarthi/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendDirectSms") {
                val phoneNumbers = call.argument<List<String>>("phoneNumbers")
                val message = call.argument<String>("message")

                if (phoneNumbers.isNullOrEmpty() || message.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENTS", "Phone numbers and message required", null)
                    return@setMethodCallHandler
                }

                // Verify SMS Permission
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(arrayOf(Manifest.permission.SEND_SMS, Manifest.permission.READ_PHONE_STATE), 1001)
                    }
                    result.error("PERMISSION_DENIED", "SEND_SMS permission not granted by user", null)
                    return@setMethodCallHandler
                }

                var anySent = false
                var lastException: Exception? = null

                for (rawPhone in phoneNumbers) {
                    val cleanPhone = rawPhone.trim().replace(Regex("[^0-9+]"), "")
                    if (cleanPhone.isBlank()) continue

                    val sent = sendSmsToRecipient(cleanPhone, message)
                    if (sent) {
                        anySent = true
                    }
                }

                if (anySent) {
                    result.success(true)
                } else {
                    result.error("SMS_FAILED", lastException?.localizedMessage ?: "Failed to dispatch SMS through cellular modem", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendSmsToRecipient(phone: String, message: String): Boolean {
        // Attempt 1: Context/Subscription-bound SmsManager
        try {
            val smsManager = getAppropriateSmsManager()
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            return true
        } catch (e: Exception) {
            android.util.Log.w("JAN_SARTHI_SMS", "Attempt 1 failed for $phone: ${e.message}")
        }

        // Attempt 2: Default System SmsManager
        try {
            @Suppress("DEPRECATION")
            val defaultManager = SmsManager.getDefault()
            val parts = defaultManager.divideMessage(message)
            if (parts.size > 1) {
                defaultManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                defaultManager.sendTextMessage(phone, null, message, null, null)
            }
            return true
        } catch (e: Exception) {
            android.util.Log.w("JAN_SARTHI_SMS", "Attempt 2 failed for $phone: ${e.message}")
        }

        // Attempt 3: Single-part fallback with 10-digit sanitized phone (strip country code)
        try {
            val localPhone = if (phone.startsWith("+91") && phone.length == 13) {
                phone.substring(3)
            } else if (phone.startsWith("91") && phone.length == 12) {
                phone.substring(2)
            } else {
                phone
            }

            @Suppress("DEPRECATION")
            val defaultManager = SmsManager.getDefault()
            val parts = defaultManager.divideMessage(message)
            if (parts.size > 1) {
                defaultManager.sendMultipartTextMessage(localPhone, null, parts, null, null)
            } else {
                defaultManager.sendTextMessage(localPhone, null, message, null, null)
            }
            return true
        } catch (e: Exception) {
            android.util.Log.e("JAN_SARTHI_SMS", "All SMS attempts failed for $phone: ${e.message}")
        }

        return false
    }

    private fun getAppropriateSmsManager(): SmsManager {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val subId = SubscriptionManager.getDefaultSmsSubscriptionId()
                if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                    context.getSystemService(SmsManager::class.java).createForSubscriptionId(subId)
                } else {
                    context.getSystemService(SmsManager::class.java) ?: @Suppress("DEPRECATION") SmsManager.getDefault()
                }
            } catch (e: Exception) {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }
}
