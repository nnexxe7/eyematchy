import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🚀 IMPORT POWIADOMIEŃ
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🚀 IMPORT LOKALNYCH POWIADOMIEŃ

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:eyematchy/screens/setup_profile_screen.dart';
import 'screens/salon_home_screen.dart';
import 'screens/invitations_screen.dart';
import 'screens/salon_settings_screen.dart';
import 'screens/client_home_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/eye_match_screen.dart';
import 'screens/client_appointments_screen.dart';
import 'screens/verify_email_screen.dart';

// 🚀 ZMIENNA GLOBALNA DLA POWIADOMIEŃ LOKALNYCH
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 🚀 FUNKCJA OBSŁUGUJĄCA POWIADOMIENIA W TLE (musi być poza klasami)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Odebrano powiadomienie w tle: ${message.messageId}");
}

// 🚀 INICJALIZACJA POWIADOMIEŃ LOKALNYCH
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  // 🚀 ZMIANA: Dodano słówko "settings:"
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await initLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // 🚀 ZMIANA: Wszystkie parametry mają teraz swoje nazwy
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      flutterLocalNotificationsPlugin.show(
        id: message.hashCode,
        title: message.notification!.title,
        body: message.notification!.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

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
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
            );
          }

          if (snapshot.hasData) {
            final user = snapshot.data!;

            if (!user.emailVerified) {
              return const VerifyEmailScreen();
            }

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
                    return ClientHomeScreen(userData: data);
                  }
                }
                return SetupProfileScreen();
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

  const AppDrawer({super.key, required this.userData, required this.currentRole});

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
    final bool isOwner = currentRole == 'salon' && userData['salonRole'] == 'owner';

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(color: Colors.deepPurple),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
              ),
              accountName: Text('${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'),
              accountEmail: Text(userData['email'] ?? ''),
            ),

            if (currentRole == 'salon') ...[
              ListTile(
                leading: const Icon(Icons.remove_red_eye, color: Colors.deepPurple),
                title: const Text('EyeMatch AI', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Analiza kształtu oczu i dobór rzęs', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EyeMatchScreen()),
                  );
                },
              ),
              const Divider(height: 1),
            ],

            if (currentRole == 'client') ...[
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.pinkAccent),
                title: const Text('Moje zaplanowane wizyty', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Sprawdź swoje rezerwacje w salonach', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClientAppointmentsScreen(userData: userData)),
                  );
                },
              ),
              const Divider(height: 1),
            ],

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
            ] else ...[
              if (currentRole == 'client') ...[
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('invitations')
                      .where('email', isEqualTo: userData['email'])
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      leading: const Icon(Icons.mail_outline, color: Colors.deepPurple),
                      title: const Text('Zaproszenia do pracy', style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${snapshot.data!.docs.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvitationsScreen(userData: userData),
                          ),
                        );
                      },
                    );
                  },
                ),

                // 🚀 NOWE: Przycisk zakładania salonu dla klientek
                ListTile(
                  leading: const Icon(Icons.storefront_outlined, color: Colors.deepPurple),
                  title: const Text('Załóż własny salon', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Zacznij zarządzać swoim biznesem', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(context);
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // Dodajemy rolę 'salon' do tablicy ról i przełączamy widok
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                        'roles': FieldValue.arrayUnion(['salon']),
                        'currentView': 'salon',
                      });
                    }
                  },
                ),
              ],
            ],

            const Spacer(),
            const Divider(height: 1),

            if (isOwner)
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: Colors.black87),
                title: const Text('Ustawienia Salonu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SalonSettingsScreen(userData: userData),
                    ),
                  );
                },
              ),

            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: Colors.black87),
              title: const Text('Ustawienia profilu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(userData: userData),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Wyloguj się', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}