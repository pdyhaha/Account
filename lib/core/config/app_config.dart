class AppConfig {
  AppConfig._();

  // ========== LLM 配置 (火山引擎) ==========
  // Prefer injecting secrets via `--dart-define` so nothing sensitive is
  // committed to source control.
  //
  // Example:
  // flutter run --dart-define=LLM_API_KEY=... --dart-define=LLM_BASE_URL=... --dart-define=LLM_MODEL=...
  static const String llmApiKey =
      String.fromEnvironment('LLM_API_KEY', defaultValue: '');
  static const String llmBaseUrl = String.fromEnvironment(
    'LLM_BASE_URL',
    defaultValue: 'https://ark.cn-beijing.volces.com/api/v3',
  );
  static const String llmModel = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: 'ep-20260107165320-6hsq2',
  );
  
  // ========== 语音识别配置 (百度) ==========
  // 请访问 https://cloud.baidu.com/doc/SPEECH/s/Vk38lxil5 申请
  // 申请后替换下面的值以获得最佳语音识别体验
  static const String baiduSpeechApiKey = 'YOUR_BAIDU_API_KEY';
  static const String baiduSpeechSecretKey = 'YOUR_BAIDU_SECRET_KEY';
  
  // 是否启用百度语音识别（当设备不支持 Google 语音服务时自动启用）
  static bool get useBaiduSpeech => 
    baiduSpeechApiKey != 'YOUR_BAIDU_API_KEY' && 
    baiduSpeechSecretKey != 'YOUR_BAIDU_SECRET_KEY';
}
