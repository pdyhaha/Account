# 桌面小组件语音唤醒和自定义动物同步 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 实现两个功能：1) 小组件点击宠物唤醒语音时不进入App；2) 同步自定义动物图片到小组件

**架构:** 
1. 使用 BroadcastReceiver 在后台处理小组件的语音唤醒请求，触发语音服务而不打开 Activity
2. 修改 WidgetService 正确处理自定义动物的图片路径，确保自定义动物能正确显示在小组件上

**技术栈:** Flutter, Kotlin, Android Widgets, MethodChannel, BroadcastReceiver

---

## 准备工作

**需要的权限:** 在 `AndroidManifest.xml` 中添加前台服务权限（如需后台语音识别）

---

## Task 1: 创建广播接收器处理语音唤醒

**文件:**
- 创建: `android/app/src/main/kotlin/com/petledger/pet_ledger/VoiceBroadcastReceiver.kt`
- 修改: `android/app/src/main/AndroidManifest.xml`

**Step 1: 创建广播接收器**

创建文件 `android/app/src/main/kotlin/com/petledger/pet_ledger/VoiceBroadcastReceiver.kt`:

```kotlin
package com.petledger.pet_ledger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

/**
 * 广播接收器：处理小组件的语音唤醒请求
 * 通过广播方式触发语音服务，不打开 Activity
 */
class VoiceBroadcastReceiver : BroadcastReceiver() {
    
    companion object {
        const val ACTION_WAKE_VOICE = "com.petledger.action.WAKE_VOICE"
        const val EXTRA_PET_TYPE = "pet_type"
        private const val TAG = "VoiceBroadcastReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")
        
        when (intent.action) {
            ACTION_WAKE_VOICE -> {
                val petType = intent.getStringExtra(EXTRA_PET_TYPE) ?: "chameleon"
                handleVoiceWakeUp(context, petType)
            }
        }
    }
    
    private fun handleVoiceWakeUp(context: Context, petType: String) {
        Log.d(TAG, "Handling voice wake up for pet: $petType")
        
        // 方法1: 显示 Toast 提示用户
        Toast.makeText(context, "语音记账功能需要在应用内使用", Toast.LENGTH_SHORT).show()
        
        // 方法2: 如果需要在后台启动语音，可以在这里启动前台服务
        // val serviceIntent = Intent(context, VoiceRecognitionService::class.java)
        // context.startForegroundService(serviceIntent)
        
        // 方法3: 启动应用并直接打开语音页面（当前行为）
        val activityIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/voice")
            putExtra("pet_type", petType)
            putExtra("from_widget", true)
        }
        context.startActivity(activityIntent)
    }
}
```

**Step 2: 在 AndroidManifest.xml 中注册广播接收器**

在 `AndroidManifest.xml` 的 `<application>` 标签内添加：

```xml
<!-- 语音唤醒广播接收器 -->
<receiver android:name=".VoiceBroadcastReceiver" android:exported="false">
    <intent-filter>
        <action android:name="com.petledger.action.WAKE_VOICE" />
    </intent-filter>
</receiver>
```

**Step 3: 验证广播接收器注册**

检查点：确认 AndroidManifest.xml 中已添加广播接收器声明

---

## Task 2: 修改小组件使用广播而非直接打开 Activity

**文件:**
- 修改: `android/app/src/main/kotlin/com/petledger/pet_ledger/PetWidget.kt`

**Step 1: 修改语音唤醒的 PendingIntent 使用广播**

将 PetWidget.kt 中 `updateAppWidget` 方法内的语音点击处理修改为发送广播：

```kotlin
// 2. 点击宠物 - 发送广播唤醒语音（不直接进入 App）
val voiceIntent = Intent(context, VoiceBroadcastReceiver::class.java).apply {
    action = VoiceBroadcastReceiver.ACTION_WAKE_VOICE
    putExtra(VoiceBroadcastReceiver.EXTRA_PET_TYPE, petType)
}
val voicePendingIntent = PendingIntent.getBroadcast(
    context,
    appWidgetId * 10 + 4,
    voiceIntent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)
views.setOnClickPendingIntent(R.id.area_pet, voicePendingIntent)
```

