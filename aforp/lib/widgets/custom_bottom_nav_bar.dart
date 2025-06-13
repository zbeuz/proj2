import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Color(0xFF3C64F4),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Cours',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sports_basketball),
          label: 'Équipements',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.stadium),
          label: 'Terrains',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Réservations',
        ),
      ],
    );
  }
} 