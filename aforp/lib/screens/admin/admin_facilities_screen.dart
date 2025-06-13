import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../../models/facility.dart';
import '../../services/api_service.dart';
import '../base_screen.dart';

class AdminFacilitiesScreen extends StatefulWidget {
  const AdminFacilitiesScreen({Key? key}) : super(key: key);

  @override
  _AdminFacilitiesScreenState createState() => _AdminFacilitiesScreenState();
}

class _AdminFacilitiesScreenState extends State<AdminFacilitiesScreen> {
  final ApiService _apiService = ApiService();
  List<Facility> _facilities = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  final TextEditingController _closingHoursController = TextEditingController();
  bool _isAvailable = true;
  bool _isTerrain = true;
  String _selectedOpeningHour = '08:00';
  String _selectedClosingHour = '20:00';
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  
  // Liste des heures disponibles
  final List<String> _availableHours = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00', 
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', 
    '19:00', '20:00', '21:00', '22:00', '23:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
    _openingHoursController.text = _selectedOpeningHour;
    _closingHoursController.text = _selectedClosingHour;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _openingHoursController.dispose();
    _closingHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
      setState(() {
        _isLoading = true;
      _errorMessage = '';
      });

    try {
      final facilities = await _apiService.getAllFacilities();
      setState(() {
        _facilities = facilities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des installations: $e';
      });
    }
  }

  Future<void> _createFacility(Map<String, dynamic> facilityData) async {
    try {
      // Créer l'objet Facility correctement
      final facility = Facility(
        name: facilityData['name'] ?? '',
        description: facilityData['description'] ?? '',
        imageUrl: facilityData['image_url'],
        openingHours: facilityData['opening_hours'],
        closingHours: facilityData['closing_hours'],
        isAvailable: facilityData['is_available'] == 1,
        isTerrain: facilityData['is_terrain'] == 1,
      );
      
      // Afficher les données pour debug
      print("Création d'installation avec les données: ${facility.toJson()}");
      
      // Appel à l'API
      await _apiService.createFacility(facility);
      
      // Recharger la liste et réinitialiser le formulaire
      _loadFacilities();
      _resetControllers();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installation créée avec succès')),
      );
    } catch (e) {
      print("Erreur lors de la création de l'installation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création: $e')),
      );
    }
  }

  Future<void> _updateFacility(Facility facility) async {
    try {
      Facility updatedFacility = facility.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
        openingHours: _selectedOpeningHour,
        closingHours: _selectedClosingHour,
        isAvailable: _isAvailable,
        isTerrain: true,
      );

      await _apiService.updateFacility(updatedFacility);
      _loadFacilities();
      _resetControllers();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terrain mis à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du terrain: $e')),
      );
    }
  }

  Future<void> _deleteFacility(int? facilityId) async {
    if (facilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: ID d\'installation manquant')),
      );
      return;
    }
    
    try {
      await _apiService.deleteFacility(facilityId);
      _loadFacilities();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installation supprimée avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }

  void _resetControllers() {
    _nameController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _selectedOpeningHour = '08:00';
    _selectedClosingHour = '20:00';
    _openingHoursController.text = _selectedOpeningHour;
    _closingHoursController.text = _selectedClosingHour;
    _isAvailable = true;
    _isTerrain = true;
    setState(() {
      _selectedImage = null;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _selectedOpeningHour = '08:00';
    _selectedClosingHour = '20:00';
    _openingHoursController.text = _selectedOpeningHour;
    _closingHoursController.text = _selectedClosingHour;
    _isAvailable = true;
    _isTerrain = true;
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
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
          request.fields['folder'] = 'facilities';
          
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

  void _showAddFacilityDialog() {
    _nameController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _openingHoursController.text = '08:00';
    _closingHoursController.text = '20:00';
    _isTerrain = true;
    _selectedImage = null;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
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
                    const Icon(Icons.place, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: const Text(
                        'Ajouter une installation',
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
              Flexible(
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
                          labelText: 'Nom de l\'installation',
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
                      const SizedBox(height: 16),
                      
                      // Interface d'upload d'image
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
                          
                          // Visualisation de l'image
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade700),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade800,
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
                          ),
                          
                          // Bouton d'upload et champ URL
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Choisir une image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3C64F4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _imageUrlController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'URL de l\'image (optionnel)',
                              labelStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.link, color: Color(0xFF3C64F4)),
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
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Horaires',
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
                              controller: _openingHoursController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Heure d\'ouverture',
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
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _closingHoursController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Heure de fermeture',
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
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Type d\'installation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C64F4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text(
                          'Terrain sportif',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Cochez si cette installation est un terrain',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        value: _isTerrain,
                        activeColor: const Color(0xFF3C64F4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        tileColor: Colors.grey.shade800,
                        onChanged: (bool value) {
                          setState(() {
                            _isTerrain = value;
                          });
                        },
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
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Le nom est requis')),
                          );
                          return;
                        }
                        
                        final newFacility = {
                          'name': _nameController.text,
                          'description': _descriptionController.text,
                          'image_url': _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
                          'opening_hours': _openingHoursController.text,
                          'closing_hours': _closingHoursController.text,
                          'is_terrain': _isTerrain ? 1 : 0,
                          'is_available': 1,
                        };
                        
                        try {
                          await _createFacility(newFacility);
                          Navigator.of(context).pop();
                        } catch (e) {
                          // L'erreur est déjà gérée dans _createFacility
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
        ),
      ),
    );
  }

  void _showEditDialog(Facility facility) {
    _nameController.text = facility.name ?? '';
    _descriptionController.text = facility.description ?? '';
    _imageUrlController.text = facility.imageUrl ?? '';
    _selectedOpeningHour = facility.openingHours ?? '08:00';
    _selectedClosingHour = facility.closingHours ?? '20:00';
    _openingHoursController.text = _selectedOpeningHour;
    _closingHoursController.text = _selectedClosingHour;
    _isAvailable = facility.isAvailable ?? true;
    _isTerrain = facility.isTerrain ?? true;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Row(
                children: [
                  const Icon(Icons.edit, color: Color(0xFF3C64F4)),
                  const SizedBox(width: 10),
                  const Text(
                    'Modifier le terrain',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              
              // Corps du formulaire
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nom du terrain *',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Image
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
                      
                      const SizedBox(height: 16),
                      
                      // Horaires
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Ouverture',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                              ),
                              value: _selectedOpeningHour,
                              items: _availableHours.map((String hour) {
                                return DropdownMenuItem<String>(
                                  value: hour,
                                  child: Text(hour),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedOpeningHour = newValue;
                                    _openingHoursController.text = newValue;
                                  });
                                }
                              },
                              dropdownColor: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Fermeture',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                              ),
                              value: _selectedClosingHour,
                              items: _availableHours.map((String hour) {
                                return DropdownMenuItem<String>(
                                  value: hour,
                                  child: Text(hour),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedClosingHour = newValue;
                                    _closingHoursController.text = newValue;
                                  });
                                }
                              },
                              dropdownColor: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Disponibilité
                      SwitchListTile(
                        title: const Text('Disponible'),
                        value: _isAvailable,
                        activeColor: const Color(0xFF3C64F4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _isAvailable = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              // Actions
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _clearForm();
                    },
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
                        );
                        return;
                      }
                      
                      final updatedFacility = Facility(
                        id: facility.id,
                        name: _nameController.text,
                        description: _descriptionController.text,
                        imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
                        openingHours: _selectedOpeningHour,
                        closingHours: _selectedClosingHour,
                        isAvailable: _isAvailable,
                        isTerrain: true,
                      );
                      
                      Navigator.of(context).pop();
                      _updateFacility(updatedFacility);
                      _clearForm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C64F4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Gestion des Terrains',
      currentIndex: 3,
      isAdminMode: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadFacilities,
              child: const Text('Réessayer'),
            ),
          ],
                    ),
                  );
                }

    if (_facilities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Aucune installation trouvée'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAddFacilityDialog,
              child: const Text('Ajouter une installation'),
            ),
          ],
                  ),
                );
              }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _facilities.length,
          itemBuilder: (context, index) {
            final facility = _facilities[index];
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Facility image
                  if (facility.imageUrl != null && facility.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        facility.imageUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 150,
                          color: Colors.grey.shade800,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                facility.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildAvailabilityBadge(facility.isAvailable),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          facility.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        const SizedBox(height: 8),
                        if (facility.openingHours != null && facility.closingHours != null)
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('${facility.openingHours} - ${facility.closingHours}'),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFF3C64F4)),
                              onPressed: () => _showEditDialog(facility),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(facility),
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
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _showAddFacilityDialog,
            backgroundColor: const Color(0xFF3C64F4),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityBadge(bool isAvailable) {
    Color color = isAvailable ? const Color(0xFF32D74B) : Colors.red;
    String label = isAvailable ? 'Disponible' : 'Non disponible';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _confirmDelete(Facility facility) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer l\'installation "${facility.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFacility(facility.id);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
} 