import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/alarm_model.dart';

class AlarmAudioService {
  static final AlarmAudioService instance = AlarmAudioService._internal();
  AlarmAudioService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;
  AlarmModel? _currentRingingAlarm;

  bool get isPlaying => _isPlaying;
  AlarmModel? get currentRingingAlarm => _currentRingingAlarm;

  Future<void> initialize() async {
    _player = AudioPlayer();
    await _configureAlarmAudioContext();
  }

  Future<void> _configureAlarmAudioContext() async {
    if (_player == null) return;

    try {
      await _player!.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error configuring audio context: $e');
    }
  }

  Future<void> startRinging(AlarmModel alarm) async {
    if (_player == null) await initialize();

    try {
      await stopRinging();

      _currentRingingAlarm = alarm;
      _isPlaying = true;

      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);

      if (alarm.customAudioPath != null && File(alarm.customAudioPath!).existsSync()) {
        debugPrint('Playing custom song from file: ${alarm.customAudioPath}');
        await _player!.play(DeviceFileSource(alarm.customAudioPath!));
      } else {
        debugPrint('No custom audio file specified; native Android alarm handles system ringtone');
      }
    } catch (e) {
      debugPrint('Error in startRinging: $e');
    }
  }

  Future<void> stopRinging() async {
    try {
      if (_player != null) {
        await _player!.stop();
      }
      _isPlaying = false;
      _currentRingingAlarm = null;
    } catch (e) {
      debugPrint('Error in stopRinging: $e');
    }
  }

  Future<void> previewAudio(String filePath) async {
    if (_player == null) await initialize();
    try {
      await stopRinging();
      _isPlaying = true;
      await _player!.setReleaseMode(ReleaseMode.release);
      await _player!.setVolume(1.0);
      await _player!.play(DeviceFileSource(filePath));
    } catch (e) {
      debugPrint('Error in previewAudio: $e');
    }
  }
}
