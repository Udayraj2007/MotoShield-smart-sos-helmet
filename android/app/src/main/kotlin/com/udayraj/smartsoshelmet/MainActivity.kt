package com.udayraj.smartsoshelmet

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.udayraj.smartsoshelmet/direct_sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendDirectSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")

                    if (!phone.isNullOrEmpty() && !message.isNullOrEmpty()) {
                        try {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                applicationContext.getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }

                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(phone, null, message, null, null)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_FAILED", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone or message is empty", null)
                    }
                }
                "makeDirectCall" -> {
                    val phone = call.argument<String>("phone")
                    if (!phone.isNullOrEmpty()) {
                        try {
                            enableSpeakerphone()
                            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phone"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                enableSpeakerphone()
                                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("CALL_FAILED", e2.localizedMessage, null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone number is empty", null)
                    }
                }
                "enableSpeakerphone" -> {
                    try {
                        enableSpeakerphone()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SPEAKER_FAILED", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enableSpeakerphone() {
        try {
            val audioManager = applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_IN_CALL
            audioManager.isSpeakerphoneOn = true
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
            audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, maxVolume, 0)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}