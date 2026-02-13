import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 语音识别服务 - 使用 Sherpa-ONNX 流式识别
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isDisposed = false;
  
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription? _recordSub;
  
  /// 识别结果回调 (text, isFinal)
  /// 流式过程中 isFinal 为 false，停止时为 true
  Function(String text, bool isFinal)? onResult;
  
  /// 错误回调
  Function(String error)? onError;
  
  /// 状态变化回调
  Function(bool isListening)? onStatusChange;

  bool get isListening => _isListening;

  /// 初始化
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    // 检查权限
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        onError?.call('需要麦克风权限');
        return false;
      }
    }

    // 初始化底层库
    sherpa.initBindings();

    // 初始化模型
    await _initSherpa();
    
    _isInitialized = true;
    return true;
  }

  /// 初始化 Sherpa 模型
  Future<void> _initSherpa() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory(path.join(appDir.path, 'sherpa_model'));
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      // 模型文件路径
      final encoderPath = path.join(modelDir.path, 'encoder-epoch-99-avg-1.int8.onnx');
      final decoderPath = path.join(modelDir.path, 'decoder-epoch-99-avg-1.onnx');
      final joinerPath = path.join(modelDir.path, 'joiner-epoch-99-avg-1.onnx');
      final tokensPath = path.join(modelDir.path, 'tokens.txt');

      // 检查模型是否存在，不存在则从 Assets 复制
      if (!await File(encoderPath).exists() || !await File(tokensPath).exists()) {
        print("Model files missing in app directory. Copying from assets...");
        
        // 确保 assets 包含在 pubspec.yaml 中
        await _copyAssetToLocal('assets/sherpa_model/encoder-epoch-99-avg-1.int8.onnx', encoderPath);
        await _copyAssetToLocal('assets/sherpa_model/decoder-epoch-99-avg-1.onnx', decoderPath);
        await _copyAssetToLocal('assets/sherpa_model/joiner-epoch-99-avg-1.onnx', joinerPath);
        await _copyAssetToLocal('assets/sherpa_model/tokens.txt', tokensPath);
        
        print("Model files copied successfully.");
      }

      print("Loading model from: ${modelDir.path}");

      // 创建流式识别器配置
      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath,
          ),
          tokens: tokensPath,
          modelType: 'zipformer',
        ),
        ruleFsts: '',
      );

      _recognizer = sherpa.OnlineRecognizer(config);
      print("Sherpa-ONNX Online Recognizer initialized successfully!");
      
    } catch (e) {
      print("Sherpa init error: $e");
      onError?.call("语音服务初始化失败: $e");
      _recognizer = null;
    }
  }

  /// 复制 Asset 文件到本地
  Future<void> _copyAssetToLocal(String assetPath, String localPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await File(localPath).writeAsBytes(bytes, flush: true);
    } catch (e) {
      print("Error copying asset $assetPath: $e");
      throw "模型文件缺失，请检查安装包完整性 ($e)";
    }
  }

  /// 开始录音 (流式处理)

  Future<bool> startListening() async {
    if (!_isInitialized) await initialize();
    if (_isListening) return true;

    try {
      if (_recognizer == null) {
        // 尝试重新初始化
        await _initSherpa();
        if (_recognizer == null) {
          onError?.call("语音模型加载失败，请检查网络或重启应用");
          return false;
        }
      }

      // 创建新的流
      _stream?.free();
      _stream = _recognizer!.createStream();

      // 检查录音权限
      if (!await _recorder.hasPermission()) {
        onError?.call("无录音权限");
        return false;
      }

      // 启动录音流 (PCM 16bit, 16000Hz, 单声道)
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      _isListening = true;
      onStatusChange?.call(true);

      // 监听音频数据
      _recordSub = stream.listen((data) {
        _processAudioData(data);
      }, onError: (e) {
        print("Audio stream error: $e");
        stopListening();
      });
      
      return true;
    } catch (e) {
      print('Start recording error: $e');
      onError?.call('启动录音失败: $e');
      return false;
    }
  }

  /// 处理音频数据
  void _processAudioData(Uint8List data) {
    // 捕获快照，防止处理过程中被其他线程置空
    final recognizer = _recognizer;
    final stream = _stream;
    
    if (_isDisposed || recognizer == null || stream == null) return;

    try {
      // 将 PCM 16bit (Int16) 转换为 Float32 (-1.0 ~ 1.0)
      final samples = _convertBytesToFloat32(data);
      
      // 喂给识别器
      stream.acceptWaveform(samples: samples, sampleRate: 16000);

      // 解码
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }

      // 获取实时结果
      final result = recognizer.getResult(stream);
      final text = result.text;
      
      if (text.isNotEmpty) {
        onResult?.call(text, false);
      }
    } catch (e) {
      print('SpeechService: Error processing audio data: $e');
    }
  }

  /// 停止录音
  Future<void> stopListening() async {
    if (_isDisposed) return; // 已销毁则直接返回，防止触碰 Native
    if (!_isListening) return;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      await _recordSub?.cancel();
      _recordSub = null;
      
      _isListening = false;
      onStatusChange?.call(false);

      // 获取最终结果
      if (_recognizer != null && _stream != null) {
        // 告诉识别器输入已结束，这对于流式模型非常重要
        _stream!.inputFinished();
        
        // 最后再 decode 一次，确保缓冲区的数据被处理
        while (_recognizer!.isReady(_stream!)) {
          _recognizer!.decode(_stream!);
        }
        
        final result = _recognizer!.getResult(_stream!);
        if (result.text.isNotEmpty) {
          onResult?.call(result.text, true);
        }
        // _stream!.free(); // 暂时注释掉，防止 Native 崩溃
        _stream = null;
      }
    } catch (e) {
      print('Stop recording error: $e');
      onError?.call('停止录音失败: $e');
    }
  }

  /// 取消录音
  Future<void> cancelListening() async {
    await stopListening();
  }

  Future<void> dispose() async {
    // 改为软清理：只停止录音和释放当前流，保留模型实例常驻内存
    // 这样可以彻底避免 Native 层销毁时的竞态崩溃
    
    // 1. 优先取消订阅，防止音频流继续回调
    await _recordSub?.cancel();
    _recordSub = null;

    // 2. 停止录音硬件
    try {
      // 检查是否正在录音
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      print('SpeechService: Error stopping recorder during dispose: $e');
    }
    
    _isListening = false;
    onStatusChange?.call(false);
    

    // 3. 安全处理 Stream 资源
    final streamToFree = _stream;
    _stream = null;
    // streamToFree?.free(); // 暂时注释掉以防止 Native 崩溃 (Mutex Destroyed)

    // 注意：不再释放 _recognizer 和 _recorder，让它们常驻内存
    // 也不再设置 _isDisposed = true，允许服务被复用
  }

  // --- 工具方法 ---

  /// 将 PCM 16bit 字节转换为 Float32List
  Float32List _convertBytesToFloat32(Uint8List bytes) {
    // 确保字节数是偶数
    final length = bytes.length ~/ 2 * 2;
    final values = Float32List(length ~/ 2);
    // 关键修复：使用 offsetInBytes 和 lengthInBytes 创建 ByteData
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

    for (var i = 0; i < length; i += 2) {
      int short = data.getInt16(i, Endian.little);
      values[i ~/ 2] = short / 32768.0;
    }
    return values;
  }
}

final speechService = SpeechService();
