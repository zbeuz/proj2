import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/course.dart';
import '../../models/facility.dart';
import '../../models/equipment.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import '../base_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({Key? key}) : super(key: key);

  @override
  _AdminCoursesScreenState createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final ApiService _apiService = ApiService();
  List<Course> _courses = [];
  List<Facility> _facilities = [];
  List<Facility> _terrains = [];
  List<Equipment> _availableEquipment = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _maxCapacityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  int? _selectedFacilityId;
  int _selectedDuration = 60; // Valeur par défaut
  List<CourseEquipment> _selectedEquipment = [];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  // Liste des lignes d'équipement à afficher
  List<Widget> _equipmentSelectionRows = [];
  
  // Variables pour la sélection d'équipement
  int? _selectedEquipmentId;
  int _selectedQuantity = 1;
  int _maxQuantity = 1;
  final TextEditingController _quantityController = TextEditingController();

  // Durées prédéfinies en minutes
  final List<int> _durations = [15, 30, 45, 60, 75, 90, 120, 150, 180];
  
  // Liste des heures disponibles
  final List<String> _availableHours = [
    '08:00:00', '08:30:00', '09:00:00', '09:30:00', '10:00:00', '10:30:00', 
    '11:00:00', '11:30:00', '12:00:00', '12:30:00', '13:00:00', '13:30:00', 
    '14:00:00', '14:30:00', '15:00:00', '15:30:00', '16:00:00', '16:30:00',
    '17:00:00', '17:30:00', '18:00:00', '18:30:00', '19:00:00', '19:30:00',
    '20:00:00', '20:30:00', '21:00:00'
  ];

  // Image picker
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadFacilities();
    _loadAvailableTerrains();
    _loadAvailableEquipment();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxCapacityController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final courses = await _apiService.getAllCourses();
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des cours: $e';
      });
    }
  }

  Future<void> _loadFacilities() async {
    try {
      final facilities = await _apiService.getAllFacilities();
      setState(() {
        _facilities = facilities;
      });
    } catch (e) {
      print('Erreur lors du chargement des installations: $e');
    }
  }
  
  Future<void> _loadAvailableTerrains() async {
    try {
      print("Chargement des terrains disponibles...");
      final terrains = await _apiService.getAvailableTerrainsForCourses();
      setState(() {
        _terrains = terrains;
      });
      print("Terrains chargés: ${terrains.length}");
    } catch (e) {
      print('Erreur lors du chargement des terrains: $e');
    }
  }
  
  Future<void> _loadAvailableEquipment() async {
    try {
      print("Chargement des équipements disponibles...");
      final equipment = await _apiService.getAvailableEquipmentForCourses();
      setState(() {
        _availableEquipment = equipment;
      });
      print("Équipements chargés: ${equipment.length}");
    } catch (e) {
      print('Erreur lors du chargement des équipements: $e');
    }
  }

  Future<void> _createCourse() async {
    if (_nameController.text.isEmpty || 
        _descriptionController.text.isEmpty || 
        _maxCapacityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
      );
      return;
    }

    // Check if selected facility is a terrain
    bool isTerrain = false;
    if (_selectedFacilityId != null) {
      final terrain = _terrains.firstWhere(
        (t) => t.id == _selectedFacilityId,
        orElse: () => Facility(id: 0, name: '', description: '', isTerrain: false),
      );
      isTerrain = terrain.isTerrain == true;
    }

    // Formater les données d'équipements pour debug
    final equipmentList = _selectedEquipment.map((e) => {
      'equipment_id': e.equipmentId,
      'quantity': e.quantity,
    }).toList();
    
    // Debug - Afficher les équipements
    print('Équipements sélectionnés: ${_selectedEquipment.length}');
    print('Équipements envoyés: $equipmentList');

    final newCourse = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'duration': _selectedDuration,
      'max_capacity': int.tryParse(_maxCapacityController.text) ?? 0,
      'available_spots': int.tryParse(_maxCapacityController.text) ?? 0,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'facility_id': _selectedFacilityId, // Peut être null, c'est OK
      'image_url': _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
      'date': _dateController.text.isEmpty ? null : _dateController.text,
      'time': _timeController.text.isEmpty ? null : _timeController.text,
    };
    
    // Ajouter l'équipement uniquement s'il y en a
    if (_selectedEquipment.isNotEmpty) {
      newCourse['equipment'] = equipmentList;
    }
    
    // Debug - Afficher le cours complet
    print('Cours complet à créer: $newCourse');

    try {
      // Créer le cours
      final Course createdCourse = await _apiService.createCourse(newCourse);
      
      // Si un terrain est sélectionné, s'assurer qu'il est marqué comme indisponible
      if (_selectedFacilityId != null && isTerrain && 
          _dateController.text.isNotEmpty && _timeController.text.isNotEmpty) {
        try {
          // Récupérer l'utilisateur courant
          final currentUser = await _apiService.getCurrentUser();
          if (currentUser == null) {
            throw Exception("Utilisateur non authentifié");
          }

          // Construire la date et l'heure en format ISO
          final dateStr = _dateController.text;
          final timeStr = _timeController.text;
          
          // Construire des DateTime complets pour start et end time
          final DateTime startDate = DateTime.parse('${dateStr}T$timeStr');
          final DateTime endDate = startDate.add(Duration(minutes: _selectedDuration));
          
          // Formater pour l'API
          final String startTimeIso = startDate.toIso8601String();
          final String endTimeIso = endDate.toIso8601String();
          
          print('Création de réservation pour terrain:');
          print('Terrain ID: $_selectedFacilityId');
          print('Cours ID: ${createdCourse.id}');
          print('Date: $dateStr');
          print('Heure début: $timeStr');
          print('Heure fin: ${_calculateEndTime(timeStr, _selectedDuration)}');
          print('User ID: ${currentUser.id}');
          
          // Créer la réservation directement avec les bonnes dates au format ISO
          await _apiService.createReservationWithDateTime({
            'user_id': currentUser.id,
            'facility_id': _selectedFacilityId,
            'course_id': createdCourse.id,
            'start_time': startTimeIso,
            'end_time': endTimeIso,
            'status': 'Confirmée'
          });
          
          // Mettre à jour localement la liste des terrains disponibles
          await _loadAvailableTerrains();
          
          print('Terrain réservé et marqué comme indisponible');
        } catch (e) {
          print('Erreur lors de la réservation du terrain: $e');
          // Ne pas bloquer le flux si la réservation échoue
        }
      }
      
      _clearForm();
      _loadCourses();
      // Ne pas fermer le dialogue ici, c'est géré par le bouton
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cours créé avec succès')),
      );
    } catch (e) {
      print('Erreur détaillée lors de la création du cours: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création: $e')),
      );
      // Ne pas masquer l'exception pour qu'elle puisse être gérée par le bouton
      throw e;
    }
  }

  Future<void> _updateCourse(Course course) async {
    try {
      // Préparer les données de base du cours
      final Map<String, dynamic> updatedCourse = {
        'id': course.id,
        'name': course.name,
        'description': course.description,
        'duration': course.duration,
        'max_capacity': course.maxCapacity,
        'available_spots': course.availableSpots,
        'price': course.price,
        'facility_id': course.facilityId, // Peut être null
        'image_url': course.imageUrl,
        'date': course.date?.toIso8601String().split('T')[0],
        'time': course.time,
      };
      
      // Ajouter l'équipement uniquement s'il y en a
      final List<CourseEquipment> equipment = course.equipment?.toList() ?? [];
      if (equipment.isNotEmpty) {
        updatedCourse['equipment'] = equipment.map((e) => {
          'equipment_id': e.equipmentId,
          'quantity': e.quantity,
        }).toList();
      }
      
      // Debug - Afficher les détails de la mise à jour
      print('Mise à jour du cours: ${course.id} avec ${equipment.length} équipements');
      print('Données de mise à jour: $updatedCourse');
      
      await _apiService.updateCourse(updatedCourse);
      _loadCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cours mis à jour avec succès')),
      );
    } catch (e) {
      print('Erreur détaillée lors de la mise à jour: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  Future<void> _deleteCourse(int? courseId) async {
    if (courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: ID du cours manquant')),
      );
      return;
    }
    
    try {
      // Récupérer les informations du cours avant de le supprimer
      Course? courseToDelete;
      for (final course in _courses) {
        if (course.id == courseId) {
          courseToDelete = course;
          break;
        }
      }
      
      await _apiService.deleteCourse(courseId);
      
      // Si le cours supprimé utilisait un terrain, recharger la liste des terrains
      if (courseToDelete != null && courseToDelete.facilityId != null && courseToDelete.isTerrain) {
        // Mettre à jour la liste locale des terrains disponibles
        _loadAvailableTerrains();
      }
      
      _loadCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cours supprimé avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _maxCapacityController.clear();
    _priceController.clear();
    _imageUrlController.clear();
    _dateController.clear();
    _timeController.clear();
    _quantityController.clear();
    _selectedFacilityId = null;
    _selectedDuration = 60;
    _selectedEquipment = [];
    _selectedDate = null;
    _selectedTime = null;
    _selectedEquipmentId = null;
    _selectedImage = null;
  }

  void _showAddCourseDialog() {
    _clearForm();
    setState(() {
      _selectedEquipment = [];
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: BoxConstraints(
                  maxWidth: 800,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  minWidth: 300,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En-tête du formulaire
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3C64F4),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sports, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: const Text(
                              'Ajouter un cours',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                        ],
                      ),
                    ),
                    
                    // Corps du formulaire
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informations générales',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C64F4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Nom du cours',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.title, color: Color(0xFF3C64F4)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                alignLabelWithHint: true,
                                prefixIcon: const Icon(Icons.description, color: Color(0xFF3C64F4)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            const Text(
                              'Capacité et prix',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C64F4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _maxCapacityController,
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Capacité max',
                                      labelStyle: TextStyle(color: Colors.grey.shade400),
                                      prefixIcon: const Icon(Icons.people, color: Color(0xFF3C64F4)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade700),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade700),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _priceController,
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Prix (€)',
                                      labelStyle: TextStyle(color: Colors.grey.shade400),
                                      prefixIcon: const Icon(Icons.euro, color: Color(0xFF3C64F4)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade700),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade700),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            const Text(
                              'Date et heure',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C64F4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context),
                                    child: AbsorbPointer(
                                      child: TextField(
                                        controller: _dateController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: 'Date',
                                          labelStyle: TextStyle(color: Colors.grey.shade400),
                                          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF3C64F4)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide(color: Colors.grey.shade700),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide(color: Colors.grey.shade700),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    dropdownColor: Colors.grey.shade800,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Heure',
                                      labelStyle: TextStyle(color: Colors.grey.shade400),
                                      prefixIcon: const Icon(Icons.access_time, color: Color(0xFF3C64F4)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade700),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade700),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade800,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                    value: _timeController.text.isNotEmpty ? _timeController.text : _availableHours[0],
                                    items: _availableHours.map((String time) {
                                      // Afficher sous format plus court (ex: "08:00" au lieu de "08:00:00")
                                      String displayTime = time.substring(0, 5);
                                      return DropdownMenuItem<String>(
                                        value: time,
                                        child: Text(displayTime),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        _timeController.text = newValue;
                                        _selectTimeFromList(newValue);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              dropdownColor: Colors.grey.shade800,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Durée (minutes)',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.timelapse, color: Color(0xFF3C64F4)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              value: _selectedDuration,
                              items: _durations.map((int duration) {
                                return DropdownMenuItem<int>(
                                  value: duration,
                                  child: Text('$duration minutes'),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  setDialogState(() {
                                    _selectedDuration = newValue;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 24),
                            const Text(
                              'Terrain et image',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C64F4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int?>(
                              isExpanded: true,
                              dropdownColor: Colors.grey.shade800,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Terrain',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.place, color: Color(0xFF3C64F4)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              value: _selectedFacilityId,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Aucun terrain'),
                                ),
                                ..._terrains.map((Facility terrain) {
                                  return DropdownMenuItem<int?>(
                                    value: terrain.id,
                                    child: Text(terrain.name),
                                  );
                                }).toList(),
                              ],
                              onChanged: (int? newValue) {
                                setDialogState(() {
                                  _selectedFacilityId = newValue;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Image',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3C64F4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                
                                if (_selectedImage != null || _imageUrlController.text.isNotEmpty)
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade700),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: _isUploading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _selectedImage != null || _imageUrlController.text.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              _imageUrlController.text.isNotEmpty 
                                                ? _imageUrlController.text
                                                : "https://via.placeholder.com/400x300?text=Image+sélectionnée",
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / 
                                                            (loadingProgress.expectedTotalBytes ?? 1)
                                                        : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Icon(Icons.broken_image, size: 50),
                                                );
                                              },
                                            ),
                                          )
                                        : const Center(
                                            child: Icon(Icons.image, size: 50, color: Colors.grey),
                                          ),
                                  )
                                else
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade700),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.grey.shade800,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                                    ),
                                  ),
                                
                                const SizedBox(height: 10),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Choisir une image'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF3C64F4),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _imageUrlController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'URL de l\'image (optionnel)',
                                    labelStyle: TextStyle(color: Colors.grey.shade400),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            const Text(
                              'Équipements',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C64F4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Section Équipements refaite
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Lignes d'équipements existantes
                                if (_selectedEquipment.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Aucun équipement sélectionné',
                                      style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                  
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _selectedEquipment.length,
                                  itemBuilder: (context, index) {
                                    final equipment = _selectedEquipment[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8.0),
                                      color: Colors.grey.shade800,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: [
                                            // Nom de l'équipement
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                equipment.equipmentName ?? "Équipement #${equipment.equipmentId}",
                                                style: const TextStyle(color: Colors.white),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            
                                            // Quantité
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                "Qté: ${equipment.quantity}",
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            
                                            // Bouton pour supprimer
                                            SizedBox(
                                              width: 40,
                                              child: IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    _selectedEquipment.removeAt(index);
                                                  });
                                                },
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Formulaire pour ajouter un équipement
                                Card(
                                  color: Colors.grey.shade900,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey.shade700),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Ajouter un équipement',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Sélection d'équipement
                                        DropdownButtonFormField<int?>(
                                          isExpanded: true,
                                          dropdownColor: Colors.grey.shade800,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText: 'Équipement',
                                            labelStyle: TextStyle(color: Colors.grey.shade400),
                                            prefixIcon: const Icon(Icons.fitness_center, color: Color(0xFF3C64F4)),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.grey.shade700),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.grey.shade700),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade800,
                                          ),
                                          hint: Text('Sélectionner', style: TextStyle(color: Colors.grey.shade400)),
                                          value: _selectedEquipmentId,
                                          items: _availableEquipment.map((Equipment e) {
                                            return DropdownMenuItem<int?>(
                                              value: e.id,
                                              child: Text(
                                                '${e.name} (${e.availableQuantity})',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setDialogState(() {
                                              _selectedEquipmentId = value;
                                            });
                                          },
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Saisie de quantité
                                        TextField(
                                          controller: _quantityController,
                                          style: const TextStyle(color: Colors.white),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Quantité',
                                            labelStyle: TextStyle(color: Colors.grey.shade400),
                                            prefixIcon: const Icon(Icons.numbers, color: Color(0xFF3C64F4)),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.grey.shade700),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.grey.shade700),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade800,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Bouton pour ajouter
                                        Center(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.add),
                                            label: const Text('Ajouter'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF3C64F4),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () {
                                              if (_selectedEquipmentId != null) {
                                                final equipment = _availableEquipment.firstWhere(
                                                  (e) => e.id == _selectedEquipmentId,
                                                  orElse: () => Equipment(
                                                    id: _selectedEquipmentId!,
                                                    name: 'Équipement #$_selectedEquipmentId',
                                                    description: '',
                                                    totalQuantity: 0,
                                                    availableQuantity: 0,
                                                    condition: 'Bon',
                                                    isAvailable: true,
                                                  ),
                                                );
                                                
                                                int quantity = int.tryParse(_quantityController.text) ?? 1;
                                                if (quantity <= 0) quantity = 1;
                                                
                                                final courseEquipment = CourseEquipment(
                                                  equipmentId: equipment.id!,
                                                  quantity: quantity,
                                                  equipmentName: equipment.name,
                                                  equipmentDescription: equipment.description,
                                                );
                                                
                                                setDialogState(() {
                                                  // Vérifier si cet équipement existe déjà
                                                  final existingIndex = _selectedEquipment.indexWhere(
                                                    (e) => e.equipmentId == equipment.id
                                                  );
                                                  
                                                  if (existingIndex >= 0) {
                                                    // Remplacer l'équipement existant
                                                    _selectedEquipment[existingIndex] = courseEquipment;
                                                  } else {
                                                    // Ajouter un nouvel équipement
                                                    _selectedEquipment.add(courseEquipment);
                                                  }
                                                  
                                                  // Réinitialiser
                                                  _selectedEquipmentId = null;
                                                  _quantityController.clear();
                                                });
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Veuillez sélectionner un équipement')),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Boutons d'action
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade700),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (_nameController.text.isEmpty ||
                                  _descriptionController.text.isEmpty ||
                                  _maxCapacityController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
                                );
                                return;
                              }
                              
                              try {
                                // Afficher un indicateur de chargement
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return const Dialog(
                                      child: Padding(
                                        padding: EdgeInsets.all(20.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(width: 20),
                                            Text("Création du cours en cours..."),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                                
                                // Créer le cours
                                await _createCourse();
                                
                                // Fermer l'indicateur de chargement et le dialogue principal
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              } catch (e) {
                                // En cas d'erreur, fermer l'indicateur de chargement
                                Navigator.of(context).pop();
                                
                                // Afficher un message d'erreur
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF3C64F4),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Créer'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Course course) {
    _nameController.text = course.name;
    _descriptionController.text = course.description;
    _selectedDuration = course.duration;
    _maxCapacityController.text = course.maxCapacity.toString();
    _priceController.text = course.price?.toString() ?? '0';
    _imageUrlController.text = course.imageUrl ?? '';
    // Vérifier que le terrain existe encore dans la liste
    if (course.facilityId != null && _terrains.any((t) => t.id == course.facilityId)) {
      _selectedFacilityId = course.facilityId;
    } else {
      _selectedFacilityId = null;
    }
    _selectedEquipment = course.equipment?.toList() ?? [];
    
    // Initialiser la date et l'heure s'ils sont disponibles
    _selectedDate = course.date;
    if (course.date != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(course.date!);
    } else {
      _dateController.clear();
    }
    
    _timeController.text = course.time ?? '';
    if (course.time != null && course.time!.isNotEmpty) {
      final timeParts = course.time!.split(':');
      if (timeParts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1])
        );
      }
    } else {
      _selectedTime = null;
    }

    // Variables pour la sélection d'équipement
    int? _selectedEquipmentId;
    int _selectedQuantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Modifier un cours',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _maxCapacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacité maximale',
                      prefixIcon: Icon(Icons.people),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prix',
                      prefixIcon: Icon(Icons.euro),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de l\'image',
                      prefixIcon: Icon(Icons.image),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Champ de date avec sélecteur
                  TextField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date du cours',
                      prefixIcon: Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_month),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 10),
                  // Champ d'heure avec sélecteur
                  DropdownButtonFormField<String>(
                    value: _timeController.text.isEmpty ? null : _timeController.text,
                    decoration: const InputDecoration(
                      labelText: 'Heure du cours',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    items: _availableHours.map((String hour) {
                      // Afficher l'heure au format HH:MM
                      final displayHour = hour.substring(0, 5);
                      return DropdownMenuItem<String>(
                        value: hour,
                        child: Text(displayHour),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _selectTimeFromList(newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    value: _selectedFacilityId,
                    decoration: const InputDecoration(
                      labelText: 'Terrain (optionnel)',
                      prefixIcon: Icon(Icons.place),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Aucun terrain'),
                      ),
                      ..._terrains.map((terrain) {
                        return DropdownMenuItem<int?>(
                          value: terrain.id,
                          child: Text(terrain.name),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFacilityId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _selectedDuration,
                    decoration: const InputDecoration(
                      labelText: 'Durée (minutes)',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    items: _durations.map((duration) {
                      return DropdownMenuItem<int>(
                        value: duration,
                        child: Text('$duration minutes'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDuration = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Équipements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Liste des équipements sélectionnés
                  if (_selectedEquipment.isEmpty)
                    const Text('Aucun équipement sélectionné'),
                  if (_selectedEquipment.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedEquipment.length,
                      itemBuilder: (context, index) {
                        final equipment = _selectedEquipment[index];
                        return ListTile(
                          title: Text(equipment.equipmentName ?? 'Équipement #${equipment.equipmentId}'),
                          subtitle: Text('Quantité: ${equipment.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _selectedEquipment.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  
                  // Section d'ajout d'équipement intégrée à la popup
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ajouter un équipement',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          // Sélection de l'équipement avec quantité disponible
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Équipement',
                              prefixIcon: const Icon(Icons.fitness_center, color: Color(0xFF3C64F4)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                              ),
                            ),
                            items: _availableEquipment.map((equipment) {
                              return DropdownMenuItem<int>(
                                value: equipment.id,
                                child: Text(
                                  '${equipment.name} (${equipment.availableQuantity})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedEquipmentId = value;
                                // Réinitialiser la quantité
                                _selectedQuantity = 1;
                              });
                            },
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Sélection de la quantité
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantité',
                              prefixIcon: const Icon(Icons.numbers, color: Color(0xFF3C64F4)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade700),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade800,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Bouton pour ajouter l'équipement à la liste
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter à la liste'),
                              onPressed: () {
                                if (_selectedEquipmentId != null) {
                                  final equipment = _availableEquipment.firstWhere(
                                    (e) => e.id == _selectedEquipmentId,
                                    orElse: () => Equipment(
                                      id: _selectedEquipmentId!,
                                      name: 'Équipement #$_selectedEquipmentId',
                                      description: '',
                                      totalQuantity: 0,
                                      availableQuantity: 0,
                                      condition: 'Bon',
                                      isAvailable: true,
                                    ),
                                  );
                                  
                                  setState(() {
                                    final courseEquipment = CourseEquipment(
                                      equipmentId: equipment.id!,
                                      quantity: _selectedQuantity,
                                      equipmentName: equipment.name,
                                      equipmentDescription: equipment.description,
                                    );
                                    
                                    print('Ajout équipement: ${equipment.name}, ID: ${equipment.id}, Qté: $_selectedQuantity');
                                    _selectedEquipment.add(courseEquipment);
                                    
                                    // Réinitialiser les champs
                                    _selectedEquipmentId = null;
                                    _selectedQuantity = 1;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez sélectionner un équipement')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          final updatedCourse = Course(
                            id: course.id,
                            name: _nameController.text,
                            description: _descriptionController.text,
                            duration: _selectedDuration,
                            maxCapacity: int.tryParse(_maxCapacityController.text) ?? course.maxCapacity,
                            availableSpots: course.availableSpots,
                            price: double.tryParse(_priceController.text),
                            facilityId: _selectedFacilityId,
                            facilityName: course.facilityName,
                            isTerrain: course.isTerrain,
                            imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
                            date: _selectedDate,
                            time: _timeController.text.isEmpty ? null : _timeController.text,
                            equipment: _selectedEquipment,
                          );
                          _updateCourse(updatedCourse);
                        },
                        child: const Text('Mettre à jour'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Gestion des Cours',
      currentIndex: 1,
      isAdminMode: true,
      body: Stack(
        children: [
          _buildCoursesList(),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _showAddCourseDialog,
              backgroundColor: const Color(0xFF3C64F4),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loadCourses,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Aucun cours disponible'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddCourseDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3C64F4),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Ajouter un cours'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _courses.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final course = _courses[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course image
              if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    course.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Icon(Icons.school, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.school, size: 50, color: Colors.grey),
                  ),
                ),
              // Course details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            course.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${course.price?.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3C64F4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${course.duration} min',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${course.availableSpots}/${course.maxCapacity} places',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Afficher les détails des équipements
                    if (course.equipment != null && course.equipment!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Équipements (${course.equipment!.length}):',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...course.equipment!.take(3).map((equipment) => 
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Text(
                                '• ${equipment.equipmentName ?? 'Équipement #${equipment.equipmentId}'} (${equipment.quantity})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          ).toList(),
                          if (course.equipment!.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Text(
                                '• Et ${course.equipment!.length - 3} autres...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _showEditDialog(course);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteCourse(course.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getFacilityName(int facilityId) {
    final facility = _facilities.firstWhere(
      (f) => f.id == facilityId,
      orElse: () => Facility(id: facilityId, name: 'Installation inconnue', description: ''),
    );
    return facility.name;
  }

  void _confirmDelete(Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le cours "${course.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteCourse(course.id);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Fonction pour sélectionner une date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  // Fonction pour sélectionner une heure depuis la liste
  void _selectTimeFromList(String time) {
    setState(() {
      _timeController.text = time;
      
      // Mettre à jour _selectedTime pour compatibilité
      if (time.isNotEmpty) {
        final timeParts = time.split(':');
        if (timeParts.length >= 2) {
          _selectedTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1])
          );
        }
      }
    });
  }

  // Fonction utilitaire pour calculer l'heure de fin
  String _calculateEndTime(String startTime, int durationMinutes) {
    final parts = startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final DateTime startDateTime = DateTime(2025, 1, 1, hour, minute);
    final DateTime endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
    
    return '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';
  }

  // Méthode pour ajouter un équipement à la liste
  void _addEquipment() {
    if (_selectedEquipmentId != null) {
      final equipment = _availableEquipment.firstWhere(
        (e) => e.id == _selectedEquipmentId,
        orElse: () => Equipment(
          id: _selectedEquipmentId!,
          name: 'Équipement #$_selectedEquipmentId',
          description: '',
          totalQuantity: 0,
          availableQuantity: 0,
          condition: 'Bon',
          isAvailable: true,
        ),
      );
      
      int quantity = int.tryParse(_quantityController.text) ?? 1;
      if (quantity <= 0) quantity = 1;
      
      setState(() {
        // Créer un nouvel équipement
        final courseEquipment = CourseEquipment(
          equipmentId: equipment.id!,
          quantity: quantity,
          equipmentName: equipment.name,
          equipmentDescription: equipment.description,
        );
        
        // Vérifier si cet équipement existe déjà
        final existingIndex = _selectedEquipment.indexWhere(
          (e) => e.equipmentId == equipment.id
        );
        
        if (existingIndex >= 0) {
          // Remplacer l'équipement existant
          _selectedEquipment[existingIndex] = courseEquipment;
        } else {
          // Ajouter un nouvel équipement
          _selectedEquipment.add(courseEquipment);
        }
        
        // Réinitialiser
        _selectedEquipmentId = null;
        _quantityController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un équipement')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _isUploading = true;
        });
        
        try {
          print('Fichier sélectionné: ${image.path}');
          
          // Lire les bytes directement depuis XFile sans convertir en File
          final bytes = await image.readAsBytes();
          
          // Créer un formulaire multipart directement
          final uri = Uri.parse('${_apiService.baseUrl}/upload');
          final request = http.MultipartRequest('POST', uri);
          
          // Ajouter le token si disponible
          final token = await _apiService.getToken();
          if (token != null) {
            request.headers.addAll({
              'Authorization': 'Bearer $token',
            });
          }
          
          // Ajouter le dossier de destination
          request.fields['folder'] = 'courses';
          
          // Créer le fichier multipart à partir des bytes
          final fileName = image.name.isNotEmpty ? image.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Déterminer le type MIME
          final mimeType = image.mimeType ?? 'image/jpeg';
          final extension = mimeType.split('/').last;
          
          final multipartFile = http.MultipartFile.fromBytes(
            'image', 
            bytes,
            filename: fileName,
            contentType: MediaType(mimeType.split('/').first, extension),
          );
          
          request.files.add(multipartFile);
          
          // Envoyer la requête
          print('Envoi de la requête multipart...');
          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          
          print('Réponse reçue: ${response.statusCode}, ${response.body}');
          
          if (response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final imageUrl = data['imageUrl'];
            
            setState(() {
              _imageUrlController.text = imageUrl;
              _isUploading = false;
            });
            print('Image uploadée avec succès: $imageUrl');
          } else {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur lors de l\'upload de l\'image: ${response.body}')),
            );
          }
        } catch (e) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'upload de l\'image: $e')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l\'image: $e')),
      );
    }
  }
} 