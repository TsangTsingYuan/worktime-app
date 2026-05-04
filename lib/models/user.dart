class User {
  final int? id;
  final String nickname;
  final String phone;
  final String password;
  final String config;

  User({
    this.id,
    this.nickname = '',
    this.phone = '',
    this.password = '',
    this.config = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nickname': nickname,
        'phone': phone,
        'password': password,
        'config': config,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'],
        nickname: map['nickname'] ?? '',
        phone: map['phone'] ?? '',
        password: map['password'] ?? '',
        config: map['config'] ?? '',
      );

  User copyWith({
    int? id,
    String? nickname,
    String? phone,
    String? password,
    String? config,
  }) =>
      User(
        id: id ?? this.id,
        nickname: nickname ?? this.nickname,
        phone: phone ?? this.phone,
        password: password ?? this.password,
        config: config ?? this.config,
      );
}
