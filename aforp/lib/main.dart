import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reservations_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/facilities_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_courses_screen.dart';
import 'screens/admin/admin_equipment_screen.dart';
import 'screens/admin/admin_facilities_screen.dart';
import 'services/api_service.dart';
import 'models/user.dart';

void main() {
  runApp(MyApp());
}

// Widget simple pour l'écran de chargement
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AAFORP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Color(0xFF3C64F4),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'AAFORP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF3C64F4),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3C64F4),
          secondary: Color(0xFF32D74B),
          surface: Color(0xFF1E1E1E),
          background: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3C64F4), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3C64F4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            textStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/reservations': (context) => const ReservationsScreen(),
        '/courses': (context) => const CoursesScreen(),
        '/equipment': (context) => const EquipmentScreen(),
        '/facilities': (context) => const FacilitiesScreen(),
        '/admin/users': (context) => const AdminUsersScreen(),
        '/admin/courses': (context) => const AdminCoursesScreen(),
        '/admin/equipment': (context) => const AdminEquipmentScreen(),
        '/admin/facilities': (context) => const AdminFacilitiesScreen(),
      },
      onGenerateRoute: (settings) {
        // Vérifier si l'utilisateur est connecté pour les routes protégées
        if (settings.name != '/login' && settings.name != '/register') {
          // Retourner un Route<dynamic>
          return MaterialPageRoute(
            builder: (context) {
              return FutureBuilder<User?>(
                future: _apiService.getCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingScreen();
                  } else if (snapshot.hasError || snapshot.data == null) {
                    // Rediriger vers la page de connexion si l'utilisateur n'est pas connecté
                    Timer(Duration.zero, () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    });
                    return const LoadingScreen();
                  } else {
                    // L'utilisateur est connecté, déterminer où le rediriger en fonction de son rôle
                    final isAdmin = snapshot.data!.role == 'admin';
                    
                    // Définir la route par défaut en fonction du rôle
                    if (settings.name == '/') {
                      if (isAdmin) {
                        // Rediriger l'admin vers la page admin principale
                        Timer(Duration.zero, () {
                          Navigator.of(context).pushReplacementNamed('/admin/users');
                        });
                        return const LoadingScreen();
                      } else {
                        // Rediriger l'utilisateur vers la page de réservations
                        Timer(Duration.zero, () {
                          Navigator.of(context).pushReplacementNamed('/reservations');
                        });
                        return const LoadingScreen();
                      }
                    }
                    
                    // Choisir la page en fonction de la route demandée et du rôle
                    Widget page;
                    
                    if (isAdmin) {
                      // Routes admin
                      switch (settings.name) {
                        case '/admin/users':
                          page = const AdminUsersScreen();
                          break;
                        case '/admin/courses':
                          page = const AdminCoursesScreen();
                          break;
                        case '/admin/equipment':
                          page = const AdminEquipmentScreen();
                          break;
                        case '/admin/facilities':
                          page = const AdminFacilitiesScreen();
                          break;
                        case '/reservations':
                        case '/courses':
                        case '/equipment':
                        case '/facilities':
                          // Rediriger vers la page admin correspondante si un admin essaie d'accéder aux pages utilisateur
                          Timer(Duration.zero, () {
                            Navigator.of(context).pushReplacementNamed('/admin/users');
                          });
                          return const LoadingScreen();
                        default:
                          page = const AdminUsersScreen();
                      }
                    } else {
                      // Routes utilisateur
                      switch (settings.name) {
                        case '/reservations':
                          page = const ReservationsScreen();
                          break;
                        case '/courses':
                          page = const CoursesScreen();
                          break;
                        case '/equipment':
                          page = const EquipmentScreen();
                          break;
                        case '/facilities':
                          page = const FacilitiesScreen();
                          break;
                        case '/admin/users':
                        case '/admin/courses':
                        case '/admin/equipment':
                        case '/admin/facilities':
                          // Rediriger vers la page utilisateur si un utilisateur essaie d'accéder aux pages admin
                          Timer(Duration.zero, () {
                            Navigator.of(context).pushReplacementNamed('/reservations');
                          });
                          return const LoadingScreen();
                        default:
                          page = const ReservationsScreen();
                      }
                    }
                    
                    return page;
                  }
                },
              );
            },
          );
        }
        return null;
      },
      initialRoute: '/login',
    );
  }
}
