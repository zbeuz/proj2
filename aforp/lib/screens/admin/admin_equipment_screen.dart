import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../../models/equipment.dart';
import '../../services/api_service.dart';
import '../base_screen.dart';

class AdminEquipmentScreen extends StatefulWidget {
  const AdminEquipmentScreen({Key? key}) : super(key: key);

  @override
  _AdminEquipmentScreenState createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen> {
  final ApiService _apiService = ApiService();
  List<Equipment> _equipment = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _totalQuantityController = TextEditingController();
  final TextEditingController _availableQuantityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final ValueNotifier<bool> _isAvailableNotifier = ValueNotifier<bool>(true);
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  String _selectedCondition = 'Bon';

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _totalQuantityController.dispose();
    _availableQuantityController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    super.dispose();
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
          request.fields['folder'] = 'equipment';
          
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

  Future<void> _loadEquipment() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
      
    try {
      List<Equipment> loadedEquipment = await _apiService.getAllEquipment();
      if (mounted) {
      setState(() {
          _equipment = loadedEquipment;
        _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement de l\'équipement: $e')),
        );
      }
    }
  }

  Future<void> _createEquipment(Equipment equipment) async {
    try {
      await _apiService.createEquipment(equipment);
      Navigator.of(context).pop();
      _resetControllers();
      _loadEquipment();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Équipement créé avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création: $e')),
      );
    }
  }

  Future<void> _updateEquipment(Equipment equipment) async {
    try {
      // Vérification des données
      final totalQuantity = int.tryParse(_totalQuantityController.text) ?? 0;
      final availableQuantity = int.tryParse(_availableQuantityController.text) ?? 0;
      
      if (totalQuantity < 0 || availableQuantity < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les quantités ne peuvent pas être négatives')),
        );
        return;
      }
      
      if (availableQuantity > totalQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La quantité disponible ne peut pas être supérieure à la quantité totale')),
        );
        return;
      }
      
      equipment = equipment.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
        totalQuantity: totalQuantity,
        availableQuantity: availableQuantity,
        category: _categoryController.text.isEmpty ? null : _categoryController.text,
        condition: _selectedCondition,
        isAvailable: _isAvailableNotifier.value,
      );

      await _apiService.updateEquipment(equipment);
      Navigator.of(context).pop();
      _resetControllers();
      _loadEquipment();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Équipement mis à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  Future<void> _deleteEquipment(Equipment equipment) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${equipment.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                if (equipment.id != null) {
                  await _apiService.deleteEquipment(equipment.id!);
                  _loadEquipment();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Équipement supprimé avec succès')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erreur: ID d\'équipement manquant')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la suppression: $e')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return Future.value();
  }

  void _resetControllers() {
    _nameController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _totalQuantityController.clear();
    _availableQuantityController.clear();
    _categoryController.clear();
    _conditionController.clear();
    _isAvailableNotifier.value = true;
    setState(() {
      _selectedImage = null;
    });
  }

  void _showAddEquipmentDialog() {
    _nameController.clear();
    _descriptionController.clear();
    _totalQuantityController.clear();
    _availableQuantityController.clear();
    _imageUrlController.clear();
    _selectedCondition = 'Bon';
    
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
                    const Icon(Icons.fitness_center, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: const Text(
                        'Ajouter un équipement',
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
                          labelText: 'Nom de l\'équipement',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.sports_basketball, color: Color(0xFF3C64F4)),
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
                        'Quantités',
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
                              controller: _totalQuantityController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantité totale',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.inventory, color: Color(0xFF3C64F4)),
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
                              controller: _availableQuantityController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantité disponible',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.check_circle, color: Color(0xFF3C64F4)),
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
                        'État',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C64F4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCondition,
                        dropdownColor: Colors.grey.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'État de l\'équipement',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.handyman, color: Color(0xFF3C64F4)),
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
                        items: ['Neuf', 'Bon', 'Moyen', 'Mauvais'].map((String condition) {
                          return DropdownMenuItem<String>(
                            value: condition,
                            child: Text(condition),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCondition = newValue;
                            });
                          }
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
                      onPressed: () {
                        if (_nameController.text.isEmpty || 
                            _totalQuantityController.text.isEmpty || 
                            _availableQuantityController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
                          );
                          return;
                        }
                        
                        final totalQuantity = int.tryParse(_totalQuantityController.text) ?? 0;
                        final availableQuantity = int.tryParse(_availableQuantityController.text) ?? 0;
                        
                        if (availableQuantity > totalQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La quantité disponible ne peut pas être supérieure à la quantité totale')),
                          );
                          return;
                        }
                        
                        final newEquipment = Equipment(
                          name: _nameController.text,
                          description: _descriptionController.text,
                          totalQuantity: totalQuantity,
                          availableQuantity: availableQuantity,
                          imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
                          condition: _selectedCondition,
                          isAvailable: true,
                        );
                        
                        _createEquipment(newEquipment);
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

  void _showEditEquipmentDialog(Equipment equipment) {
    _nameController.text = equipment.name;
    _descriptionController.text = equipment.description ?? '';
    _totalQuantityController.text = equipment.totalQuantity.toString();
    _availableQuantityController.text = equipment.availableQuantity.toString();
    _imageUrlController.text = equipment.imageUrl ?? '';
    _selectedCondition = equipment.condition;
    
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
                    const Icon(Icons.fitness_center, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: const Text(
                        'Modifier l\'équipement',
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
                          labelText: 'Nom de l\'équipement',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.sports_basketball, color: Color(0xFF3C64F4)),
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
                        'Quantités',
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
                              controller: _totalQuantityController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantité totale',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.inventory, color: Color(0xFF3C64F4)),
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
                              controller: _availableQuantityController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantité disponible',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.check_circle, color: Color(0xFF3C64F4)),
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
                        'État',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C64F4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCondition,
                        dropdownColor: Colors.grey.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'État de l\'équipement',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.handyman, color: Color(0xFF3C64F4)),
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
                        items: ['Neuf', 'Bon', 'Moyen', 'Mauvais'].map((String condition) {
                          return DropdownMenuItem<String>(
                            value: condition,
                            child: Text(condition),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCondition = newValue;
                            });
                          }
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
                      onPressed: () {
                        if (_nameController.text.isEmpty || 
                            _totalQuantityController.text.isEmpty || 
                            _availableQuantityController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
                          );
                          return;
                        }
                        
                        final totalQuantity = int.tryParse(_totalQuantityController.text) ?? 0;
                        final availableQuantity = int.tryParse(_availableQuantityController.text) ?? 0;
                        
                        if (availableQuantity > totalQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La quantité disponible ne peut pas être supérieure à la quantité totale')),
                          );
                          return;
                        }
                        
                        final updatedEquipment = Equipment(
                          id: equipment.id,
                          name: _nameController.text,
                          description: _descriptionController.text,
                          totalQuantity: totalQuantity,
                          availableQuantity: availableQuantity,
                          imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
                          condition: _selectedCondition,
                          isAvailable: equipment.isAvailable,
                        );
                        
                        _updateEquipment(updatedEquipment);
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF3C64F4),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Mettre à jour'),
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

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Gestion des Équipements',
      currentIndex: 2,
      isAdminMode: true,
      body: Stack(
        children: [
          _buildEquipmentList(),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
        onPressed: () => _showAddEquipmentDialog(),
              backgroundColor: const Color(0xFF3C64F4),
        child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentList() {
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
              onPressed: _loadEquipment,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_equipment.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Aucun équipement disponible', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showAddEquipmentDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3C64F4),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Ajouter un équipement'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _equipment.length,
      itemBuilder: (context, index) {
        final equipment = _equipment[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Equipment image
              if (equipment.imageUrl != null && equipment.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    equipment.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Icon(Icons.fitness_center, size: 50, color: Colors.grey),
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
                    child: Icon(Icons.fitness_center, size: 50, color: Colors.grey),
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
                            equipment.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildAvailabilityBadge(equipment.isAvailable),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      equipment.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade300),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.inventory, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Disponible: ${equipment.availableQuantity}/${equipment.totalQuantity}'),
                        const Spacer(),
                        if (equipment.category != null && equipment.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              equipment.category!,
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 12,
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
                          icon: const Icon(Icons.edit, color: Color(0xFF3C64F4)),
                          onPressed: () => _showEditEquipmentDialog(equipment),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteEquipment(equipment),
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
} 