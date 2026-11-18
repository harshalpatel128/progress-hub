package com.progresshub.progress_hub

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File

class AlarmForegroundService : Service() {

    companion object {
        private const val TAG = "AlarmForegroundService"
        const val CHANNEL_ID = "progresshub_active_alarm_v4"
        const val NOTIFICATION_ID = 99999

        @Volatile
        var isRinging: Boolean = false
            private set

        @Volatile
        var activeAlarmId: Int = -1
            private set

        @Volatile
        var activeAlarmTitle: String = ""
            private set

        fun stopAlarm(context: Context) {
            val intent = Intent(context, AlarmForegroundService::class.java).apply {
                action = "STOP_ALARM"
            }
            context.startService(intent)
        }

        fun snoozeAlarm(context: Context, alarmId: Int, title: String, groupName: String?, customAudioPath: String?) {
            stopAlarm(context)
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
                    putExtra("ALARM_ID", alarmId)
                    putExtra("TITLE", "[Snoozed] $title")
                    putExtra("GROUP_NAME", groupName)
                    putExtra("CUSTOM_AUDIO_PATH", customAudioPath)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    alarmId + 88888,
                    snoozeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val triggerTime = System.currentTimeMillis() + 10 * 60 * 1000L
                val showIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val showPendingIntent = PendingIntent.getActivity(
                    context,
                    alarmId + 88889,
                    showIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTime, showPendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                Log.d(TAG, "Alarm $alarmId snoozed for 10 minutes")
            } catch (e: Exception) {
                Log.e(TAG, "Error snoozing alarm: ${e.message}")
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: "START_ALARM"

        if (action == "STOP_ALARM") {
            cleanupAndStop()
            return START_NOT_STICKY
        }

        val alarmId = intent?.getIntExtra("ALARM_ID", 1) ?: 1
        val title = intent?.getStringExtra("TITLE") ?: "Scheduled Session Alarm"
        val groupName = intent?.getStringExtra("GROUP_NAME")
        val customAudioPath = intent?.getStringExtra("CUSTOM_AUDIO_PATH")

        activeAlarmId = alarmId
        activeAlarmTitle = title
        isRinging = true

        acquireWakeLock()
        createNotificationChannel()

        val notification = buildAlarmNotification(alarmId, title, groupName, customAudioPath)
        startForeground(NOTIFICATION_ID, notification)

        startSoundAndVibration(customAudioPath)

        return START_STICKY
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "ProgressHub:AlarmWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(15 * 60 * 1000L) // 15 mins max timeout
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wakeLock: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ProgressHub Active Ringing Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Fullscreen ringing alarms with stop & snooze controls"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildAlarmNotification(
        alarmId: Int,
        title: String,
        groupName: String?,
        customAudioPath: String?
    ): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("ALARM_RINGING", true)
            putExtra("ALARM_ID", alarmId)
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            alarmId,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = "ACTION_DISMISS"
            putExtra("ALARM_ID", alarmId)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId + 1000,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = "ACTION_SNOOZE"
            putExtra("ALARM_ID", alarmId)
            putExtra("TITLE", title)
            putExtra("GROUP_NAME", groupName)
            putExtra("CUSTOM_AUDIO_PATH", customAudioPath)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId + 2000,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val bodyText = if (!groupName.isNullOrEmpty()) "Goal: $groupName • Tap to open app" else "Time for your scheduled learning session!"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("⏰ $title")
            .setContentText(bodyText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openAppPendingIntent)
            .setFullScreenIntent(openAppPendingIntent, true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "DISMISS", dismissPendingIntent)
            .addAction(android.R.drawable.ic_popup_sync, "SNOOZE (+10m)", snoozePendingIntent)
            .build()
    }

    private fun startSoundAndVibration(customAudioPath: String?) {
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer()

            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxAlarmVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val currentAlarmVol = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            if (currentAlarmVol == 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, (maxAlarmVol * 0.85).toInt(), 0)
            }

            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            mediaPlayer!!.setAudioAttributes(attributes)

            var loadedCustom = false
            if (!customAudioPath.isNullOrEmpty()) {
                val file = File(customAudioPath)
                if (file.exists() && file.canRead()) {
                    Log.d(TAG, "Playing custom song from file: $customAudioPath")
                    mediaPlayer!!.setDataSource(file.absolutePath)
                    loadedCustom = true
                }
            }

            if (!loadedCustom) {
                Log.d(TAG, "Playing default system alarm tone")
                val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                mediaPlayer!!.setDataSource(this, alarmUri)
            }

            mediaPlayer!!.isLooping = true
            mediaPlayer!!.prepare()
            mediaPlayer!!.start()
            Log.d(TAG, "MediaPlayer started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting MediaPlayer: ${e.message}")
            try {
                mediaPlayer?.release()
                mediaPlayer = MediaPlayer()
                val fallbackUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                mediaPlayer!!.setDataSource(this, fallbackUri)
                mediaPlayer!!.isLooping = true
                mediaPlayer!!.prepare()
                mediaPlayer!!.start()
            } catch (fallbackError: Exception) {
                Log.e(TAG, "Fallback sound error: ${fallbackError.message}")
            }
        }

        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator ?: getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            val pattern = longArrayOf(0, 800, 400, 800, 400, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error vibrating: ${e.message}")
        }
    }

    private fun cleanupAndStop() {
        isRinging = false
        activeAlarmId = -1
        activeAlarmTitle = ""

        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing mediaPlayer: ${e.message}")
        }

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling vibrator: ${e.message}")
        }

        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wakeLock: ${e.message}")
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "AlarmForegroundService stopped and cleaned up")
    }

    override fun onDestroy() {
        cleanupAndStop()
        super.onDestroy()
    }
}
