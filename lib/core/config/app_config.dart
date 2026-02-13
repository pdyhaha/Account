class AppConfig {
  AppConfig._();

  // ========== LLM 配置 (火山引擎) ==========
  static const String llmApiKey = 'd863d891-00f5-47f9-8852-f51280c32875';
  static const String llmBaseUrl = 'https://ark.cn-beijing.volces.com/api/v3';
  static const String llmModel = 'ep-20260107165320-6hsq2';
  
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
