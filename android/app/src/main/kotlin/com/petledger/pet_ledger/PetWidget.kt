package com.petledger.pet_ledger

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import android.graphics.BitmapFactory
import android.os.Build

class PetWidget : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // 尺寸变化时重新更新
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }
    
    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                Log.d("PetWidget", "Updating widget $appWidgetId")
                // 增强型数据获取逻辑：尝试多个可能的 SharedPreferences 文件和前缀
                val prefsFiles = listOf("group.pet_ledger_widget", "HomeWidgetPreferences", "FlutterSharedPreferences")
                val keyPrefixes = listOf("", "DATA_", "flutter.")
                
                var petImagePath: String? = null
                var petType = "chameleon"
                var petMessage = "点我记账"
                var todayExpense = "¥0"
                var monthExpense = "¥0"
                var isDark = false

                // 遍历查找数据
                for (fileName in prefsFiles) {
                    val sp = context.getSharedPreferences(fileName, Context.MODE_PRIVATE)
                    if (sp.all.isNotEmpty()) {
                        Log.d("PetWidget", "Found data in SharedPreferences: $fileName")
                        
                        // 尝试获取各个字段
                        for (prefix in keyPrefixes) {
                            if (petImagePath == null) petImagePath = sp.getString("${prefix}pet_image_path", null)
                            if (petType == "chameleon") petType = sp.getString("${prefix}pet_type", "chameleon") ?: "chameleon"
                            if (petMessage == "点我记账") petMessage = sp.getString("${prefix}pet_message", "点我记账") ?: "点我记账"
                            if (todayExpense == "¥0") todayExpense = sp.getString("${prefix}today_expense", "¥0") ?: "¥0"
                            if (monthExpense == "¥0") monthExpense = sp.getString("${prefix}month_expense", "¥0") ?: "¥0"
                            
                            val darkVal = sp.all["${prefix}is_dark"]
                            if (darkVal != null) {
                                isDark = when (darkVal) {
                                    is Number -> darkVal.toInt() == 1
                                    is Boolean -> darkVal
                                    else -> false
                                }
                            }
                        }
                        
                        // Debug: 打印该文件的所有 key
                        sp.all.forEach { (k, v) -> Log.d("PetWidget", "File: $fileName, Key: $k, Value: $v") }
                    }
                }
                
                Log.d("PetWidget", "Final resolved data - petImagePath: $petImagePath, petType: $petType, isDark: $isDark")

                val views = RemoteViews(context.packageName, R.layout.app_widget)

                // 更新背景和颜色
                if (isDark) {
                    views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_background_dark)
                    val whiteColor = android.graphics.Color.WHITE
                    val grayColor = android.graphics.Color.parseColor("#AAAAAA")
                    val hintColor = android.graphics.Color.parseColor("#888888")
                    
                    views.setTextColor(R.id.tv_today_expense, whiteColor)
                    views.setTextColor(R.id.tv_month_expense, whiteColor)
                    views.setTextColor(R.id.tv_today_label, grayColor)
                    views.setTextColor(R.id.tv_month_label, grayColor)
                    views.setTextColor(R.id.tv_hint, hintColor)
                } else {
                    views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_background)
                    views.setTextColor(R.id.tv_today_expense, android.graphics.Color.parseColor("#333333"))
                    views.setTextColor(R.id.tv_month_expense, android.graphics.Color.parseColor("#333333"))
                    views.setTextColor(R.id.tv_today_label, android.graphics.Color.parseColor("#666666"))
                    views.setTextColor(R.id.tv_month_label, android.graphics.Color.parseColor("#666666"))
                    views.setTextColor(R.id.tv_hint, android.graphics.Color.parseColor("#999999"))
                }

                // 更新内容
                if (petImagePath != null) {
                    Log.d("PetWidget", "Loading image from: $petImagePath")
                    val file = java.io.File(petImagePath)
                    if (file.exists()) {
                        Log.d("PetWidget", "Image file exists, size: ${file.length()}")
                        // 使用采样加载大图，防止 Widget 更新失败 (IPC 限制 1MB)
                        val bitmap = decodeSampledBitmapFromFile(petImagePath, 300, 300)
                        if (bitmap != null) {
                            Log.d("PetWidget", "Bitmap decoded successfully: ${bitmap.width}x${bitmap.height}")
                            views.setImageViewBitmap(R.id.iv_pet_image, bitmap)
                        } else {
                            Log.e("PetWidget", "Failed to decode bitmap from $petImagePath")
                        }
                    } else {
                        Log.e("PetWidget", "Image file does NOT exist at $petImagePath")
                    }
                } else {
                    Log.d("PetWidget", "petImagePath is null")
                }
                views.setTextViewText(R.id.tv_hint, petMessage)
                views.setTextViewText(R.id.tv_today_expense, todayExpense)
                views.setTextViewText(R.id.tv_month_expense, monthExpense)

                // 1. 点击空白区域 - 进入 App 首页
                val homeIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("route", "/")
                }
                val homePendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId * 10 + 1,
                    homeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.area_home, homePendingIntent)

                // 2. 点击宠物 - 启动桌面透明语音浮层
                val voiceIntent = Intent(context, VoiceActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val voicePendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId * 10 + 4,
                    voiceIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.area_pet, voicePendingIntent)
                
                // 3. 点击今日支出 - 进入统计页面
                val statsIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("route", "/stats")
                }
                val statsPendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId * 10 + 3,
                    statsIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.area_today, statsPendingIntent)
                
                // 本月支出也可以进入统计
                views.setOnClickPendingIntent(R.id.area_month, statsPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d("PetWidget", "Widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                Log.e("PetWidget", "Error updating widget $appWidgetId", e)
            }
        }

        private fun decodeSampledBitmapFromFile(path: String, reqWidth: Int, reqHeight: Int): android.graphics.Bitmap? {
            // First decode with inJustDecodeBounds=true to check dimensions
            val options = android.graphics.BitmapFactory.Options()
            options.inJustDecodeBounds = true
            android.graphics.BitmapFactory.decodeFile(path, options)

            // Calculate inSampleSize
            options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)

            // Decode bitmap with inSampleSize set
            options.inJustDecodeBounds = false
            return android.graphics.BitmapFactory.decodeFile(path, options)
        }

        private fun calculateInSampleSize(options: android.graphics.BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
            // Raw height and width of image
            val height = options.outHeight
            val width = options.outWidth
            var inSampleSize = 1

            if (height > reqHeight || width > reqWidth) {
                val halfHeight = height / 2
                val halfWidth = width / 2

                // Calculate the largest inSampleSize value that is a power of 2 and keeps both
                // height and width larger than the requested height and width.
                while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                    inSampleSize *= 2
                }
            }
            return inSampleSize
        }


    }
}