import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import './admin_users_screen.dart';
import './admin_courses_screen.dart';
import './admin_equipment_screen.dart';
import './admin_facilities_screen.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final bool showAddButton;

  const AdminLayout({
    Key? key,
    required this.child,
    required this.title,
    this.showAddButton = true,
  }) : super(key: key);

  @override
  _AdminLayoutState createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = true;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });

      // Rediriger vers l'écran de connexion si l'utilisateur n'est pas connecté ou n'est pas admin
      if (user == null || user.role != 'admin') {
        Future.delayed(Duration.zero, () {
          Navigator.of(context).pushReplacementNamed('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Accès réservé aux administrateurs'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
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

    if (_currentUser == null || _currentUser!.role != 'admin') {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Accès non autorisé',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vous devez être administrateur pour accéder à cette page',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/reservations'),
                child: Text('Retour à l\'application'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3C64F4),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.dashboard),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/admin');
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _apiService.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                _currentUser?.username ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _currentUser?.email ?? '',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Color(0xFF3C64F4),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              decoration: BoxDecoration(
                color: Color(0xFF111111),
              ),
            ),
            ListTile(
              leading: Icon(Icons.people, color: Colors.blue),
              title: Text('Utilisateurs', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminUsersScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.fitness_center, color: Colors.green),
              title: Text('Cours', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminCoursesScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.sports_basketball, color: Colors.purple),
              title: Text('Équipements', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminEquipmentScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.stadium, color: Colors.orange),
              title: Text('Terrains', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminFacilitiesScreen()));
              },
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red),
              title: Text('Déconnexion', style: TextStyle(color: Colors.white)),
              onTap: () async {
                await _apiService.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
      body: widget.child,
      floatingActionButton: widget.showAddButton ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen) ...[
            _buildMiniFloatingActionButton(
              'Ajouter un utilisateur',
              Icons.person_add,
              Colors.blue,
              () {
                _toggleMenu();
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminUsersScreen(initiallyAddUser: true)));
              },
            ),
            SizedBox(height: 8),
            _buildMiniFloatingActionButton(
              'Ajouter un cours',
              Icons.fitness_center,
              Colors.green,
              () {
                _toggleMenu();
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminCoursesScreen(initiallyAddCourse: true)));
              },
            ),
            SizedBox(height: 8),
            _buildMiniFloatingActionButton(
              'Ajouter un équipement',
              Icons.sports_basketball,
              Colors.purple,
              () {
                _toggleMenu();
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminEquipmentScreen(initiallyAddEquipment: true)));
              },
            ),
            SizedBox(height: 8),
            _buildMiniFloatingActionButton(
              'Ajouter un terrain',
              Icons.stadium,
              Colors.orange,
              () {
                _toggleMenu();
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdminFacilitiesScreen(initiallyAddFacility: true)));
              },
            ),
            SizedBox(height: 16),
          ],
          FloatingActionButton(
            backgroundColor: Color(0xFF3C64F4),
            onPressed: _toggleMenu,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return RotationTransition(turns: animation, child: child);
              },
              child: _isMenuOpen 
                  ? Icon(Icons.close, key: ValueKey('close'))
                  : Icon(Icons.add, key: ValueKey('add')),
            ),
          ),
        ],
      ) : null,
    );
  }

  Widget _buildMiniFloatingActionButton(
    String tooltip,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tooltip,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 8),
        FloatingActionButton.small(
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon),
          tooltip: tooltip,
        ),
      ],
    );
  }
} 