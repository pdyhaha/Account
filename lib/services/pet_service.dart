import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/pet_provider.dart';

class PetService {
  /// 初始化宠物资源：将预设宠物图片复制到 App Documents 目录
  static Future<void> initializePetAssets() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final petsDir = Directory('${docsDir.path}/pets');
      
      if (!petsDir.existsSync()) {
        petsDir.createSync(recursive: true);
      }
      
      // 复制所有预设宠物到本地存储
      for (final pet in PetType.presets) {
        final fileName = pet.assetPath.split('/').last; // e.g. bee.png
        final file = File('${petsDir.path}/$fileName');
        
        // 如果文件不存在，则复制
        // 注意：如果 Assets 更新了，这里可能需要强制覆盖逻辑，但简单起见先只判断是否存在
        if (!file.existsSync()) {
          try {
            final data = await rootBundle.load(pet.assetPath);
            final bytes = data.buffer.asUint8List();
            await file.writeAsBytes(bytes, flush: true);
            print('PetService: Copied ${pet.name} to ${file.path}');
          } catch (e) {
            print('PetService: Failed to copy ${pet.name}: $e');
          }
        }
      }
    } catch (e) {
      print('PetService: Initialize assets failed: $e');
    }
  }

  /// 获取宠物的本地文件绝对路径
  /// 
  /// - 自定义宠物：直接返回 assetPath (它已经是文件路径)
  /// - 预设宠物：返回 Documents/pets/ 下的路径
  static Future<String?> getLocalPetPath(PetType pet) async {
    if (pet.isCustom) {
      final file = File(pet.assetPath);
      if (await file.exists()) {
        return pet.assetPath;
      }
      print('PetService: Custom pet file not found: ${pet.assetPath}');
      return null; 
    }
    
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = pet.assetPath.split('/').last;
    final path = '${docsDir.path}/pets/$fileName';
    final file = File(path);
    
    if (await file.exists()) {
      return path;
    }
    
    // 如果本地没有（可能被清理或初始化失败），尝试重新复制
    try {
      print('PetService: Preset pet not found at $path, trying to recover...');
      final data = await rootBundle.load(pet.assetPath);
      final bytes = data.buffer.asUint8List();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      print('PetService: Recovered ${pet.name} to $path');
      return path;
    } catch (e) {
      print('PetService: Recover preset pet failed: $e');
      return null;
    }
  }
}
