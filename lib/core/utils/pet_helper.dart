import '../../providers/pet_provider.dart';

class PetHelper {
  static String getPetImage(PetType type, PetMood mood) {
    // 简化逻辑：所有心情暂时统一使用同一张图片
    // 如果后续有不同心情的图片，可以按文件名区分，例如 'assets/pets/${type.name}_${mood.name}.png'
    return type.assetPath;
  }
}