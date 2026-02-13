package com.petledger.pet_ledger

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * 桌面语音悬浮窗服务 - 不启动App，直接在桌面显示
 */
class VoiceFloatService : Service() {

    companion object {
        const val ACTION_SHOW = "com.petledger.action.SHOW_VOICE_FLOAT"
        const val EXTRA_PET_IMAGE_PATH = "pet_image_path"
        const val NOTIFICATION_CHANNEL_ID = "voice_float_channel"
        const val NOTIFICATION_ID = 1002
    }

    private var windowManager: WindowManager? = null
    private var floatView: View? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_SHOW) {
            val petImagePath = intent.getStringExtra(EXTRA_PET_IMAGE_PATH)
            startForeground(NOTIFICATION_ID, createNotification())
            showFloatWindow(petImagePath)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "语音记账",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "桌面语音记账悬浮窗"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("正在语音记账")
            .setContentText("点击打开应用")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showFloatWindow(petImagePath: String?) {
        if (floatView != null) return

        // 检查悬浮窗权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "请授予悬浮窗权限", Toast.LENGTH_LONG).show()
            stopSelf()
            return
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        // 创建简单的悬浮窗视图
        floatView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xCC000000.toInt())
            setPadding(50, 50, 50, 50)

            // 宠物图片
            val petImage = ImageView(context).apply {
                layoutParams = LinearLayout.LayoutParams(200, 200)
                setImageResource(android.R.drawable.ic_menu_help)
                // 尝试加载自定义图片
                petImagePath?.let { path ->
                    val file = File(path)
                    if (file.exists()) {
                        val bitmap = android.graphics.BitmapFactory.decodeFile(path)
                        if (bitmap != null) {
                            setImageBitmap(bitmap)
                        }
                    }
                }
            }
            addView(petImage)

            // 状态文字
            val statusText = TextView(context).apply {
                text = "点击麦克风开始说话"
                setTextColor(0xFFFFFFFF.toInt())
                textSize = 18f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 30 }
            }
            addView(statusText)

            // 麦克风按钮
            val micButton = ImageButton(context).apply {
                layoutParams = LinearLayout.LayoutParams(150, 150).apply { topMargin = 50 }
                setImageResource(android.R.drawable.ic_btn_speak_now)
                setBackgroundColor(0xFF4CAF50.toInt())
                setOnClickListener {
                    if (isListening) {
                        stopListening()
                        statusText.text = "点击麦克风开始说话"
                    } else {
                        startListening(statusText)
                    }
                }
            }
            addView(micButton)

            // 关闭按钮
            val closeButton = ImageButton(context).apply {
                layoutParams = LinearLayout.LayoutParams(100, 100).apply { 
                    topMargin = 50
                    gravity = Gravity.END
                }
                setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                setOnClickListener {
                    hideFloatWindow()
                }
            }
            addView(closeButton)
        }

        windowManager?.addView(floatView, params)
    }

    private fun startListening(statusText: TextView) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Toast.makeText(this, "语音识别不可用", Toast.LENGTH_SHORT).show()
            return
        }

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                isListening = true
                statusText.text = "正在听..."
            }

            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                isListening = false
                statusText.text = "处理中..."
            }

            override fun onError(error: Int) {
                isListening = false
                statusText.text = "识别失败，请重试"
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    val text = matches[0]
                    statusText.text = "识别结果: $text"
                    // TODO: 保存记账数据
                    Toast.makeText(this@VoiceFloatService, "已识别: $text", Toast.LENGTH_SHORT).show()
                } else {
                    statusText.text = "没有听清"
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!partial.isNullOrEmpty()) {
                    statusText.text = partial[0]
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        speechRecognizer?.startListening(intent)
    }

    private fun stopListening() {
        speechRecognizer?.stopListening()
        isListening = false
    }

    private fun hideFloatWindow() {
        speechRecognizer?.destroy()
        speechRecognizer = null

        if (floatView != null) {
            windowManager?.removeView(floatView)
            floatView = null
        }

        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        hideFloatWindow()
    }
}
