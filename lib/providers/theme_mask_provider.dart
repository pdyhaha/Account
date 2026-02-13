import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 管理主题切换时的全屏遮罩状态
final themeMaskProvider = StateProvider<bool>((ref) => false);
