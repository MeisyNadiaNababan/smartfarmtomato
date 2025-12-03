// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'auth/home_screen.dart';
import 'navigation/admin_navigation.dart';
import 'navigation/farmer_navigation.dart';
import 'app_user.dart';
import 'core/firebase_options.dart';
import 'providers/theme_provider.dart'; // Import yang benar

bool _isInitialized = false;

void main() {
  print('🚀 Starting TomaFarm App...');
  
  if (_isInitialized) {
    print('⚠️ App already initialized, ignoring duplicate call');
    return;
  }
  _isInitialized = true;
  
  runApp(const TomaFarmApp());
}

class TomaFarmApp extends StatefulWidget {
  const TomaFarmApp({super.key});

  @override
  State<TomaFarmApp> createState() => _TomaFarmAppState();
}

class _TomaFarmAppState extends State<TomaFarmApp> {
  late Future<FirebaseApp> _firebaseInitialization;

  @override
  void initState() {
    super.initState();
    _firebaseInitialization = _initializeFirebase();
  }

  Future<FirebaseApp> _initializeFirebase() async {
    try {
      print('🔥 Initializing Firebase...');
      
      try {
        final existingApp = Firebase.app();
        print('✅ Using existing Firebase app: ${existingApp.name}');
        return existingApp;
      } catch (e) {
        print('🆕 Creating new Firebase app...');
        final app = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase initialized successfully!');
        return app;
      }
    } catch (e) {
      print('❌ Firebase initialization failed: $e');

      if (e.toString().contains('duplicate-app') || e.toString().contains('[DEFAULT]')) {
        print('⚠️ Firebase app already exists, using existing instance');
        return Firebase.app();
      }
      
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInitialLoadingScreen();
        }

        if (snapshot.hasError) {
          print('❌ Firebase error in FutureBuilder: ${snapshot.error}');
          return ErrorApp(error: snapshot.error.toString());
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => ThemeProvider()),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'TomaFarm',
                theme: themeProvider.currentTheme,
                darkTheme: ThemeProvider.darkTheme,
                themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                home: const AuthWrapper(),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInitialLoadingScreen() {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.agriculture,
                  size: 50,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'TomaFarm',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Initializing app...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        print('✅ User already signed in: ${user.email}');
        _currentUser = user;
        
        try {
          final userData = await AppUser.getUserRole(user.uid)
              .timeout(const Duration(seconds: 3));
          
          setState(() {
            _userData = userData;
            _isCheckingAuth = false;
          });
        } catch (e) {
          print('⚠️ User data load timeout, using default');
          final fallbackData = {
            'email': user.email,
            'role': 'farmer',
            'displayName': user.email?.split('@').first ?? 'User',
          };
          setState(() {
            _userData = fallbackData;
            _isCheckingAuth = false;
          });
        }
      } else {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      print('❌ Error checking auth: $e');
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return _buildQuickLoadingScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildQuickLoadingScreen();
        }

        if (snapshot.hasError) {
          print('❌ Auth stream error: ${snapshot.error}');
          return const HomeScreen();
        }

        final user = snapshot.data;
        
        if (user == null) {
          print('🚪 No user, redirecting to HomeScreen');
          return const HomeScreen();
        }
        
        print('✅ User authenticated: ${user.email}');
        
        if (_userData != null && _currentUser?.uid == user.uid) {
          print('🎭 Using cached user role: ${_userData!['role']}');
          return _buildNavigationByRole(_userData!);
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: AppUser.getUserRole(user.uid)
              .timeout(const Duration(seconds: 2)),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return _buildQuickLoadingScreen();
            }
            
            if (roleSnapshot.hasError) {
              print('❌ Role error, default to farmer: ${roleSnapshot.error}');
              final fallbackData = {
                'email': user.email,
                'role': 'farmer',
                'displayName': user.email?.split('@').first ?? 'User',
              };
              return _buildNavigationByRole(fallbackData);
            }
            
            final userData = roleSnapshot.data!;
            
            print('📊 User data: $userData');
            print('🎭 User role: ${userData['role']}');
            
            return _buildNavigationByRole(userData);
          },
        );
      },
    );
  }

  Widget _buildNavigationByRole(Map<String, dynamic> userData) {
    final isAdmin = userData['role'] == 'admin';
    print('🚀 Navigating to: ${isAdmin ? 'ADMIN' : 'FARMER'} dashboard');
    
    if (isAdmin) {
      return const AdminNavigation();
    } else {
      return const FarmerNavigation();
    }
  }

  Widget _buildQuickLoadingScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _getErrorMessage(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _isInitialized = false;
                    runApp(const TomaFarmApp());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    _isInitialized = false;
                    runApp(MaterialApp(
                      home: const HomeScreen(),
                      debugShowCheckedModeBanner: false,
                    ));
                  },
                  child: const Text('Continue to App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('duplicate-app') || error.contains('[DEFAULT]')) {
      return 'Firebase is already initialized. The app will continue normally.';
    } else if (error.contains('network') || error.contains('SocketException')) {
      return 'Network connection issue. Please check your internet connection.';
    } else if (error.contains('permission') || error.contains('403')) {
      return 'Firebase permission denied. Please contact support.';
    }
    return error.length > 150 ? '${error.substring(0, 150)}...' : error;
  }
}