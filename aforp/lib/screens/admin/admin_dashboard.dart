import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import './admin_users_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAdmin = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer l'utilisateur actuel
      _currentUser = await _apiService.getCurrentUser();
      
      // Vérifier si l'utilisateur est un administrateur
      if (_currentUser != null && _currentUser!.role == 'admin') {
        setState(() {
          _isAdmin = true;
          _isLoading = false;
        });

        // Rediriger vers la page de gestion des utilisateurs
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AdminUsersScreen())
          );
        });
      } else {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification du statut d\'administrateur: ${e.toString()}');
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3C64F4),
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text('Accès non autorisé'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/reservations');
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 80,
              ),
              SizedBox(height: 20),
              Text(
                'Accès non autorisé',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Vous n\'avez pas les droits d\'administrateur pour accéder à cette page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/reservations');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3C64F4),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Retour à l\'accueil',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Ce code ne devrait jamais être exécuté car nous redirigeons dans initState
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3C64F4),
        ),
      ),
    );
  }
} 