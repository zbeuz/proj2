class Course {
  final int? id;
  final String name;
  final String description;
  final int duration;
  final int maxCapacity;
  final int availableSpots;
  final double? price;
  final int? facilityId;
  final String? facilityName;
  final bool isTerrain;
  final String? imageUrl;
  final DateTime? date;
  final String? time;
  final List<CourseSchedule>? schedules;
  final List<CourseEquipment>? equipment;

  Course({
    this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.maxCapacity,
    required this.availableSpots,
    this.price,
    this.facilityId,
    this.facilityName,
    this.isTerrain = false,
    this.imageUrl,
    this.date,
    this.time,
    this.schedules,
    this.equipment,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'] is String 
          ? int.tryParse(json['duration']) ?? 0 
          : json['duration'] ?? 0,
      maxCapacity: json['max_capacity'] is String
          ? int.tryParse(json['max_capacity']) ?? 0
          : json['max_capacity'] ?? 0,
      availableSpots: json['available_spots'] is String
          ? int.tryParse(json['available_spots']) ?? 0
          : json['available_spots'] ?? 0,
      price: json['price'] is String
          ? double.tryParse(json['price']) ?? 0.0
          : json['price']?.toDouble() ?? 0.0,
      facilityId: json['facility_id'],
      facilityName: json['facility_name'],
      isTerrain: json['is_terrain'] == 1 || json['is_terrain'] == true,
      imageUrl: json['image_url'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      time: json['time'],
      schedules: json['schedules'] != null
          ? (json['schedules'] as List).map((s) => CourseSchedule.fromJson(s)).toList()
          : null,
      equipment: json['equipment'] != null
          ? (json['equipment'] as List).map((e) => CourseEquipment.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'duration': duration,
      'max_capacity': maxCapacity,
      'available_spots': availableSpots,
      'price': price,
      'facility_id': facilityId,
      'is_terrain': isTerrain,
      'image_url': imageUrl,
      'date': date?.toIso8601String().split('T')[0],
      'time': time,
      'schedules': schedules?.map((s) => s.toJson()).toList(),
      'equipment': equipment?.map((e) => e.toJson()).toList(),
    };
  }
}

class CourseSchedule {
  final int? id;
  final int? courseId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  CourseSchedule({
    this.id,
    this.courseId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory CourseSchedule.fromJson(Map<String, dynamic> json) {
    return CourseSchedule(
      id: json['id'],
      courseId: json['course_id'],
      dayOfWeek: json['day_of_week'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}

class CourseEquipment {
  final int? id;
  final int? courseId;
  final int equipmentId;
  final String? equipmentName;
  final String? equipmentDescription;
  final int quantity;

  CourseEquipment({
    this.id,
    this.courseId,
    required this.equipmentId,
    this.equipmentName,
    this.equipmentDescription,
    this.quantity = 1,
  });

  factory CourseEquipment.fromJson(Map<String, dynamic> json) {
    return CourseEquipment(
      id: json['id'],
      courseId: json['course_id'],
      equipmentId: json['equipment_id'],
      equipmentName: json['equipment_name'],
      equipmentDescription: json['equipment_description'],
      quantity: json['quantity'] is String
          ? int.tryParse(json['quantity']) ?? 1
          : json['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      'equipment_id': equipmentId,
      'quantity': quantity,
    };
  }
} 