import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/custom_card.dart';
import '../services/api_service.dart';
import 'courses_screen.dart';
import 'equipment_screen.dart';
import 'reservations_screen.dart';
import 'facilities_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final String username = "Alexandre";
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Déterminer si c'est une version desktop
  bool get isDesktop => kIsWeb || !(Platform.isAndroid || Platform.isIOS);
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style for status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPatternPainter(),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 30),
                  // Welcome message
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Bienvenue $username, 👋',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Accédez à toutes les fonctionnalités du campus',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Main menu
                  Expanded(
                    child: _buildGridMenu(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 35,
            color: Colors.white,
          ),
          Row(
            children: [
              _buildIconButton(Icons.notifications_outlined, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications')),
                );
              }),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C64F4),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3C64F4).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildGridMenu() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          CustomCard(
            title: 'Cours',
            icon: Icons.fitness_center,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CoursesScreen()),
              );
            },
          ),
          CustomCard(
            title: 'Équipements',
            icon: Icons.sports_basketball,
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EquipmentScreen()),
              );
            },
          ),
          CustomCard(
            title: 'Terrains',
            icon: Icons.stadium,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FacilitiesScreen()),
              );
            },
          ),
          CustomCard(
            title: 'Réservations',
            icon: Icons.calendar_today,
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReservationsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3C64F4).withOpacity(0.07)
      ..style = PaintingStyle.fill;

    // Draw large circle in top right
    canvas.drawCircle(Offset(size.width + 20, -20), 200, paint);
    
    // Draw medium circle in bottom left
    canvas.drawCircle(Offset(-50, size.height - 50), 120, paint);
    
    // Draw small circle in center right
    canvas.drawCircle(Offset(size.width - 30, size.height * 0.6), 80, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 