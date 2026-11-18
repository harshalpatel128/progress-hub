package com.progresshub.progress_hub

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val alarmId = intent.getIntExtra("ALARM_ID", 1)
        val title = intent.getStringExtra("TITLE") ?: "Scheduled Session Alarm"
        val groupName = intent.getStringExtra("GROUP_NAME")
        val customAudioPath = intent.getStringExtra("CUSTOM_AUDIO_PATH")

        Log.d("AlarmActionReceiver", "Action received: $action for alarm: $alarmId")

        when (action) {
            "ACTION_DISMISS" -> {
                AlarmForegroundService.stopAlarm(context)
            }
            "ACTION_SNOOZE" -> {
                AlarmForegroundService.snoozeAlarm(context, alarmId, title, groupName, customAudioPath)
            }
        }
    }
}
