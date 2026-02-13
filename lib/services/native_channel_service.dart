import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// 处理与 Android 原生端的通信
class NativeChannelService {
  static const MethodChannel _channel = MethodChannel('com.petledger/speech');
  static GoRouter? _router;
  
  /// 初始化并设置路由
  static void init(GoRouter router) {
    _router = router;
    _channel.setMethodCallHandler(_handleMethodCall);
    _checkInitialRoute();
  }
  
  /// 处理从原生端传来的方法调用
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'navigateTo':
        final route = call.arguments as String?;
        if (route != null && _router != null) {
          _navigateToRoute(route);
        }
        break;
    }
  }
  
  /// 检查初始路由（从小组件启动时）
  static Future<void> _checkInitialRoute() async {
    try {
      final route = await _channel.invokeMethod<String>('getInitialRoute');
      if (route != null && route != '/') {
        // 减少延迟，更快显示语音浮层
        Future.delayed(const Duration(milliseconds: 100), () {
          _navigateToRoute(route);
        });
      }
    } catch (e) {
      print('Failed to get initial route: $e');
    }
  }
  
  /// 导航到指定路由
  static void _navigateToRoute(String route) {
    if (_router == null) return;
    
    // 使用 push 而非 go，这样关闭语音界面后能返回之前的页面
    _router!.push(route);
  }
}