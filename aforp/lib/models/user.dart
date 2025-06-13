class User {
  final int? id;
  final String username;
  final String email;
  final String? token;
  final String? name;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    required this.username,
    required this.email,
    this.token,
    this.name,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Imprimer tout le JSON pour debug
    print("JSON COMPLET REÇU: $json");
    
    // Rechercher toutes les clés qui pourraient être liées au rôle
    final roleKey = json.keys.firstWhere(
      (key) => key.toLowerCase().contains('role') || key.toLowerCase().contains('admin'),
      orElse: () => 'role',
    );
    
    // Récupérer la valeur du rôle avec plusieurs tentatives
    String roleValue = 'user';
    if (json.containsKey('role')) {
      roleValue = json['role'] ?? 'user';
    } else if (json.containsKey('user_role')) {
      roleValue = json['user_role'] ?? 'user';
    } else if (json.containsKey('userRole')) {
      roleValue = json['userRole'] ?? 'user';
    } else if (json.containsKey('Role')) {
      roleValue = json['Role'] ?? 'user';
    } else if (json.containsKey(roleKey)) {
      roleValue = json[roleKey] ?? 'user';
    }
    
    print("ROLE DÉTECTÉ: $roleValue (clé utilisée: ${json.containsKey(roleKey) ? roleKey : 'aucune clé trouvée'})");
    
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      token: json['token'],
      name: json['name'],
      role: roleValue,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'token': token,
      'name': name,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
} 