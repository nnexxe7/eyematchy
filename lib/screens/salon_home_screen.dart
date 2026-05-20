import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class SalonHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SalonHomeScreen({super.key, required this.userData});

  @override
  State<SalonHomeScreen> createState() => _SalonHomeScreenState();
}

class _SalonHomeScreenState extends State<SalonHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _emailController = TextEditingController();

  // Kontrolery dla kreatora salonu
  final TextEditingController _salonNameController = TextEditingController();
  final TextEditingController _salonAddressController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _salonNameController.dispose();
    _salonAddressController.dispose();
    super.dispose();
  }

  // --- LOGIKA KREATORA SALONU ---
  Future<void> _createSalon() async {
    final name = _salonNameController.text.trim();
    final address = _salonAddressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isCreating = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final salonRef = FirebaseFirestore.instance.collection('salons').doc();
      final String generatedSalonId = salonRef.id;

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Tworzymy dokument salonu w nowej kolekcji
      batch.set(salonRef, {
        'salonId': generatedSalonId,
        'salonName': name,
        'address': address,
        'ownerId': user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'employees': [user.uid],
      });

      // 2. Aktualizujemy profil szefowej w kolekcji 'users'
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'salonId': generatedSalonId,
        'salonName': name,
        'salonRole': 'owner',
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salon został utworzony!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // --- WIDOK KREATORA SALONU ---
  Widget _buildSalonCreator() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text(
              'Stwórz profil swojego salonu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Podaj nazwę i adres, aby wygenerować unikalny identyfikator i zacząć zapraszać pracownice.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _salonNameController,
              decoration: InputDecoration(
                labelText: 'Nazwa Salonu',
                prefixIcon: const Icon(Icons.edit_note, color: Colors.deepPurple),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _salonAddressController,
              decoration: InputDecoration(
                labelText: 'Adres (ulica, miasto)',
                prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.deepPurple),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createSalon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Stwórz i przejdź do panelu', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDOK PICKERA DNI (STYL BOOKSY) ---
  Widget _buildDatePicker() {
    return Container(
      height: 90,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month &&
              date.year == _selectedDate.year;

          final daysOfWeek = ['Nie', 'Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob'];
          final dayName = daysOfWeek[date.weekday % 7];

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                  const SizedBox(height: 4),
                  Text(date.day.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- LOGIKA WYSYŁANIA ZAPROSZEŃ ---
  Future<void> _sendInvitation() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    final mySalonId = widget.userData['salonId'];
    final mySalonName = widget.userData['salonName'] ?? "Twój Salon";

    try {
      await FirebaseFirestore.instance.collection('invitations').add({
        'email': email,
        'salonId': mySalonId,
        'salonName': mySalonName,
        'roleInSalon': 'employee',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaproszenie wysłane pomyślnie!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd wysyłania: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sprawdzamy, czy użytkownik ma przypisany salon
    final bool hasSalon = widget.userData.containsKey('salonId') && widget.userData['salonId'] != null;

    if (!hasSalon) {
      return Scaffold(
        appBar: AppBar(title: const Text('Konfiguracja Salonu'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
        drawer: AppDrawer(userData: widget.userData, currentRole: 'salon'),
        body: _buildSalonCreator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userData['salonName'] ?? 'Panel Salonu'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: "Kalendarz"),
            Tab(icon: Icon(Icons.people), text: "Zespół")
          ],
        ),
      ),
      drawer: AppDrawer(userData: widget.userData, currentRole: 'salon'),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ZAKŁADKA 1: KALENDARZ
          Column(
            children: [
              _buildDatePicker(),
              Expanded(
                child: ListView.builder(
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final hour = index + 8;
                    return Container(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5))),
                      child: Row(
                        children: [
                          Container(width: 60, padding: const EdgeInsets.symmetric(vertical: 20), alignment: Alignment.center, child: Text("$hour:00")),
                          Expanded(child: Container(height: 60, color: index % 4 == 0 ? Colors.purple.withOpacity(0.05) : Colors.white)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ZAKŁADKA 2: DYNAMICZNY ZESPÓŁ
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.userData['salonRole'] == 'owner') ...[
                const Text("Zaproś nową stylistkę do zespołu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                                hintText: "Wpisz e-mail stylistki",
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                            )
                        )
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                        onPressed: _sendInvitation,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                        child: const Icon(Icons.send)
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ],
                const Text("Pracownicy salonu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // StreamBuilder pobierający z bazy osoby z tym samym salonId
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('salonId', isEqualTo: widget.userData['salonId'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text("Brak przypisanych pracowników.");
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final employee = snapshot.data!.docs[index].data() as Map<String, dynamic>;

                          final String firstName = employee['firstName'] ?? 'Nieznane';
                          final String lastName = employee['lastName'] ?? 'Imię';
                          final String email = employee['email'] ?? '';
                          final bool isOwner = employee['salonRole'] == 'owner';
                          final String roleTitle = isOwner ? 'Właściciel' : 'Stylistka';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: isOwner ? Colors.deepPurple : Colors.purple[300],
                                child: Icon(isOwner ? Icons.star : Icons.person, color: Colors.white)
                            ),
                            title: Text("$firstName $lastName"),
                            subtitle: Text(email),
                            trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isOwner ? Colors.green : Colors.blue,
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: Text(
                                    roleTitle,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                )
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}