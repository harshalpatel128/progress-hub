package com.progresshub.progress_hub

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.progresshub/native_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 1
                        val timestampMillis = call.argument<Long>("timestampMillis") ?: 0L
                        val title = call.argument<String>("title") ?: "Alarm"
                        val groupName = call.argument<String>("groupName")
                        val customAudioPath = call.argument<String>("customAudioPath")

                        scheduleNativeAlarm(id, timestampMillis, title, groupName, customAudioPath)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "scheduleAlarm error: ${e.message}")
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 1
                        cancelNativeAlarm(id)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "triggerAlarmNow" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 1
                        val title = call.argument<String>("title") ?: "Alarm"
                        val groupName = call.argument<String>("groupName")
                        val customAudioPath = call.argument<String>("customAudioPath")

                        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
                            action = "START_ALARM"
                            putExtra("ALARM_ID", id)
                            putExtra("TITLE", title)
                            putExtra("GROUP_NAME", groupName)
                            putExtra("CUSTOM_AUDIO_PATH", customAudioPath)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TRIGGER_ERROR", e.message, null)
                    }
                }
                "stopAlarm" -> {
                    try {
                        AlarmForegroundService.stopAlarm(context)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "isAlarmRinging" -> {
                    result.success(AlarmForegroundService.isRinging)
                }
                "getActiveAlarmId" -> {
                    result.success(AlarmForegroundService.activeAlarmId)
                }
                "getActiveAlarmTitle" -> {
                    result.success(AlarmForegroundService.activeAlarmTitle)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleNativeAlarm(
        id: Int,
        timestampMillis: Long,
        title: String,
        groupName: String?,
        customAudioPath: String?
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("ALARM_ID", id)
            putExtra("TITLE", title)
            putExtra("GROUP_NAME", groupName)
            putExtra("CUSTOM_AUDIO_PATH", customAudioPath)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            this,
            id + 5000,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmClockInfo = AlarmManager.AlarmClockInfo(timestampMillis, showPendingIntent)
        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        Log.d("MainActivity", "Native Alarm Clock set: id=$id at timestamp=$timestampMillis")
    }

    private fun cancelNativeAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        Log.d("MainActivity", "Native Alarm cancelled: id=$id")
    }
}
