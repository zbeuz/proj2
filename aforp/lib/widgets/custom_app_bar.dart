import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int selectedIndex;
  final Function(int) onTap;
  final bool isHome;
  
  CustomAppBar({
    Key? key,
    required this.title,
    required this.selectedIndex,
    required this.onTap,
    this.isHome = false,
  }) : super(key: key);
  
  // Déterminer si c'est une version desktop
  bool get isDesktop => kIsWeb || !(Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopNavBar(context);
    } else {
      return _buildMobileAppBar(context);
    }
  }
  
  Widget _buildDesktopNavBar(BuildContext context) {
    return Container(
      color: Color(0xFF1E1E1E),
      height: kToolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Text(
              'AAFORP SPORTS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 40),
            _buildNavItem(0, 'Accueil', Icons.home),
            _buildNavItem(1, 'Cours', Icons.fitness_center),
            _buildNavItem(2, 'Équipements', Icons.sports_basketball),
            _buildNavItem(3, 'Terrains', Icons.stadium),
            _buildNavItem(4, 'Réservations', Icons.calendar_today),
            Spacer(),
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Notifications en développement'),
                    backgroundColor: Color(0xFF3C64F4),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              onPressed: () {
                // Navigator.pushNamed(context, '/profile');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                _logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.black,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Notifications en développement'),
                backgroundColor: Color(0xFF3C64F4),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () {
            // Navigator.pushNamed(context, '/profile');
          },
        ),
      ],
    );
  }
  
  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = index == selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextButton.icon(
        onPressed: () => onTap(index),
        icon: Icon(
          icon,
          color: isSelected ? Color(0xFF3C64F4) : Colors.white,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Color(0xFF3C64F4) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        ),
      ),
    );
  }
  
  void _logout(BuildContext context) async {
    // Afficher une boîte de dialogue de confirmation
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'Déconnexion',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3C64F4),
            ),
            child: Text('Déconnexion'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
} 