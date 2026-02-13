import 'dart:io' as io;
import 'dart:convert';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';

class WebDavAccount {
  final String id;
  final String url;
  final String user;
  final String password;
  final String label;

  WebDavAccount({
    required this.id,
    required this.url,
    required this.user,
    required this.password,
    String? label,
  }) : label = label ?? user;

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'user': user,
    'password': password,
    'label': label,
  };

  factory WebDavAccount.fromJson(Map<String, dynamic> json) => WebDavAccount(
    id: json['id'] as String,
    url: json['url'] as String,
    user: json['user'] as String,
    password: json['password'] as String,
    label: json['label'] as String?,
  );
}

class WebDavService {
  static final WebDavService _instance = WebDavService._internal();
  factory WebDavService() => _instance;
  WebDavService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _keyAccounts = 'webdav_accounts';
  static const String _keyActiveAccountId = 'webdav_active_account_id';
  static const String _keyAutoBackup = 'webdav_auto_backup';
  static const String _remoteFolder = 'PetLedger_Backup';
  // Legacy keys for migration
  static const String _keyUrl = 'webdav_url';
  static const String _keyUser = 'webdav_user';
  static const String _keyPass = 'webdav_password';

  List<WebDavAccount> _accounts = [];
  String? _activeAccountId;
  webdav.Client? _client;
  String? _deviceName;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  List<WebDavAccount> get accounts => List.unmodifiable(_accounts);
  WebDavAccount? get activeAccount => 
      _accounts.where((a) => a.id == _activeAccountId).firstOrNull;
  
  bool get isLoggedIn => _client != null;
  String? get currentUrl => activeAccount?.url;
  String? get currentUser => activeAccount?.user;

  // 默认账号配置 (在此处填入你的账号信息，新安装 App 时将自动登录)
  static const String _defaultUrl = 'https://dav.jianguoyun.com/dav/';
  static const String _defaultUser = 'pulei756@gmail.com';
  static const String _defaultPass = 'a7bx5hrp693jahbm';

