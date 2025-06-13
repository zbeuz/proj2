import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/facility.dart';
import '../models/equipment.dart';
import '../models/course.dart';
import '../models/reservation.dart';

class ApiService {
  // L'adresse IP et le port du serveur Node.js
  final String baseUrl = 'http://185.157.247.18:3000/api';
  final storage = FlutterSecureStorage();

  // Clé pour stocker le token dans les préférences partagées
  static const String TOKEN_KEY = 'auth_token';

  // MÉTHODES D'AUTHENTIFICATION

  // Méthode pour s'inscrire
  Future<User> register(String username, String email, String password, {String? name}) async {
    try {
      print('Tentative d\'inscription: $baseUrl/auth/register');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'name': name,
        }),
      ).timeout(Duration(seconds: 15));

      print('Statut de la réponse: ${response.statusCode}');
      print('Contenu de la réponse: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        
        // Stocker le token
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(user.toJson()));
        
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de l\'inscription');
      }
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  // Méthode pour se connecter
  Future<User> login(String email, String password) async {
    try {
      print('Tentative de connexion à: $baseUrl/auth/login');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(Duration(seconds: 15));

      print('Statut de la réponse: ${response.statusCode}');
      print('Contenu de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Vérifier si les données utilisateur sont disponibles
        if (data['user'] == null) {
          print('ERREUR: Données utilisateur manquantes dans la réponse');
          throw Exception('Données utilisateur invalides');
        }
        
        // Analyser le contenu JSON pour débogage
        print('DONNÉES UTILISATEUR COMPLÈTES: ${data['user']}');
        
        if (data['user'] is Map) {
          // Vérifier si le champ de rôle existe dans les données
          if (data['user'].containsKey('role')) {
            print('RÔLE TROUVÉ DANS LES DONNÉES: ${data['user']['role']}');
          } else {
            print('AUCUN CHAMP RÔLE TROUVÉ DANS LES DONNÉES. Clés disponibles: ${data['user'].keys.toList()}');
            
            // Chercher des clés alternatives qui pourraient contenir le rôle
            final possibleRoleKeys = data['user'].keys.where(
              (key) => key.toString().toLowerCase().contains('role') || 
                       key.toString().toLowerCase().contains('admin')
            ).toList();
            
            if (possibleRoleKeys.isNotEmpty) {
              print('CLÉS POTENTIELLES POUR LE RÔLE: $possibleRoleKeys');
              for (final key in possibleRoleKeys) {
                print('VALEUR POUR $key: ${data['user'][key]}');
              }
            }
          }
        }
        
        // Créer l'utilisateur et vérifier le rôle
        final user = User.fromJson(data['user']);
        print('UTILISATEUR CONNECTÉ: ${user.username}, RÔLE: ${user.role}');
        
        // Stocker le token et les données utilisateur
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(user.toJson()));
        
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la connexion');
      }
    } on SocketException {
      throw Exception('Impossible de se connecter au serveur');
    } on HttpException {
      throw Exception('Erreur HTTP');
    } on FormatException {
      throw Exception('Erreur de format de la réponse');
    } on TimeoutException {
      throw Exception('La requête a pris trop de temps');
    } catch (e) {
      print('Erreur lors de la connexion: $e');
      rethrow;
    }
  }

  // Méthode pour se déconnecter
  Future<void> logout() async {
    await storage.delete(key: 'token');
    await storage.delete(key: 'user');
  }

  // Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    try {
      final token = await storage.read(key: 'token');
      return token != null;
    } catch (e) {
      print('Erreur lors de la vérification de connexion: $e');
      return false;
    }
  }

  // Récupérer l'utilisateur actuel
  Future<User?> getCurrentUser() async {
    try {
      final userJson = await storage.read(key: 'user');
      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }

  // Récupérer le token JWT
  Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  // MÉTHODES POUR LES UTILISATEURS
  
  // Récupérer tous les utilisateurs (pour l'administration)
  Future<List<User>> getAllUsers() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Récupération des utilisateurs - Statut: ${response.statusCode}');
      print('Récupération des utilisateurs - Contenu: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des utilisateurs');
      }
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs: $e');
      throw Exception('Erreur lors de la récupération des utilisateurs: $e');
    }
  }
  
  // Alias pour getAllUsers pour correspondre à l'implémentation dans admin_users_screen
  Future<List<User>> getUsers() async {
    return getAllUsers();
  }
  
  // Ajouter un utilisateur (admin seulement)
  Future<User> addUser(User user, String password) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': user.username,
          'email': user.email,
          'password': password,
          'role': user.role,
          'name': user.name,
        }),
      );

      if (response.statusCode == 201) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de l\'ajout de l\'utilisateur');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de l\'ajout de l\'utilisateur');
    }
  }
  
  // Créer un utilisateur à partir d'un Map
  Future<User> createUser(Map<String, dynamic> userData) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la création de l\'utilisateur');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la création de l\'utilisateur');
    }
  }
  
  // Mettre à jour un utilisateur (admin seulement)
  Future<User> updateUserById(int id, User user) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/users/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': user.username,
          'email': user.email,
          'role': user.role,
          'name': user.name,
        }),
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la mise à jour de l\'utilisateur');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la mise à jour de l\'utilisateur');
    }
  }
  
  // Méthode simplifiée pour la mise à jour d'un utilisateur
  Future<User> updateUser(User user) async {
    if (user.id == null) {
      throw Exception('ID d\'utilisateur non défini');
    }
    return updateUserById(user.id!, user);
  }
  
  // Supprimer un utilisateur (admin seulement)
  Future<void> deleteUser(int id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la suppression de l\'utilisateur');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la suppression de l\'utilisateur');
    }
  }

  // MÉTHODES POUR LES TERRAINS/INSTALLATIONS

  // Récupérer toutes les installations
  Future<List<Facility>> getAllFacilities() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/facilities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Facility.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des installations');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la récupération des installations');
    }
  }
  
  // Legacy method - used by getFacilities, keep for compatibility
  Future<List<Facility>> getFacilities() async {
    try {
      final User? user = await getCurrentUser();
      if (user == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/facilities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Facility.fromJson(json)).toList();
      } else {
        print('Erreur lors de la récupération des terrains: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception lors de la récupération des terrains: $e');
      return [];
    }
  }
  
  // Supprimer une installation
  Future<void> deleteFacility(int id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/facilities/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la suppression de l\'installation');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la suppression de l\'installation');
    }
  }
  
  // Créer une installation
  Future<Facility> createFacility(Facility facility) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token non trouvé, veuillez vous connecter');
      }
      
      // Préparer les données à envoyer, en supprimant l'id
      final Map<String, dynamic> data = facility.toJson()..remove('id');
      
      // Log pour debug
      print('Envoi de création d\'installation: $data');
      print('URL API: $baseUrl/facilities');
      
      final response = await http.post(
        Uri.parse('$baseUrl/facilities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print('Statut de réponse: ${response.statusCode}');
      print('Corps de réponse: ${response.body}');

      if (response.statusCode == 201) {
        return Facility.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la création de l\'installation: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur de création d\'installation: $e');
      throw Exception('Erreur lors de la création de l\'installation: $e');
    }
  }
  
  // Mettre à jour une installation
  Future<Facility> updateFacility(Facility facility) async {
    if (facility.id == null) {
      throw Exception('L\'ID de l\'installation est requis pour la mise à jour');
    }
    
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/facilities/${facility.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(facility.toJson()),
      );

      if (response.statusCode == 200) {
        return Facility.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la mise à jour de l\'installation');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la mise à jour de l\'installation');
    }
  }

  // MÉTHODES POUR LES ÉQUIPEMENTS

  // Récupérer tous les équipements
  Future<List<Equipment>> getAllEquipment() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/equipment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> equipmentJson = json.decode(response.body);
        return equipmentJson.map((json) => Equipment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load equipment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load equipment: $e');
    }
  }

  // Récupérer un équipement par ID
  Future<Equipment?> getEquipmentItem(int id) async {
    try {
      final User? user = await getCurrentUser();
      if (user == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/equipment/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );

      if (response.statusCode == 200) {
        return Equipment.fromJson(json.decode(response.body));
      } else {
        print('Erreur lors de la récupération de l\'équipement: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception lors de la récupération de l\'équipement: $e');
      return null;
    }
  }

  // Créer un équipement
  Future<Equipment> createEquipment(Equipment equipment) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token not found, please login first');
      }
      
      final Map<String, dynamic> data = equipment.toJson();
      
      // Debug logging
      print('Creating equipment with data: $data');
      print('API URL: $baseUrl/equipment');
      
      final response = await http.post(
        Uri.parse('$baseUrl/equipment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return Equipment.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create equipment: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating equipment: $e');
      throw Exception('Failed to create equipment: $e');
    }
  }

  // Mettre à jour un équipement
  Future<Equipment> updateEquipment(Equipment equipment) async {
    if (equipment.id == null) {
      throw Exception('Equipment ID cannot be null');
    }
    
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token not found, please login first');
      }
      
      final Map<String, dynamic> data = equipment.toJson();
      
      // Debug logging
      print('Updating equipment with data: $data');
      print('API URL: $baseUrl/equipment/${equipment.id}');
      
      final response = await http.put(
        Uri.parse('$baseUrl/equipment/${equipment.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return Equipment.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update equipment: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating equipment: $e');
      throw Exception('Failed to update equipment: $e');
    }
  }

  // Supprimer un équipement
  Future<void> deleteEquipment(int id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/equipment/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete equipment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete equipment: $e');
    }
  }

  // MÉTHODES POUR LES COURS

  // Récupérer tous les cours
  Future<List<Course>> getCourses() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/courses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des cours');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la récupération des cours');
    }
  }

  // Récupérer un cours par ID
  Future<Course> getCourse(int id) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Course.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Erreur lors de la récupération du cours');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la récupération du cours');
    }
  }

  // MÉTHODES POUR LES RÉSERVATIONS

  // Récupérer toutes les réservations de l'utilisateur
  Future<List<Reservation>> getUserReservations() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Utilisateur non connecté');

      final response = await http.get(
        Uri.parse('$baseUrl/reservations/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('Réponse réservations - statut: ${response.statusCode}');
        print('Réponse réservations - contenu: ${response.body}');
        
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Reservation.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des réservations: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la récupération des réservations');
    }
  }

  // Créer une réservation
  Future<Reservation> createReservation(Reservation reservation) async {
    try {
      final token = await getToken();
      
      // Préparer les données de la réservation avec le bon format
      final Map<String, dynamic> reservationData = reservation.toJson();
      
      // Si nous avons des dates au format string, convertissons-les en format datetime
      if (reservationData['date'] != null && 
          reservationData['start_time'] != null && 
          reservationData['end_time'] != null) {
        
        final String date = reservationData['date'];
        final String startTime = reservationData['start_time'];
        final String endTime = reservationData['end_time'];
        
        // Construire les datetime complets pour start_time et end_time
        final startDateTime = DateTime.parse('${date}T${startTime}');
        final endDateTime = DateTime.parse('${date}T${endTime}');
        
        // Mettre à jour les données à envoyer à l'API
        reservationData['start_time'] = startDateTime.toIso8601String();
        reservationData['end_time'] = endDateTime.toIso8601String();
        
        // Supprimer le champ date qui n'existe pas dans la base de données
        reservationData.remove('date');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/reservations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(reservationData),
      );

      if (response.statusCode == 201) {
        return Reservation.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Erreur lors de la création de la réservation');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la création de la réservation');
    }
  }

  // Annuler une réservation
  Future<void> cancelReservation(int id) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      print('Tentative d\'annulation de la réservation ID: $id');
      final url = '$baseUrl/reservations/$id/cancel';
      print('URL: $url');
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({"status": "Annulée"}),
      ).timeout(const Duration(seconds: 10));

      print('Réponse d\'annulation - statut: ${response.statusCode}');
      print('Réponse d\'annulation - contenu: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        if (!responseData['success']) {
          throw Exception(responseData['message'] ?? 'Erreur lors de l\'annulation');
        }
      } else {
        throw Exception('Erreur lors de l\'annulation: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('La requête a pris trop de temps. Veuillez réessayer.');
    } on SocketException {
      throw Exception('Erreur de connexion au serveur. Vérifiez votre connexion internet.');
    } catch (e) {
      print('Erreur détaillée lors de l\'annulation de la réservation: $e');
      throw Exception('Erreur lors de l\'annulation de la réservation: $e');
    }
  }

  // Test de connexion simple
  Future<bool> testConnection() async {
    try {
      final String serverUrl = baseUrl.substring(0, baseUrl.lastIndexOf('/api'));
      print('Tentative de ping vers: $serverUrl/ping');
      
      final response = await http.get(
        Uri.parse('$serverUrl/ping'),
      ).timeout(Duration(seconds: 10));
      
      print('Statut de la réponse ping: ${response.statusCode}');
      print('Contenu de la réponse ping: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors du test de connexion: $e');
      return false;
    }
  }

  // Méthodes privées pour la gestion du token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TOKEN_KEY, token);
  }
  
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(TOKEN_KEY);
  }
  
  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(TOKEN_KEY);
  }

  // MÉTHODES POUR LES COURS

  // Récupérer tous les cours
  Future<List<Course>> getAllCourses() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/courses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Réponse courses - statut: ${response.statusCode}');
      print('Réponse courses - contenu: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return [];
        }
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Erreur courses: $e');
      return []; // Retourne une liste vide au lieu de lancer une exception
    }
  }
  
  // Créer un cours
  Future<Course> createCourse(Map<String, dynamic> courseData) async {
    try {
      final token = await getToken();
      
      // Debug - Afficher les données envoyées
      print('Création de cours - données envoyées: ${jsonEncode(courseData)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/courses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(courseData),
      );

      print('Création de cours - statut: ${response.statusCode}');
      print('Création de cours - réponse: ${response.body}');

      if (response.statusCode == 201) {
        return Course.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la création du cours');
      }
    } catch (e) {
      print('Erreur détaillée lors de la création du cours: $e');
      throw Exception('Erreur lors de la création du cours');
    }
  }
  
  // Mettre à jour un cours
  Future<Course> updateCourse(Map<String, dynamic> courseData) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/courses/${courseData['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(courseData),
      );

      if (response.statusCode == 200) {
        return Course.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la mise à jour du cours');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la mise à jour du cours');
    }
  }
  
  // Supprimer un cours
  Future<void> deleteCourse(int id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/courses/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la suppression du cours');
      }
    } catch (e) {
      print('Erreur: $e');
      throw Exception('Erreur lors de la suppression du cours');
    }
  }

  // Méthode pour uploader une image
  Future<String?> uploadImage(File imageFile, String folder) async {
    try {
      final token = await getToken();
      
      // Log pour debugging
      print('Début de l\'upload d\'image. Fichier: ${imageFile.path}, dossier: $folder');
      print('URL d\'upload: $baseUrl/upload');
      
      // Vérifier si nous sommes sur le web (les URLs commencent par 'blob:' ou 'http')
      final bool isWeb = imageFile.path.startsWith('blob:') || imageFile.path.startsWith('http');
      
      if (isWeb) {
        // Dans le cas du web, on utilise XFile et FormData pour créer la requête
        print('Détection de Flutter Web, utilisation de la méthode adaptée pour le web');
        
        // Créer le FormData directement
        var uri = Uri.parse('$baseUrl/upload');
        var request = http.MultipartRequest('POST', uri);
        
        // Ajouter l'autorisation
        if (token != null) {
          request.headers.addAll({
            'Authorization': 'Bearer $token',
          });
        }
        
        // Ajouter le dossier
        request.fields['folder'] = folder;
        
        // Lire les bytes du fichier web
        try {
          // Pour Flutter Web, on passe les bytes de l'image directement
          final bytes = await imageFile.readAsBytes();
          print('Taille du fichier: ${bytes.length} bytes');
          
          final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Créer une part multipart avec les bytes
          final multipartFile = http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: fileName,
            contentType: MediaType('image', 'jpeg')
          );
          
          request.files.add(multipartFile);
          
          // Envoyer la requête
          print('Envoi de la requête Web...');
          final streamedResponse = await request.send();
          print('Réponse reçue. Status: ${streamedResponse.statusCode}');
          
          final response = await http.Response.fromStream(streamedResponse);
          print('Contenu de la réponse: ${response.body}');
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            print('URL de l\'image reçue: ${data['imageUrl']}');
            return data['imageUrl'];
          } else {
            print('Erreur HTTP: ${response.statusCode}');
            return null;
          }
        } catch (e) {
          print('Erreur lors de la lecture du fichier web: $e');
          return null;
        }
      } else {
        // Si ce n'est pas le web, on utilise la méthode standard
        print('Utilisation de la méthode standard (non-web)');
        
        // Créer un multipart request
        var request = http.MultipartRequest(
          'POST', 
          Uri.parse('$baseUrl/upload')
        );
        
        // Ajouter l'autorisation
        if (token != null) {
          request.headers.addAll({
            'Authorization': 'Bearer $token',
          });
        }
        
        // Ajouter le fichier
        final fileBytes = await imageFile.readAsBytes();
        final fileName = imageFile.path.split('/').last;
        
        print('Taille du fichier: ${fileBytes.length} bytes, nom: $fileName');
        
        final multipartFile = http.MultipartFile.fromBytes(
          'image',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', fileName.split('.').last),
        );
        
        request.files.add(multipartFile);
        
        // Ajouter le dossier de destination
        request.fields['folder'] = folder;
        
        // Log pour debugging
        print('Headers de la requête: ${request.headers}');
        print('Champs de la requête: ${request.fields}');
        print('Fichiers attachés: ${request.files.length}');
        
        // Envoyer la requête
        print('Envoi de la requête...');
        var streamedResponse = await request.send();
        print('Réponse reçue. Status: ${streamedResponse.statusCode}');
        
        var response = await http.Response.fromStream(streamedResponse);
        print('Contenu de la réponse: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          print('URL de l\'image reçue: ${data['imageUrl']}');
          return data['imageUrl'];
        } else {
          print('Erreur lors de l\'upload de l\'image: [${response.statusCode}] ${response.body}');
          return null;
        }
      }
    } catch (e) {
      print('Exception lors de l\'upload de l\'image: $e');
      return null;
    }
  }

  // Récupérer uniquement les terrains (is_terrain=1)
  Future<List<Facility>> getTerrains() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('Token non trouvé, impossible de récupérer les terrains');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/facilities/terrains'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        print('Terrains récupérés: ${data.length}');
        return data.map((json) => Facility.fromJson(json)).toList();
      } else {
        print('Erreur lors de la récupération des terrains: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception lors de la récupération des terrains: $e');
      return [];
    }
  }

  // Récupérer tous les équipements disponibles
  Future<List<Equipment>> getAvailableEquipment() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('Token non trouvé, impossible de récupérer les équipements');
        return [];
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/equipment/available'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> equipmentJson = json.decode(response.body);
        return equipmentJson.map((json) => Equipment.fromJson(json)).toList();
      } else {
        print('Erreur lors de la récupération des équipements disponibles: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception lors de la récupération des équipements disponibles: $e');
      return [];
    }
  }

  // Récupérer tous les équipements disponibles pour les cours
  Future<List<Equipment>> getAvailableEquipmentForCourses() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('Token non trouvé, impossible de récupérer les équipements pour les cours');
        return [];
      }
      
      // Ajout d'un log pour débuggage
      print('Requête vers: $baseUrl/courses/equipment/available');
      
      final response = await http.get(
        Uri.parse('$baseUrl/courses/equipment/available'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      // Ajout d'un log pour débuggage
      print('Réponse: [${response.statusCode}] ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> equipmentJson = json.decode(response.body);
        return equipmentJson.map((json) => Equipment.fromJson(json)).toList();
      } else {
        print('Erreur lors de la récupération des équipements pour les cours: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception lors de la récupération des équipements pour les cours: $e');
      return [];
    }
  }
  
  // Récupérer tous les terrains disponibles pour les cours
  Future<List<Facility>> getAvailableTerrainsForCourses() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('Token non trouvé, impossible de récupérer les terrains pour les cours');
        return [];
      }
      
      // Ajout d'un log pour débuggage
      print('Requête vers: $baseUrl/courses/terrains/available');
      
      final response = await http.get(
        Uri.parse('$baseUrl/courses/terrains/available'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      // Ajout d'un log pour débuggage
      print('Réponse: [${response.statusCode}] ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> terrainsJson = json.decode(response.body);
        return terrainsJson.map((json) => Facility.fromJson(json)).toList();
      } else {
        print('Erreur lors de la récupération des terrains pour les cours: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception lors de la récupération des terrains pour les cours: $e');
      return [];
    }
  }

  // Créer une réservation avec DateTime au format ISO
  Future<Reservation> createReservationWithDateTime(Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/reservations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Reservation.fromJson(json);
      } else {
        print('Erreur lors de la création de la réservation: ${response.body}');
        throw Exception('Échec de la création de la réservation. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception lors de la création de la réservation: $e');
      throw Exception('Erreur lors de la création de la réservation: $e');
    }
  }
} 