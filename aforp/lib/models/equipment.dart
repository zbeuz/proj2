class Equipment {
  final int? id;
  final String name;
  final String description;
  final String? imageUrl;
  final int totalQuantity;
  final int availableQuantity;
  final String? category;
  final String condition;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Equipment({
    this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.totalQuantity,
    required this.availableQuantity,
    this.category,
    required this.condition,
    bool? isAvailable,
    this.createdAt,
    this.updatedAt,
  }) : isAvailable = isAvailable ?? (availableQuantity > 0);

  factory Equipment.fromJson(Map<String, dynamic> json) {
    final availableQty = json['available_quantity'] is String 
        ? int.tryParse(json['available_quantity']) ?? 0 
        : json['available_quantity'] ?? 0;
        
    return Equipment(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      totalQuantity: json['total_quantity'] is String 
          ? int.tryParse(json['total_quantity']) ?? 0 
          : json['total_quantity'] ?? 0,
      availableQuantity: availableQty,
      category: json['category'],
      condition: json['condition'] ?? 'Bon',
      isAvailable: json['is_available'] != null ? 
          (json['is_available'] == 1 || json['is_available'] == true) : 
          (availableQty > 0),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'total_quantity': totalQuantity,
      'available_quantity': availableQuantity,
      'category': category,
      'condition': condition,
      'is_available': isAvailable ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Equipment copyWith({
    int? id,
    String? name,
    String? description,
    String? imageUrl,
    int? totalQuantity,
    int? availableQuantity,
    String? category,
    String? condition,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newAvailableQuantity = availableQuantity ?? this.availableQuantity;
    
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      availableQuantity: newAvailableQuantity,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      isAvailable: isAvailable ?? (newAvailableQuantity > 0),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 