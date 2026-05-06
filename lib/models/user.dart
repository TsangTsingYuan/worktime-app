class User {
  final int? id;
  final String nickname;
  final String phone;
  final String password;
  final String config;
  final String? serverId;
  final String token;

  User({
    this.id,
    this.nickname = '',
    this.phone = '',
    this.password = '',
    this.config = '',
    this.serverId,
    this.token = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nickname': nickname,
        'phone': phone,
        'password': password,
        'config': config,
        'serverId': serverId,
        'token': token,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'],
        nickname: map['nickname'] ?? '',
        phone: map['phone'] ?? '',
        password: map['password'] ?? '',
        config: map['config'] ?? '',
        serverId: map['serverId'],
        token: map['token'] ?? '',
      );

  User copyWith({
    int? id,
    String? nickname,
    String? phone,
    String? password,
    String? config,
    String? serverId,
    String? token,
  }) =>
      User(
        id: id ?? this.id,
        nickname: nickname ?? this.nickname,
        phone: phone ?? this.phone,
        password: password ?? this.password,
        config: config ?? this.config,
        serverId: serverId ?? this.serverId,
        token: token ?? this.token,
      );
}
