import 'dart:convert';

/// 阿里云盘 Token 模型
class AliyunToken {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime obtainedAt;

  AliyunToken({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.obtainedAt,
  });

  /// 是否过期 (提前5分钟认为过期)
  bool get isExpired {
    return DateTime.now().isAfter(
      obtainedAt.add(Duration(seconds: expiresIn - 300)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'obtained_at': obtainedAt.toIso8601String(),
    };
  }

  factory AliyunToken.fromMap(Map<String, dynamic> map) {
    return AliyunToken(
      accessToken: map['access_token'] ?? '',
      refreshToken: map['refresh_token'] ?? '',
      tokenType: map['token_type'] ?? 'Bearer',
      expiresIn: map['expires_in']?.toInt() ?? 7200,
      obtainedAt: map['obtained_at'] != null 
          ? DateTime.parse(map['obtained_at']) 
          : DateTime.now(),
    );
  }

  factory AliyunToken.fromJson(String source) => 
      AliyunToken.fromMap(json.decode(source));
      
  String toJson() => json.encode(toMap());
}
