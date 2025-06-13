import 'package:flutter/material.dart';

class Reservation {
  final int id;
  final int userId;
  final int? courseId;
  final int? equipmentId;
  final int? facilityId;
  final String date;
  final String? startTime;
  final String? endTime;
  final String status;
  final String? createdAt;
  final int? equipmentQuantity;
  final String? pickupDate;
  final String? returnDate;
  
  // Informations liées aux relations
  final String? courseTitle;
  final String? equipmentName;
  final String? facilityName;
  final String? type;

  Reservation({
    required this.id,
    required this.userId,
    this.courseId,
    this.equipmentId,
    this.facilityId,
    required this.date,
    this.startTime,
    this.endTime,
    required this.status,
    this.createdAt,
    this.courseTitle,
    this.equipmentName,
    this.facilityName,
    this.type,
    this.equipmentQuantity,
    this.pickupDate,
    this.returnDate,
  });

  // Propriétés dérivées
  bool get isCourseReservation => courseId != null;
  bool get isEquipmentReservation => equipmentId != null;
  bool get isFacilityReservation => facilityId != null;
  bool get isPast {
    final today = DateTime.now();
    final reservationDate = DateTime.parse(date);
    return reservationDate.isBefore(today);
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    // Valider et convertir l'ID en int
    int id = 0;
    if (json['id'] != null) {
      id = json['id'] is int ? json['id'] : int.parse(json['id'].toString());
    }
    
    // Construire le type de réservation
    String? type;
    if (json['course_id'] != null) {
      type = 'Cours';
    } else if (json['equipment_id'] != null) {
      type = 'Équipement';
    } else if (json['facility_id'] != null) {
      type = 'Terrain';
    }
    
    // Extract date and times from start_time and end_time if needed
    String date = json['date'] ?? '';
    String? startTime = json['start_time'];
    String? endTime = json['end_time'];
    
    // If we don't have a date but have a start_time, extract date from it
    if (date.isEmpty && startTime != null) {
      DateTime? parsedStartTime;
      
      try {
        // Try to parse as ISO date time first
        parsedStartTime = DateTime.parse(startTime);
      } catch (e) {
        // If that fails, try to parse as MySQL datetime format
        try {
          if (startTime.contains(' ')) {
            // Convert MySQL datetime format 'YYYY-MM-DD HH:MM:SS' to ISO format
            startTime = startTime.replaceAll(' ', 'T');
            parsedStartTime = DateTime.parse(startTime);
          }
        } catch (e) {
          print('Error parsing start_time: $e');
        }
      }
      
      if (parsedStartTime != null) {
        // Extract date part only
        date = parsedStartTime.toIso8601String().split('T')[0];
        
        // Format time as HH:MM
        startTime = '${parsedStartTime.hour.toString().padLeft(2, '0')}:${parsedStartTime.minute.toString().padLeft(2, '0')}';
      }
    }
    
    // Similarly for end time if needed
    if (endTime != null) {
      DateTime? parsedEndTime;
      
      try {
        parsedEndTime = DateTime.parse(endTime);
      } catch (e) {
        try {
          if (endTime.contains(' ')) {
            endTime = endTime.replaceAll(' ', 'T');
            parsedEndTime = DateTime.parse(endTime);
          }
        } catch (e) {
          print('Error parsing end_time: $e');
        }
      }
      
      if (parsedEndTime != null) {
        endTime = '${parsedEndTime.hour.toString().padLeft(2, '0')}:${parsedEndTime.minute.toString().padLeft(2, '0')}';
      }
    }
    
    // Extract pickup_date and return_date if available
    String? pickupDate;
    String? returnDate;
    
    if (json['pickup_date'] != null) {
      DateTime? parsedPickupDate;
      
      try {
        parsedPickupDate = DateTime.parse(json['pickup_date']);
      } catch (e) {
        try {
          if (json['pickup_date'].contains(' ')) {
            String pickup = json['pickup_date'].replaceAll(' ', 'T');
            parsedPickupDate = DateTime.parse(pickup);
          }
        } catch (e) {
          print('Error parsing pickup_date: $e');
        }
      }
      
      if (parsedPickupDate != null) {
        pickupDate = parsedPickupDate.toIso8601String().split('T')[0];
      }
    }
    
    if (json['return_date'] != null) {
      DateTime? parsedReturnDate;
      
      try {
        parsedReturnDate = DateTime.parse(json['return_date']);
      } catch (e) {
        try {
          if (json['return_date'].contains(' ')) {
            String returnD = json['return_date'].replaceAll(' ', 'T');
            parsedReturnDate = DateTime.parse(returnD);
          }
        } catch (e) {
          print('Error parsing return_date: $e');
        }
      }
      
      if (parsedReturnDate != null) {
        returnDate = parsedReturnDate.toIso8601String().split('T')[0];
      }
    }
    
    // Assurer que user_id est bien un entier
    int userId = 0;
    if (json['user_id'] != null) {
      userId = json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString());
    }
    
