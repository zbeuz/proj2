import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../services/api_service.dart';
import '../models/user.dart';

class BaseScreen extends StatefulWidget {
  final Widget body;
  final String title;
  final int currentIndex;
  final bool isAdminMode;

  const BaseScreen({
    Key? key,
    required this.body,
    required this.title,
    required this.currentIndex,
    this.isAdminMode = false,
  }) : super(key: key);

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isAdmin = false;
  
  // Déterminer si c'est une version desktop
  bool get isDesktop => kIsWeb || !(Platform.isAndroid || Platform.isIOS);
  
  // Routes pour la navigation utilisateur standard
  final List<String> _userRoutes = [
    '/reservations',
    '/courses',
    '/equipment',
    '/facilities',
  ];
  
  // Routes pour la navigation admin
  final List<String> _adminRoutes = [
    '/admin/users',
    '/admin/courses',
    '/admin/equipment',
    '/admin/facilities',
  ];
  
  // Obtenir les routes selon le mode
  List<String> get _routes => widget.isAdminMode ? _adminRoutes : _userRoutes;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isAdmin = user?.role == 'admin';
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'utilisateur: $e');
    }
  }

  void _onNavItemTapped(int index) {
    if (index == widget.currentIndex) return;
    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isDesktop ? null : _buildMobileAppBar(),
      drawer: !isDesktop ? _buildDrawer() : null,
      body: Stack(
        children: [
          // Background patterns
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3C64F4).withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3C64F4).withOpacity(0.04),
              ),
            ),
          ),
          
          // Main content
          isDesktop
              ? _buildDesktopLayout()
              : widget.body,
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNavigationBar(),
    );
  }

  AppBar _buildMobileAppBar() {
    return AppBar(
      title: Text(
        widget.title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications en développement'),
                backgroundColor: Color(0xFF3C64F4),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF3C64F4),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        items: widget.isAdminMode ? _buildAdminNavigationItems() : _buildUserNavigationItems(),
      ),
    );
  }
  
  List<BottomNavigationBarItem> _buildUserNavigationItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        activeIcon: Icon(Icons.calendar_today, size: 28),
        label: 'Réservations',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center),
        activeIcon: Icon(Icons.fitness_center, size: 28),
        label: 'Cours',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.sports_basketball),
        activeIcon: Icon(Icons.sports_basketball, size: 28),
        label: 'Équipements',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.stadium),
        activeIcon: Icon(Icons.stadium, size: 28),
        label: 'Terrains',
      ),
    ];
  }
  
  List<BottomNavigationBarItem> _buildAdminNavigationItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.people),
        activeIcon: Icon(Icons.people, size: 28),
        label: 'Utilisateurs',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center),
        activeIcon: Icon(Icons.fitness_center, size: 28),
        label: 'Cours',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.sports_basketball),
        activeIcon: Icon(Icons.sports_basketball, size: 28),
        label: 'Équipements',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.stadium),
        activeIcon: Icon(Icons.stadium, size: 28),
        label: 'Terrains',
      ),
    ];
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildDesktopNavBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSidebar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: widget.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF121212),
      height: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF3C64F4).withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF3C64F4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.username ?? 'Utilisateur',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isAdmin ? 'Administrateur' : 'Membre',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isAdmin ? const Color(0xFF3C64F4) : Colors.grey,
                          fontWeight: _isAdmin ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSidebarItem(0, 'Réservations', Icons.calendar_today),
          _buildSidebarItem(1, 'Cours', Icons.fitness_center),
          _buildSidebarItem(2, 'Équipements', Icons.sports_basketball),
          _buildSidebarItem(3, 'Terrains', Icons.stadium),
          if (_isAdmin) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.grey),
            const SizedBox(height: 8),
            _buildAdminButton(),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: const Icon(
          Icons.admin_panel_settings,
          color: Color(0xFF3C64F4),
        ),
        title: const Text(
          'Panel Admin',
          style: TextStyle(
            color: Color(0xFF3C64F4),
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3C64F4), width: 1),
        ),
        tileColor: const Color(0xFF3C64F4).withOpacity(0.1),
        onTap: () {
          Navigator.pushNamed(context, '/admin');
        },
      ),
    );
  }

  Widget _buildSidebarItem(int index, String label, IconData icon) {
    final isSelected = index == widget.currentIndex;
    
    // Si on est en mode admin, on remplace "Réservations" par "Utilisateurs" pour l'index 0
    if (widget.isAdminMode && index == 0) {
      label = 'Utilisateurs';
      icon = Icons.people;
    }
    
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3C64F4).withOpacity(0.15) : Colors.transparent,
          border: isSelected
              ? const Border(
                  left: BorderSide(
                    color: Color(0xFF3C64F4),
                    width: 4,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3C64F4) : Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3C64F4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3C64F4).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.sports,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'AAFORP SPORTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          if (_isAdmin)
            TextButton.icon(
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF3C64F4)),
              label: const Text(
                'Admin',
                style: TextStyle(
                  color: Color(0xFF3C64F4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3C64F4).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin');
              },
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(width: 16),
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {},
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF3C64F4).withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF3C64F4),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentUser?.username ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F0F),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3C64F4),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3C64F4).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'AAFORP SPORTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF3C64F4).withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF3C64F4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser?.username ?? 'Utilisateur',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _isAdmin ? 'Administrateur' : 'Membre',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isAdmin ? const Color(0xFF3C64F4) : Colors.grey,
                              fontWeight: _isAdmin ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildDrawerItem(0, 'Réservations', Icons.calendar_today),
          _buildDrawerItem(1, 'Cours', Icons.fitness_center),
          _buildDrawerItem(2, 'Équipements', Icons.sports_basketball),
          _buildDrawerItem(3, 'Terrains', Icons.stadium),
          if (_isAdmin) ...[
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF3C64F4)),
              title: const Text(
                'Panel Admin',
                style: TextStyle(
                  color: Color(0xFF3C64F4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin');
              },
            ),
          ],
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, String label, IconData icon) {
    final isSelected = index == widget.currentIndex;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF3C64F4) : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF3C64F4).withOpacity(0.15),
      onTap: () {
        Navigator.pop(context);
        _onNavItemTapped(index);
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Êtes-vous sûr de vouloir vous déconnecter ?',
              style: TextStyle(color: Colors.grey),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C64F4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Déconnexion'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _apiService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
} 