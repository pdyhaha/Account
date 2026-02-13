import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 音效服务
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  /// 初始化
  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(0.7);
  }

  /// 设置是否启用音效
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 播放按键音
  Future<void> playKeyTap() async {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    // 由于我们没有音频文件，使用系统震动代替
    // 后续可以替换为: await _player.play(AssetSource('sounds/key_tap.mp3'));
  }

  /// 播放气泡音（键盘按键）
  Future<void> playBubble() async {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    // await _player.play(AssetSource('sounds/bubble.mp3'));
  }

  /// 播放收银机音效（记账成功）
  Future<void> playCashRegister() async {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    // await _player.play(AssetSource('sounds/cash_register.mp3'));
  }

  /// 播放猫叫
  Future<void> playMeow() async {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    // await _player.play(AssetSource('sounds/meow.mp3'));
  }

  /// 播放狗叫
  Future<void> playBark() async {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    // await _player.play(AssetSource('sounds/bark.mp3'));
  }

  /// 播放成功音效
  Future<void> playSuccess() async {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    // await _player.play(AssetSource('sounds/success.mp3'));
  }

  /// 播放错误音效
  Future<void> playError() async {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    // await _player.play(AssetSource('sounds/error.mp3'));
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// 全局音效服务实例
final soundService = SoundService();
