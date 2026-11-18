package com.progresshub.progress_hub

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra("ALARM_ID", 1)
        val title = intent.getStringExtra("TITLE") ?: "Scheduled Session Alarm"
        val groupName = intent.getStringExtra("GROUP_NAME")
        val customAudioPath = intent.getStringExtra("CUSTOM_AUDIO_PATH")

        Log.d("AlarmReceiver", "Alarm $alarmId triggered! Title: $title, Song: $customAudioPath")

        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
            action = "START_ALARM"
            putExtra("ALARM_ID", alarmId)
            putExtra("TITLE", title)
            putExtra("GROUP_NAME", groupName)
            putExtra("CUSTOM_AUDIO_PATH", customAudioPath)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
