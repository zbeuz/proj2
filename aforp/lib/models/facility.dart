import 'package:flutter/material.dart';

class Facility {
  final int? id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? openingHours;
  final String? closingHours;
  final bool isAvailable;
  final bool? isTerrain;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Facility({
    this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.openingHours,
    this.closingHours,
    this.isAvailable = true,
    this.isTerrain = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      openingHours: json['opening_hours'] ?? '',
      closingHours: json['closing_hours'] ?? '',
      isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      isTerrain: json['is_terrain'] == 1 || json['is_terrain'] == true,
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
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'opening_hours': openingHours,
      'closing_hours': closingHours,
      'is_available': isAvailable ? 1 : 0,
      'is_terrain': isTerrain == true ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Facility copyWith({
    int? id,
    String? name,
    String? description,
    String? imageUrl,
    String? openingHours,
    String? closingHours,
    bool? isAvailable,
    bool? isTerrain,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Facility(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      openingHours: openingHours ?? this.openingHours,
      closingHours: closingHours ?? this.closingHours,
      isAvailable: isAvailable ?? this.isAvailable,
      isTerrain: isTerrain ?? this.isTerrain,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 