    return Reservation(
      id: id,
      userId: userId,
      courseId: json['course_id'],
      equipmentId: json['equipment_id'],
      facilityId: json['facility_id'],
      date: date,
      startTime: startTime,
      endTime: endTime,
      status: json['status'] ?? 'Confirmée',
      createdAt: json['created_at'],
      courseTitle: json['course_title'],
      equipmentName: json['equipment_name'],
      facilityName: json['facility_name'],
      type: type,
      equipmentQuantity: json['equipment_quantity'],
      pickupDate: pickupDate,
      returnDate: returnDate,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'equipment_id': equipmentId,
      'facility_id': facilityId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'created_at': createdAt,
    };
    
    if (equipmentQuantity != null) {
      data['equipment_quantity'] = equipmentQuantity;
    }
    
    if (pickupDate != null) {
      data['pickup_date'] = pickupDate;
    }
    
    if (returnDate != null) {
      data['return_date'] = returnDate;
    }
    
    return data;
  }
  
  // Obtenir l'icône en fonction du type de réservation
  IconData getIcon() {
    if (isCourseReservation) {
      return Icons.fitness_center;
    } else if (isEquipmentReservation) {
      return Icons.sports_basketball;
    } else if (isFacilityReservation) {
      return Icons.stadium;
    } else {
      return Icons.calendar_today;
    }
  }
  
  // Obtenir la couleur en fonction du type de réservation
  Color getColor() {
    if (isCourseReservation) {
      return Colors.orange;
    } else if (isEquipmentReservation) {
      return Colors.blue;
    } else if (isFacilityReservation) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }
  
  // Obtenir le titre de la réservation
  String getTitle() {
    if (courseTitle != null) {
      return courseTitle!;
    } else if (equipmentName != null) {
      return equipmentName!;
    } else if (facilityName != null) {
      return facilityName!;
    } else {
      return 'Réservation #$id';
    }
  }

  // Obtenir la durée de la réservation
  String getDuration() {
    if (isEquipmentReservation && pickupDate != null && returnDate != null) {
      final pickupDateTime = DateTime.parse(pickupDate!);
      final returnDateTime = DateTime.parse(returnDate!);
      final difference = returnDateTime.difference(pickupDateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} jour(s)';
      } else {
        return '${difference.inHours} heure(s)';
      }
    } else if (startTime != null && endTime != null) {
      // Pour les réservations standard, calculer la durée basée sur start/end time
      final startParts = startTime!.split(':');
      final endParts = endTime!.split(':');
      
      if (startParts.length >= 2 && endParts.length >= 2) {
        final startHour = int.tryParse(startParts[0]) ?? 0;
        final startMinute = int.tryParse(startParts[1]) ?? 0;
        final endHour = int.tryParse(endParts[0]) ?? 0;
        final endMinute = int.tryParse(endParts[1]) ?? 0;
        
        final startMinutes = startHour * 60 + startMinute;
        final endMinutes = endHour * 60 + endMinute;
        final durationMinutes = endMinutes - startMinutes;
        
        if (durationMinutes <= 0) {
          return 'Durée inconnue';
        } else if (durationMinutes < 60) {
          return '$durationMinutes min';
        } else {
          final hours = durationMinutes ~/ 60;
          final minutes = durationMinutes % 60;
          return '$hours h${minutes > 0 ? ' $minutes min' : ''}';
        }
      }
    }
    
    return 'Durée inconnue';
  }
} 