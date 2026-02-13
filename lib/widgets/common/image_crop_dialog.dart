import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../../core/theme/colors.dart';

class ImageCropDialog extends StatefulWidget {
  final File imageFile;

  const ImageCropDialog({super.key, required this.imageFile});

  static Future<Uint8List?> show(BuildContext context, File file) {
    return Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageCropDialog(imageFile: file),
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final _controller = CropController();
  bool _isCropping = false;
  Uint8List? _imageBytes;
  bool _isInitialLoading = true;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      debugPrint('CropDialog: Start loading image: ${widget.imageFile.path}');
      
      final bytes = await widget.imageFile.readAsBytes();
      
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1024,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('解码失败');
      final finalBytes = byteData.buffer.asUint8List();

      debugPrint('CropDialog: Image loaded and resized. Size: ${finalBytes.length} bytes');

      if (mounted) {
        setState(() {
          _imageBytes = finalBytes;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CropDialog: Load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载图片失败: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<Uint8List?> _processCircularCrop(Uint8List croppedData) async {
    try {
      // 使用 image 库进行二次处理，添加真正的圆形遮罩（透明背景）
      final cmd = img.Command()
        ..decodeImage(croppedData)
        ..copyCropCircle() // 裁剪为圆形
        ..encodePng();
      
      final result = await cmd.execute();
      return result.outputBytes;
    } catch (e) {
      debugPrint('CropDialog: Circular process error: $e');
      return croppedData; // 失败则返回原图
    }
  }

  void _safePop(Uint8List? result) {
    if (_hasPopped) return;
    _hasPopped = true;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.sakura),
                  SizedBox(height: 16),
                  Text('准备图片中...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Stack(
              children: [
                if (_imageBytes != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Crop(
                      image: _imageBytes!,
                      controller: _controller,
                      onCropped: (result) async {
                        if (result is CropSuccess) {
                          debugPrint('CropDialog: Cropped successfully, size: ${result.croppedImage.length}');
                          
                          // 处理为圆形透明背景
                          final circularImage = await _processCircularCrop(result.croppedImage);
                          _safePop(circularImage);
                        } else if (result is CropFailure) {
                          debugPrint('CropDialog: Crop failed');
                          setState(() => _isCropping = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('裁剪失败，请刷新图片重试')),
                            );
                          }
                        }
                      },
                      aspectRatio: 1 / 1,
                      withCircleUi: true,
                      baseColor: Colors.black,
                      maskColor: Colors.black.withOpacity(0.5),
                      interactive: true,
                    ),
                  ),
                
                // 顶部返回按钮
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => _safePop(null),
                    ),
                  ),
                ),

                // 标题
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      '移动和缩放',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 右下角确认按钮
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 30,
                  right: 30,
                  child: _isCropping 
                    ? const CircularProgressIndicator(color: AppColors.sakura)
                    : FloatingActionButton.extended(
                        onPressed: () {
                          if (_isCropping) return;
                          setState(() => _isCropping = true);
                          debugPrint('CropDialog: Start cropping...');
                          try {
                            _controller.crop();
                          } catch (e) {
                            debugPrint('CropDialog: Crop call error: $e');
                            setState(() => _isCropping = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('裁剪启动失败: $e')),
                            );
                          }
                        },
                        backgroundColor: AppColors.sakura,
                        label: const Text('完成', style: TextStyle(color: Colors.white)),
                        icon: const Icon(Icons.check, color: Colors.white),
                      ),
                ),
              ],
            ),
    );
  }
}