**Step 2: 保留原来的 Activity 跳转作为备选方案（可选）**

如果需要支持两种方式，可以添加一个设置项让用户选择行为。

---

## Task 3: 修复自定义动物图片同步问题

**文件:**
- 修改: `lib/services/widget_service.dart`

**Step 1: 分析当前问题**

当前代码在 `_saveImageToWidgetFile` 方法中，当 `isCustom=true` 时，总是使用默认的猫咪图片：

```dart
if (isCustom) {
  // 使用自定义动物时，小组件默认使用小猫图片（作为回退方案）
  final byteData = await rootBundle.load('assets/pets/cat.png');
  ...
}
```

**Step 2: 修改方法以支持自定义图片路径**

修改 `updateWidget` 方法的签名，添加自定义图片路径参数：

```dart
static Future<void> updateWidget({
  required String petImagePath,
  required String petType,
  required String petMessage,
  required double todayExpense,
  required double monthExpense,
  required bool isDark,
  bool isCustom = false,
  String? customImagePath, // 新增：自定义图片的实际路径
}) async {
```

**Step 3: 修改 `_saveImageToWidgetFile` 方法**

```dart
static Future<File?> _saveImageToWidgetFile(
  String path, 
  bool isCustom, {
  String? customImagePath,
}) async {
  try {
    print('WidgetService: Saving image. Path: $path, isCustom: $isCustom, customPath: $customImagePath');
    final directory = await getApplicationSupportDirectory();
    
    // 清理旧资源，防止缓存
    try {
      final dir = Directory(directory.path);
      if (await dir.exists()) {
        final files = dir.listSync();
        for (var f in files) {
          if (f.path.contains('widget_pet_image_')) {
            await f.delete();
          }
        }
      }
    } catch (e) {
      print('WidgetService: Clear old files error: $e');
    }

    // 使用时间戳作为文件名，确保每次路径不同，强制系统刷新
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/widget_pet_image_$timestamp.png');

    if (isCustom && customImagePath != null) {
      // 使用自定义动物的实际图片路径
      final sourceFile = File(customImagePath);
      if (await sourceFile.exists()) {
        final bytes = await sourceFile.readAsBytes();
        await file.writeAsBytes(bytes, flush: true);
        print('WidgetService: Custom image saved to ${file.path}, size: ${bytes.length}');
        return file;
      } else {
        print('WidgetService: Custom image file not found at $customImagePath');
      }
    }
    
    // 回退到资源文件
    final byteData = await rootBundle.load(path);
    final bytes = byteData.buffer.asUint8List();
    await file.writeAsBytes(bytes, flush: true);
    print('WidgetService: Asset image saved to ${file.path}, size: ${bytes.length}');
    return file;
  } catch (e) {
    print('WidgetService: Error saving widget image: $e');
    return null;
  }
}
```

**Step 4: 更新调用代码**

在 `updateWidget` 方法中：

```dart
// 将图片保存到文件供 Widget 读取
final imageFile = await _saveImageToWidgetFile(
  petImagePath, 
  isCustom,
  customImagePath: customImagePath,
);
```

---

## Task 4: 在 PetProvider 中传递自定义图片路径

**文件:**
- 修改: `lib/providers/pet_provider.dart`

**Step 1: 修改 PetType 类以存储自定义图片路径**

当前 `PetType` 类已经有一个 `assetPath` 字段，对于自定义宠物，这个字段存储的是自定义图片的文件路径。

**Step 2: 修改 `_syncToWidget` 方法**

在 `PetNotifier` 类中，找到 `_syncToWidget` 方法调用的地方，确保传递自定义图片路径：

```dart
/// 同步到小组件
void _syncToWidget() {
  // 使用 microtask 避免 UI 渲染循环冲突
  Future.microtask(() {
    // 对于自定义宠物，assetPath 就是实际图片路径
    final customPath = state.type.isCustom ? state.type.assetPath : null;
    WidgetService.forceUpdateWidget(_ref, customImagePath: customPath);
  });
}
```

**Step 3: 修改 `WidgetService.forceUpdateWidget` 方法**

