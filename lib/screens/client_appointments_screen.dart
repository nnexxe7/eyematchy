import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientAppointmentsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ClientAppointmentsScreen({super.key, required this.userData});

  @override
  State<ClientAppointmentsScreen> createState() => _ClientAppointmentsScreenState();
}

class _ClientAppointmentsScreenState extends State<ClientAppointmentsScreen> {

  // --- LOGIKA POMOCNICZA: Parsowanie daty i czasu do obiektu DateTime ---
  DateTime _parseDateTime(String date, String time) {
    try {
      final dateParts = date.split('-');
      final timeParts = time.split(':');
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (e) {
      return DateTime(2000);
    }
  }

  // --- 🔴 ODWOŁANIE WIZYTY ---
  Future<void> _cancelAppointment(String appointmentId, String serviceName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Odwołanie wizyty'),
          ],
        ),
        content: Text('Czy na pewno chcesz odwołać wizytę: "$serviceName"?\nTej operacji nie można cofnąć.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nie, wróć')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Tak, odwołaj'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wizyta została pomyślnie odwołana.'), backgroundColor: Colors.black87),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd odwoływania wizyty: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- 📅 ZMIANA TERMINU WIZYTY (WYŚWIETLENIE MODALA Z WYBOREM) ---
  void _rescheduleAppointment(String appointmentId, Map<String, dynamic> appointmentData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RescheduleBottomSheet(
        appointmentId: appointmentId,
        appointmentData: appointmentData,
      ),
    );
  }

  // --- KOMPONENT WIDOKU: Budowa listy dla konkretnej zakładki ---
  Widget _buildAppointmentsList(List<QueryDocumentSnapshot> docs, String emptyMessage, bool isUpcoming) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final appointmentId = doc.id;
        final appointment = doc.data() as Map<String, dynamic>;

        final String salonName = appointment['salonName'] ?? 'Nieznany Salon';
        final String serviceName = appointment['serviceName'] ?? 'Usługa';
        final String employeeId = appointment['employeeId'] ?? '';
        final String fallbackEmployeeName = appointment['employeeName'] ?? 'Stylistka';
        final String date = appointment['date'] ?? '';
        final String time = appointment['time'] ?? '';
        final double price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
        final int duration = appointment['duration'] ?? 30;

        String displayDate = date;
        try {
          final parts = date.split('-');
          if (parts.length == 3) {
            displayDate = "${parts[2]}.${parts[1]}.${parts[0]}";
          }
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        salonName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${price.toStringAsFixed(2)} zł',
                        style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  serviceName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.deepPurple),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('$time ($duration min)', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(width: 20),
                    Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(displayDate, style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),

                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(employeeId).get(),
                  builder: (context, empSnapshot) {
                    String finalEmployeeName = fallbackEmployeeName;

                    if (empSnapshot.hasData && empSnapshot.data!.exists) {
                      final empData = empSnapshot.data!.data() as Map<String, dynamic>;
                      final String firstName = empData['firstName'] ?? fallbackEmployeeName;
                      final String lastName = empData['lastName'] ?? '';
                      finalEmployeeName = lastName.isNotEmpty ? "$firstName $lastName" : firstName;
                    }

                    return Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text('Stylistka: $finalEmployeeName', style: TextStyle(color: Colors.grey[700])),
                      ],
                    );
                  },
                ),

                // 🚀 AKCJE DLA NADCHODZĄCYCH WIZYT
                if (isUpcoming) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _cancelAppointment(appointmentId, serviceName),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Odwołaj'),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _rescheduleAppointment(appointmentId, appointment),
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: const Text('Zmień termin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Użytkownik niezalogowany.')));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moje Wizyty'),
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: "Nadchodzące"),
              Tab(text: "Historia"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('clientId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Błąd pobierania danych:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              );
            }

            final List<QueryDocumentSnapshot> docs = snapshot.data?.docs.toList() ?? [];

            docs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;

              int dateComparison = (dataA['date'] ?? '').compareTo(dataB['date'] ?? '');
              if (dateComparison == 0) {
                return (dataA['time'] ?? '').compareTo(dataB['time'] ?? '');
              }
              return dateComparison;
            });

            final DateTime now = DateTime.now();
            List<QueryDocumentSnapshot> upcomingAppointments = [];
            List<QueryDocumentSnapshot> pastAppointments = [];

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final DateTime appointmentTime = _parseDateTime(data['date'] ?? '', data['time'] ?? '');

              if (appointmentTime.isBefore(now)) {
                pastAppointments.add(doc);
              } else {
                upcomingAppointments.add(doc);
              }
            }

            pastAppointments = pastAppointments.reversed.toList();

            return TabBarView(
              children: [
                _buildAppointmentsList(upcomingAppointments, 'Nie masz jeszcze zaplanowanych wizyt.', true),
                _buildAppointmentsList(pastAppointments, 'Brak historii wizyt.', false),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// KOMPONENT ZMIANY TERMINU (WYBÓR NOWEJ DATY I GODZINY Z WALIDACJĄ SALONU)
// ============================================================================
class _RescheduleBottomSheet extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const _RescheduleBottomSheet({required this.appointmentId, required this.appointmentData});

  @override
  State<_RescheduleBottomSheet> createState() => _RescheduleBottomSheetState();
}

class _RescheduleBottomSheetState extends State<_RescheduleBottomSheet> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      final parts = (widget.appointmentData['date'] as String).split('-');
      _selectedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {}
  }

  Future<void> _updateAppointmentTime() async {
    if (_selectedTime == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String salonId = widget.appointmentData['salonId'];
      final String employeeId = widget.appointmentData['employeeId'];
      final int duration = widget.appointmentData['duration'];
      final String formattedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      // 1. Walidacja godzin zamknięcia salonu
      List<String> newTimeParts = _selectedTime!.split(':');
      int newStartMin = (int.tryParse(newTimeParts[0]) ?? 0) * 60 + (int.tryParse(newTimeParts[1]) ?? 0);
      int newEndMin = newStartMin + duration;

      final salonDoc = await FirebaseFirestore.instance.collection('salons').doc(salonId).get();
      if (salonDoc.exists) {
        final salonData = salonDoc.data() as Map<String, dynamic>;
        final openingHours = salonData['openingHours'] ?? {};
        final daysMapping = {1: '1_pon', 2: '2_wt', 3: '3_sr', 4: '4_czw', 5: '5_pt', 6: '6_sob', 7: '7_nd'};
        String currentDayKey = daysMapping[_selectedDate.weekday] ?? '1_pon';
        Map<String, dynamic> dayConfig = openingHours[currentDayKey] ?? {};

        bool isClosed = dayConfig['1_closed'] ?? false;
        if (!isClosed) {
          List<String> closeParts = (dayConfig['3_close'] ?? '16:00').split(':');
          int closeInMinutes = (int.tryParse(closeParts[0]) ?? 16) * 60 + (int.tryParse(closeParts[1]) ?? 0);

          if (newEndMin > closeInMinutes) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Zabieg jest za długi i wykracza poza godziny otwarcia.';
              });
            }
            return;
          }
        }
      }

      // 2. Walidacja kolizji z innymi wizytami
      final existingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('salonId', isEqualTo: salonId)
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isEqualTo: formattedDateStr)
          .get();

      bool hasOverlap = false;
      for (var doc in existingAppointments.docs) {
        if (doc.id == widget.appointmentId) continue;

        final data = doc.data();
        List<String> appTimeParts = (data['time'] ?? '00:00').split(':');
        int appStartMin = (int.tryParse(appTimeParts[0]) ?? 0) * 60 + (int.tryParse(appTimeParts[1]) ?? 0);
        int appDuration = data['duration'] ?? 30;
        int appEndMin = appStartMin + appDuration;

        if (newStartMin < appEndMin && newEndMin > appStartMin) {
          hasOverlap = true;
          break;
        }
      }

      if (hasOverlap) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Niestety, wybrany zabieg jest za długi i nakłada się na inną wizytę!';
          });
        }
        return;
      }

      // 3. Zapis zmian
      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
        'date': formattedDateStr,
        'time': _selectedTime,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Termin został zaktualizowany!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Wystąpił błąd zapisu: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 POBIERANIE DANYCH O USŁUDZE DO WYŚWIETLENIA
    final String serviceName = widget.appointmentData['serviceName'] ?? 'Usługa';
    final int duration = widget.appointmentData['duration'] ?? 30;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zmień termin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      // 🚀 DODANE: Informacja o nazwie usługi i czasie trwania
                      Text(
                          '$serviceName • Czas: $duration min',
                          style: const TextStyle(fontSize: 14, color: Colors.pinkAccent, fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                ),
                IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)
                ),
              ],
            ),
          ),
          const Divider(),

          // WIDGET WYBORU DATY (Poziomy scroll)
          Container(
            height: 90, color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal, itemCount: 30,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
                final daysOfWeek = ['Nie', 'Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDate = date;
                    _selectedTime = null;
                    _errorMessage = null;
                  }),
                  child: Container(
                    width: 65, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? Colors.pinkAccent : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(daysOfWeek[date.weekday % 7], style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                        const SizedBox(height: 4),
                        Text(date.day.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),

          // GŁÓWNA SIATKA
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('salons').doc(widget.appointmentData['salonId']).snapshots(),
              builder: (context, salonSnapshot) {
                if (!salonSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                Map<String, dynamic> openingHours = {};
                if (salonSnapshot.data!.exists) {
                  final salonData = salonSnapshot.data!.data() as Map<String, dynamic>;
                  openingHours = salonData['openingHours'] ?? {};
                }

                final daysMapping = {1: '1_pon', 2: '2_wt', 3: '3_sr', 4: '4_czw', 5: '5_pt', 6: '6_sob', 7: '7_nd'};
                String currentDayKey = daysMapping[_selectedDate.weekday] ?? '1_pon';
                Map<String, dynamic> dayConfig = openingHours[currentDayKey] ?? {'1_closed': false, '2_open': '08:00', '3_close': '16:00'};

                bool isDayClosed = dayConfig['1_closed'] ?? false;
                List<String> openParts = (dayConfig['2_open'] ?? '08:00').split(':');
                List<String> closeParts = (dayConfig['3_close'] ?? '16:00').split(':');

                int openInMinutes = (int.tryParse(openParts[0]) ?? 8) * 60 + (int.tryParse(openParts[1]) ?? 0);
                int closeInMinutes = (int.tryParse(closeParts[0]) ?? 16) * 60 + (int.tryParse(closeParts[1]) ?? 0);
                final String formattedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('salonId', isEqualTo: widget.appointmentData['salonId'])
                      .where('employeeId', isEqualTo: widget.appointmentData['employeeId'])
                      .where('date', isEqualTo: formattedDateStr)
                      .snapshots(),
                  builder: (context, appointmentsSnapshot) {
                    if (!appointmentsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                    final List<QueryDocumentSnapshot> activeAppointments = appointmentsSnapshot.data!.docs;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: 56,
                      itemBuilder: (context, index) {
                        int currentMinutes = (7 * 60) + (index * 15);
                        int hour = currentMinutes ~/ 60;
                        int minute = currentMinutes % 60;
                        String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";

                        bool isSlotClosed = isDayClosed || currentMinutes < openInMinutes || currentMinutes >= closeInMinutes;
                        bool isAlreadyBooked = false;

                        for (var appDoc in activeAppointments) {
                          if (appDoc.id == widget.appointmentId) continue;
                          final d = appDoc.data() as Map<String, dynamic>;
                          List<String> timeParts = (d['time'] ?? '00:00').split(':');
                          int appStart = (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
                          int appDuration = d['duration'] ?? 30;
                          int appEnd = appStart + appDuration;

                          if (currentMinutes >= appStart && currentMinutes < appEnd) {
                            isAlreadyBooked = true;
                            break;
                          }
                        }

                        bool isDisabled = isSlotClosed || isAlreadyBooked;
                        bool isSelected = _selectedTime == formattedTime;

                        return InkWell(
                          onTap: isDisabled ? null : () => setState(() {
                            _selectedTime = formattedTime;
                            _errorMessage = null;
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDisabled ? Colors.grey[200] : (isSelected ? Colors.pinkAccent : Colors.pink[50]),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Colors.pinkAccent : Colors.transparent, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              formattedTime,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDisabled ? Colors.grey[400] : (isSelected ? Colors.white : Colors.pinkAccent),
                                decoration: isDisabled && !isSlotClosed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_selectedTime == null || _isLoading) ? null : _updateAppointmentTime,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Potwierdź zmianę', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}