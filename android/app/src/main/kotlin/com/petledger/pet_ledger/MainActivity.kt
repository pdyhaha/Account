package com.petledger.pet_ledger

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.petledger/speech"
    private val REQ_CODE_SPEECH_INPUT = 100

    private var pendingResult: MethodChannel.Result? = null
    
    // 存储从小组件传递的路由
    private var initialRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 获取从小组件传递的初始路由
        initialRoute = intent.getStringExtra("route")
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 必须设置 Intent，否则 getIntent() 还是旧的
        setIntent(intent)
        
        // 处理热启动时的路由
        val route = intent.getStringExtra("route")
        if (route != null) {
            sendRouteToFlutter(route)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        
        // 设置 MethodChannel 处理语音和路由
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecognition" -> startSpeechRecognition(result)
                "getInitialRoute" -> {
                    // 返回从小组件传递的初始路由
                    val route = initialRoute ?: "/"
                    result.success(route)
                    initialRoute = null // 使用后清理
                }
                else -> result.notImplemented()
            }
        }

        // 同时监听 voice_control 通道，处理可能的 Activity 关闭请求 (防御性编程)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.petledger/voice_control")
            .setMethodCallHandler { call, result ->
                if (call.method == "closeActivity") {
                    // 如果是在 MainActivity 中调用，可能只是想返回上一页或退出到后台
                    // 但由于语音浮层设计为独立入口，这里选择将 Activity 移至后台而不是销毁
                    moveTaskToBack(true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
    
    private fun sendRouteToFlutter(route: String) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("navigateTo", route)
        }
    }

    private fun startSpeechRecognition(result: MethodChannel.Result) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "请开始说话...")

        try {
            pendingResult = result
            startActivityForResult(intent, REQ_CODE_SPEECH_INPUT)
        } catch (e: Exception) {
            result.error("UNAVAILABLE", "Speech recognition not available", null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQ_CODE_SPEECH_INPUT) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val result = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                if (result != null && !result.isEmpty()) {
                    pendingResult?.success(result[0])
                } else {
                    pendingResult?.error("NO_MATCH", "No speech recognized", null)
                }
            } else {
                pendingResult?.error("CANCELED", "Speech recognition canceled", null)
            }
            pendingResult = null
        }
    }
}