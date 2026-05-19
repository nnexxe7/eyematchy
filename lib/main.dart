import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // POPRAWIONY IMPORT
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeMatchy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFFAFAFA),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
            );
          }

          if (snapshot.hasData) {
            final user = snapshot.data!;
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, docSnapshot) {
                if (docSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
                  );
                }

                if (docSnapshot.hasData && docSnapshot.data!.exists) {
                  final data = docSnapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null && data['profileSetupComplete'] == true) {
                    if (data['currentView'] == 'salon') {
                      return SalonHomeScreen(userData: data);
                    }
                    return HomeScreen(userData: data);
                  }
                }
                return const SetupProfileScreen();
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String currentRole;

  const AppDrawer({super.key, required final this.userData, required final this.currentRole});

  Future<void> _toggleView(BuildContext context, String targetView) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pop(context);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'currentView': targetView,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = List<String>.from(userData['roles'] ?? []);
    final hasBothRoles = roles.contains('client') && roles.contains('salon');

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple), // POPRAWIONE TŁO
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
            ),
            accountName: Text('${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'),
            accountEmail: Text(userData['email'] ?? ''),
          ),
          if (hasBothRoles) ...[
            if (currentRole == 'salon')
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.deepPurple),
                title: const Text('Przełącz na profil Klientki'),
                onTap: () => _toggleView(context, 'client'),
              )
            else
              ListTile(
                leading: const Icon(Icons.content_cut_outlined, color: Colors.deepPurple),
                title: const Text('Przełącz na panel Stylistki'),
                onTap: () => _toggleView(context, 'salon'),
              ),
            const Divider(),
          ],
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Wyloguj się', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class SalonHomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const SalonHomeScreen({super.key, required final this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Stylistki'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(userData: userData, currentRole: 'salon'),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 80, color: Colors.deepPurple),
              SizedBox(height: 24),
              Text(
                'Witaj w panelu salonu!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Użyj menu bocznego, aby zmienić profil.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}