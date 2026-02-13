/// 阿里云盘配置
class AliyunConfig {
  AliyunConfig._();

  // TODO: 替换为你申请的 App ID 和 Secret
  static const String appId = 'YOUR_APP_ID';
  static const String appSecret = 'YOUR_APP_SECRET';
  
  // 授权回调地址 (需要在阿里云控制台配置)
  // 通常移动端可以使用 http://localhost:8080/callback 或者自定义 Scheme
  static const String redirectUri = 'petledger://oauth/callback';
  
  // API 端点
  static const String authUrl = 'https://auth.aliyundrive.com/v2/oauth/authorize';
  static const String tokenUrl = 'https://auth.aliyundrive.com/v2/oauth/token';
  static const String driveApiUrl = 'https://api.aliyundrive.com/v2';
  static const String fileApiUrl = 'https://api.aliyundrive.com/adrive/v1.0';
  
  // 备份文件夹名称
  static const String backupFolderName = 'PetLedger_Backup';
}
