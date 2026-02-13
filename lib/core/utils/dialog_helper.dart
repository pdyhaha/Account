import 'package:flutter/material.dart';

class DialogHelper {
  /// 显示管家风格的底部弹窗
  /// 
  /// 特点：
  /// 1. 使用 showModalBottomSheet，自带下滑关闭手势
  /// 2. useRootNavigator: true，确保遮挡底部导航栏
  /// 3. 统一的圆角、阴影和拖动手柄样式
  static Future<T?> showButlerBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    double? heightFactor,
    bool showHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true, // 允许自定义高度
      useRootNavigator: true,   // 关键：遮挡底部导航栏
      enableDrag: true,         // 启用下滑关闭
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: heightFactor != null
              ? MediaQuery.of(context).size.height * heightFactor
              : null, // null 则自适应内容高度
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9, // 最大高度限制
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部拖动手柄
                if (showHandle)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                
                // 标题栏 (可选)
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  
                // 内容区域
                heightFactor != null
                    ? Expanded(child: child) // 固定高度模式：撑满剩余空间
                    : Flexible(child: child), // 自适应模式：包裹内容
              ],
            ),
          ),
        ),
      ),
    );
  }
}
