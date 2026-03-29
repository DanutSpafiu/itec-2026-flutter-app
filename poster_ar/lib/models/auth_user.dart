class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? teamId;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.teamId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      teamId: json['teamId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'teamId': teamId,
    };
  }
}
