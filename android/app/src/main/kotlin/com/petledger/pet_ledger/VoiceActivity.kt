package com.petledger.pet_ledger

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class VoiceActivity : FlutterActivity() {
    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getDartEntrypointFunctionName(): String {
        return "voiceMain"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 建立专用通道处理 Activity 关闭
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.petledger/voice_control")
            .setMethodCallHandler { call, result ->
                if (call.method == "closeActivity") {
                    // 只移至后台，不销毁 Activity
                    //这是避免 Flutter 引擎销毁导致的 Mutex Destroyed 崩溃的唯一可靠方法
                    moveTaskToBack(true)
                    overridePendingTransition(0, 0)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