  // 初始化（加载配置）
  Future<void> initialize() async {
    // Load accounts
    final jsonStr = await _storage.read(key: _keyAccounts);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _accounts = list.map((e) => WebDavAccount.fromJson(e)).toList();
      } catch (e) {
        // ignore error
      }
    }

    // Load active account ID
    _activeAccountId = await _storage.read(key: _keyActiveAccountId);

    // Migration logic & Default Account
    if (_accounts.isEmpty) {
      // 1. 尝试从旧版本迁移
      final oldUrl = await _storage.read(key: _keyUrl);
      final oldUser = await _storage.read(key: _keyUser);
      final oldPass = await _storage.read(key: _keyPass);

      if (oldUrl != null && oldUser != null && oldPass != null) {
        final newAccount = WebDavAccount(
          id: const Uuid().v4(),
          url: oldUrl,
          user: oldUser,
          password: oldPass,
          label: oldUser,
        );
        _accounts.add(newAccount);
        _activeAccountId = newAccount.id;
        await _saveAccounts();
        await _saveActiveAccountId();
        
        // Clean up legacy keys
        await _storage.delete(key: _keyUrl);
        await _storage.delete(key: _keyUser);
        await _storage.delete(key: _keyPass);
      } 
      // 2. 如果没有旧数据，使用代码内置的默认账号
      else if (_defaultUser.isNotEmpty && _defaultPass.isNotEmpty) {
         final newAccount = WebDavAccount(
          id: const Uuid().v4(),
          url: _defaultUrl,
          user: _defaultUser,
          password: _defaultPass,
          label: '默认账号',
        );
        _accounts.add(newAccount);
        _activeAccountId = newAccount.id;
        
        // 保存到本地，避免下次启动重复添加
        await _saveAccounts();
        await _saveActiveAccountId();
      }
    }

    // Initialize client if active account exists
    if (_activeAccountId != null && activeAccount != null) {
      _initClient(activeAccount!);
    }

    // Get device name
    await _initDeviceInfo();
  }

  Future<void> _initDeviceInfo() async {
    try {
      if (io.Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // 使用品牌+型号，如 "Xiaomi 2106118C"
        _deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (io.Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceName = iosInfo.utsname.machine;
      } else {
        _deviceName = io.Platform.operatingSystem;
      }
      _deviceName = _deviceName?.replaceAll(RegExp(r'[^\w\s\-]'), '_').replaceAll(' ', '_');
    } catch (e) {
      _deviceName = 'UnknownDevice';
    }
  }

  String get _deviceFolder => '$_remoteFolder/${_deviceName ?? "UnknownDevice"}';

  /// 生成备份文件名：pet_ledger_[日期].db
  String generateBackupFileName() {
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'pet_ledger_$dateStr.db';
  }

  Future<void> _saveAccounts() async {
    final jsonStr = jsonEncode(_accounts.map((e) => e.toJson()).toList());
    await _storage.write(key: _keyAccounts, value: jsonStr);
  }

  Future<void> _saveActiveAccountId() async {
    if (_activeAccountId != null) {
      await _storage.write(key: _keyActiveAccountId, value: _activeAccountId);
    } else {
      await _storage.delete(key: _keyActiveAccountId);
    }
  }

  Future<bool> isAutoBackupEnabled() async {
    final val = await _storage.read(key: _keyAutoBackup);
    return val == 'true';
  }

  Future<void> setAutoBackup(bool enabled) async {
    await _storage.write(key: _keyAutoBackup, value: enabled.toString());
  }

  // 添加新账号并设为活动账号 (Login)
  Future<void> login(String url, String user, String pass) async {
    // 简单的格式校验
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    if (!url.endsWith('/')) {
      url = '$url/';
    }

    // 测试连接
    final client = webdav.newClient(
      url,
      user: user,
      password: pass,
      debug: false,
    );

    try {
      // 尝试 ping
      await client.ping();
      
      // 连接成功，创建账号
      // 检查是否已存在 (简单去重: url + user)
      final existingIndex = _accounts.indexWhere((a) => a.url == url && a.user == user);
      
      final newAccount = WebDavAccount(
        id: existingIndex >= 0 ? _accounts[existingIndex].id : const Uuid().v4(),
        url: url,
        user: user,
        password: pass,
        label: user,
      );

      if (existingIndex >= 0) {
        _accounts[existingIndex] = newAccount; // 更新密码
      } else {
        _accounts.add(newAccount);
      }

      _activeAccountId = newAccount.id;
      _client = client;

      await _saveAccounts();
      await _saveActiveAccountId();
      
    } catch (e) {
      throw '连接失败: 请检查服务器地址和账号密码\n($e)';
    }
  }

  // 切换账号
  Future<void> switchAccount(String accountId) async {
    final account = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) throw '账号不存在';

    _initClient(account);
    // 验证连接
    try {
      await _client!.ping();
      _activeAccountId = accountId;
      await _saveActiveAccountId();
    } catch (e) {
      _client = null; // Reset if failed
      throw '切换失败，无法连接该账号: $e';
    }
  }

  // 删除账号
  Future<void> deleteAccount(String accountId) async {
    _accounts.removeWhere((a) => a.id == accountId);
    if (_activeAccountId == accountId) {
      _activeAccountId = null;
      _client = null;
      await _storage.delete(key: _keyActiveAccountId);
      
      // 如果还有其他账号，自动切到第一个? 或者保持未登录
      if (_accounts.isNotEmpty) {
         // Optional: Auto switch to next available?
         // await switchAccount(_accounts.first.id);
      }
    }
    await _saveAccounts();
  }

  // 退出当前账号 (不再作为活动账号，但不删除)
  Future<void> logout() async {
    _activeAccountId = null;
    _client = null;
    await _storage.delete(key: _keyActiveAccountId);
  }

  void _initClient(WebDavAccount account) {
    _client = webdav.newClient(
      account.url,
      user: account.user,
      password: account.password,
      debug: false,
    );
  }

  // 上传备份
  Future<void> uploadDatabase(io.File dbFile, {String? remoteName}) async {
    if (_client == null) await initialize();
    if (_client == null) throw '未登录 WebDAV';

    try {
      // 1. 检查并创建根目录
      try {
        await _client!.mkdir(_remoteFolder);
      } catch (e) { /* ignore */ }

      // 2. 检查并创建设备子目录
      try {
        await _client!.mkdir(_deviceFolder);
      } catch (e) { /* ignore */ }

      // 3. 上传文件
      final fileName = remoteName ?? generateBackupFileName();
      final remotePath = '$_deviceFolder/$fileName';
      
      await _client!.writeFromFile(dbFile.path, remotePath);
      
    } catch (e) {
      throw '上传失败: $e';
    }
  }

  // 获取所有备份列表
  Future<List<webdav.File>> getBackupList({bool currentDeviceOnly = true}) async {
    if (_client == null) await initialize();
    if (_client == null) throw '未登录 WebDAV';

    List<webdav.File> allFiles = [];
    try {
      // 1. 尝试从设备子目录读取
      try {
        final deviceFiles = await _client!.readDir(_deviceFolder);
        allFiles.addAll(deviceFiles.where((f) => f.name?.endsWith('.db') ?? false));
      } catch (e) {
        // 子目录可能还不存在
      }

      // 2. 如果不只限于当前设备，或者想兼容旧版本，也读取根目录
      if (!currentDeviceOnly) {
        try {
          final rootFiles = await _client!.readDir(_remoteFolder);
          // 旧文件通常包含 'pet_ledger'
          allFiles.addAll(rootFiles.where((f) {
            final name = f.name;
            return name != null && name.endsWith('.db') && name.contains('pet_ledger');
          }));
        } catch (e) { /* ignore */ }
      }

      // 去重 (以 path 或 name 为准)
      final Map<String, webdav.File> uniqueFiles = {};
      for (var f in allFiles) {
        final key = f.path ?? f.name;
        if (key != null) uniqueFiles[key] = f;
      }
      
      final dbFiles = uniqueFiles.values.toList();

      // 按时间倒序排列（最新的在前）
      dbFiles.sort((a, b) => (b.mTime ?? DateTime(0)).compareTo(a.mTime ?? DateTime(0)));
      return dbFiles;
    } catch (e) {
      print('WebDavService: Load backup list failed: $e');
      return [];
    }
  }

  // 下载备份
  Future<io.File?> downloadDatabase(String savePath, {String? remoteFilePath}) async {
    if (_client == null) await initialize();
    if (_client == null) throw '未登录 WebDAV';

    try {
      String? remotePath = remoteFilePath;

      // 如果未指定路径，则自动找最新的
      if (remotePath == null) {
        final files = await getBackupList(currentDeviceOnly: false);
        if (files.isEmpty) return null;
        
        final latest = files.first;
        // 优先使用显式 path，否则根据文件名特征猜测 (新版文件在子目录，旧版在根目录)
        if (latest.path != null) {
          remotePath = latest.path!;
        } else {
          // 兜底逻辑：如果包含设备标识（旧版风格）或就在根目录下，则从根目录查找；否则从设备目录查找
          final isOldFormat = latest.name?.contains('backup_') ?? false;
          remotePath = isOldFormat ? '$_remoteFolder/${latest.name}' : '$_deviceFolder/${latest.name}';
        }
      }

      // 2. 下载
      await _client!.read2File(remotePath, savePath);
      return io.File(savePath);

    } catch (e) {
      throw '下载失败: $e';
    }
  }
}

final webDavService = WebDavService();