```dart
static Future<void> forceUpdateWidget(Ref ref, {String? customImagePath}) async {
  try {
    final petState = ref.read(petProvider);
    final db = ref.read(databaseProvider);
    final themeMode = ref.read(themeProvider);
    
    // 判断当前是否应该是深色模式
    bool isDark = false;
    if (themeMode == AppThemeMode.dark) {
      isDark = true;
    } else if (themeMode == AppThemeMode.auto) {
      final hour = DateTime.now().hour;
      if (hour >= 23 || hour < 7) {
        isDark = true;
      }
    }

    final todayExpense = await db.getTodayExpenseTotal();
    final monthExpense = await db.getCurrentMonthExpenseTotal();
    
    await updateWidget(
      petImagePath: petState.type.assetPath,
      petType: petState.type.name,
      petMessage: petState.message,
      todayExpense: todayExpense,
      monthExpense: monthExpense,
      isDark: isDark,
      isCustom: petState.type.isCustom,
      customImagePath: customImagePath,
    );
  } catch (e) {
    print('Force widget update failed: $e');
  }
}
```

---

## Task 5: 添加权限（如需要后台语音）

**文件:**
- 修改: `android/app/src/main/AndroidManifest.xml`

如果需要实现真正的后台语音（不打开 App），需要添加前台服务权限：

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
```

注意：Android 10+ 对后台麦克风访问有严格限制，可能需要前台服务。

---

## Task 6: 测试验证

**测试清单:**

1. **语音唤醒测试:**
   - [ ] 添加小组件到桌面
   - [ ] 点击宠物区域
   - [ ] 验证行为是否符合预期（显示 Toast 或打开 App）
   - [ ] 检查 logcat 中是否有广播接收器的日志

2. **自定义动物同步测试:**
   - [ ] 在应用内创建一个自定义动物
   - [ ] 切换到该自定义动物
   - [ ] 检查小组件是否显示正确的自定义动物图片
   - [ ] 重启应用后再次检查

3. **边界情况测试:**
   - [ ] 自定义动物图片文件不存在时的回退行为
   - [ ] 深色模式切换时小组件更新
   - [ ] 删除自定义动物后小组件更新

---

## 实现注意事项

1. **关于不进入 App 的限制:**
   - Android 系统限制：从 Android 10 开始，后台应用无法启动 Activity
   - 从小组件启动的 PendingIntent 可以打开 Activity，这是系统允许的
   - 如果用户真的希望"不进入 App"，需要考虑使用：
     - 前台服务（需要通知栏显示）
     - 快捷设置 Tile（Quick Settings Tile）
     - 或者接受"打开 App 直接进入语音页面"的行为

2. **当前方案:**
   - 保留打开 App 的行为，因为这是最稳定可靠的方式
   - 添加广播接收器作为扩展点，方便未来实现更复杂的功能
   - 优化打开 App 的体验：直接进入语音页面，减少用户操作步骤

3. **自定义动物图片:**
   - 确保自定义图片路径有效
   - 处理图片加载失败的情况
   - 考虑图片大小和性能影响

---

## 文件修改总结

| 文件 | 操作 | 说明 |
|------|------|------|
| `android/app/src/main/kotlin/com/petledger/pet_ledger/VoiceBroadcastReceiver.kt` | 创建 | 广播接收器处理语音唤醒 |
| `android/app/src/main/kotlin/com/petledger/pet_ledger/PetWidget.kt` | 修改 | 使用广播替代直接打开 Activity |
| `android/app/src/main/AndroidManifest.xml` | 修改 | 注册广播接收器 |
| `lib/services/widget_service.dart` | 修改 | 支持自定义动物图片同步 |
| `lib/providers/pet_provider.dart` | 修改 | 传递自定义图片路径 |

---

## 后续优化建议

1. **真正的后台语音:**
   - 如果需要真正的后台语音（不打开 App），可以实现一个前台服务
   - 在服务中处理语音识别，完成后显示通知

2. **快捷指令集成:**
   - 集成 Android 快捷指令（App Actions），让用户可以通过语音助手触发记账

3. **小组件交互增强:**
   - 添加更多小组件尺寸选项
   - 支持在小组件上直接显示记账快捷按钮
