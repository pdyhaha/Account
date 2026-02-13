import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/config/aliyun_config.dart';
import '../data/models/aliyun_token.dart';

/// 阿里云盘服务 (官方 OAuth 版)
class AliyunService {
  static final AliyunService _instance = AliyunService._internal();
  factory AliyunService() => _instance;
  AliyunService._internal();

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _tokenKey = 'aliyun_token';
  
  AliyunToken? _token;
  String? _driveId; // 默认网盘 ID

  /// 是否已登录
  bool get isLoggedIn => _token != null;

  /// 初始化：加载本地 Token
  Future<void> initialize() async {
    try {
      final jsonStr = await _storage.read(key: _tokenKey);
      if (jsonStr != null) {
        _token = AliyunToken.fromJson(jsonStr);
        // 如果过期，尝试刷新
        if (_token!.isExpired) {
          await _refreshToken();
        }
      }
    } catch (e) {
      print('Token 加载失败: $e');
    }
  }

  /// 第一步：打开授权页面
  Future<void> startAuth() async {
    final url = Uri.parse(
      '${AliyunConfig.authUrl}'
      '?client_id=${AliyunConfig.appId}'
      '&redirect_uri=${Uri.encodeComponent(AliyunConfig.redirectUri)}'
      '&response_type=code'
      '&scope=user:base,file:all:read,file:all:write',
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw '无法打开浏览器';
    }
  }

  /// 第二步：用 Code 换 Token
  Future<void> exchangeToken(String code) async {
    try {
      final response = await _dio.post(
        AliyunConfig.tokenUrl,
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': AliyunConfig.appId,
          'client_secret': AliyunConfig.appSecret,
          'redirect_uri': AliyunConfig.redirectUri,
        },
      );

      await _saveToken(response.data);
      await _getDriveId(); // 获取 Drive ID
    } catch (e) {
      throw 'Token 交换失败: $e';
    }
  }

  /// 刷新 Token
  Future<void> _refreshToken() async {
    if (_token == null) return;

    try {
      final response = await _dio.post(
        AliyunConfig.tokenUrl,
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': _token!.refreshToken,
          'client_id': AliyunConfig.appId,
          'client_secret': AliyunConfig.appSecret,
        },
      );

      await _saveToken(response.data);
    } catch (e) {
      print('Token 刷新失败: $e');
      // 如果刷新失败（如 refresh_token 过期），清除本地状态
      await logout();
    }
  }

  /// 保存 Token
  Future<void> _saveToken(Map<String, dynamic> data) async {
    _token = AliyunToken.fromMap(data);
    await _storage.write(key: _tokenKey, value: _token!.toJson());
  }

  /// 退出登录
  Future<void> logout() async {
    _token = null;
    _driveId = null;
    await _storage.delete(key: _tokenKey);
  }

  /// 获取默认 Drive ID (备份文件)
  Future<void> _getDriveId() async {
    if (_driveId != null) return;
    
    try {
      final response = await _dio.post(
        '${AliyunConfig.fileApiUrl}/user/get_drive_info',
        options: _authOptions(),
      );
      // 通常使用 default_drive_id
      _driveId = response.data['default_drive_id'];
    } catch (e) {
      print('获取 Drive ID 失败: $e');
    }
  }

  /// 查找或创建备份文件夹
  Future<String> _getBackupFolderId() async {
    await _getDriveId();
    if (_driveId == null) throw '未获取到网盘信息';

    // 1. 查找文件夹
    try {
      final searchRes = await _dio.post(
        '${AliyunConfig.fileApiUrl}/file/search',
        options: _authOptions(),
        data: {
          'drive_id': _driveId,
          'query': 'name = "${AliyunConfig.backupFolderName}" and type = "folder"',
        },
      );

      final items = searchRes.data['items'] as List;
      if (items.isNotEmpty) {
        return items.first['file_id'];
      }

      // 2. 如果不存在，创建文件夹
      final createRes = await _dio.post(
        '${AliyunConfig.fileApiUrl}/file/create_with_proof',
        options: _authOptions(),
        data: {
          'drive_id': _driveId,
          'parent_file_id': 'root',
          'name': AliyunConfig.backupFolderName,
          'type': 'folder',
          'check_name_mode': 'refuse',
        },
      );
      
      return createRes.data['file_id'];
    } catch (e) {
      throw '备份文件夹操作失败: $e';
    }
  }

  /// 上传数据库文件 (简单覆盖)
  Future<void> uploadDatabase(File dbFile) async {
    if (_token == null) throw '未登录';
    if (_token!.isExpired) await _refreshToken();

    try {
      final folderId = await _getBackupFolderId();
      final fileName = p.basename(dbFile.path);

      // 正规流程：create_with_proof -> 获取 upload_url -> PUT 上传
      final createRes = await _dio.post(
        '${AliyunConfig.fileApiUrl}/file/create_with_proof',
        options: _authOptions(),
        data: {
          'drive_id': _driveId,
          'parent_file_id': folderId,
          'name': fileName,
          'type': 'file',
          'check_name_mode': 'auto_rename', // 自动重命名，避免冲突
        },
      );

      // 如果 rapid_upload 为 true，说明秒传成功
      if (createRes.data['rapid_upload'] == true) {
        print('秒传成功');
        return;
      }

      final uploadUrl = createRes.data['part_info_list'][0]['upload_url'];
      
      // PUT 上传文件内容
      await _dio.put(
        uploadUrl,
        data: dbFile.openRead(),
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
          },
        ),
      );

      // 完成上传通知
      await _dio.post(
        '${AliyunConfig.fileApiUrl}/file/complete',
        options: _authOptions(),
        data: {
          'drive_id': _driveId,
          'file_id': createRes.data['file_id'],
          'upload_id': createRes.data['upload_id'],
        },
      );
      
    } catch (e) {
      throw '上传失败: $e';
    }
  }

  /// 下载数据库文件
  Future<File?> downloadDatabase(String savePath) async {
    if (_token == null) throw '未登录';
    if (_token!.isExpired) await _refreshToken();

    try {
      final folderId = await _getBackupFolderId();
      
      // 查找最新的 db 文件
      final searchRes = await _dio.post(
        '${AliyunConfig.fileApiUrl}/file/search',
        options: _authOptions(),
        data: {
          'drive_id': _driveId,
          'parent_file_id': folderId,
          'query': 'name match "pet_ledger" and type = "file"',
          'order_by': 'updated_at DESC',
          'limit': 1,
        },
      );

      final items = searchRes.data['items'] as List;
      if (items.isEmpty) return null;

      final fileId = items.first['file_id'];
      
      // 获取下载地址
      final downloadRes = await _dio.post(
        '${AliyunConfig.fileApiUrl}/file/get_download_url',
        options: _authOptions(),
        data: {
          'drive_id': _driveId,
          'file_id': fileId,
        },
      );
      
      final downloadUrl = downloadRes.data['url'];
      
      // 下载文件
      await _dio.download(downloadUrl, savePath);
      return File(savePath);
      
    } catch (e) {
      throw '下载失败: $e';
    }
  }

  Options _authOptions() {
    return Options(
      headers: {
        'Authorization': 'Bearer ${_token?.accessToken}',
      },
    );
  }
}

/// 全局实例
final aliyunService = AliyunService();
