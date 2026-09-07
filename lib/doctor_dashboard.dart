import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final String currentDoctorName;
  const DoctorDashboardScreen({super.key, required this.currentDoctorName});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  // Appointment Reject ya Normal Update karne ke liye
  Future<void> _updateAppointmentStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment $newStatus'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.')),
        );
      }
    }
  }

  // Doctor ko Token aur Time dono enter karne ke liye Dialog
  Future<void> _showAssignTokenDialog(String docId) async {
    final TextEditingController tokenController = TextEditingController();
    final TextEditingController timeController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Token & Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tokenController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Token Number',
                hintText: 'e.g. 1, 2, 3...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'Appointment Time',
                hintText: 'e.g. 03:30 PM',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tokenController.text.trim().isNotEmpty &&
                  timeController.text.trim().isNotEmpty) {
                int? token = int.tryParse(tokenController.text.trim());
                String assignedTime = timeController.text.trim();
                if (token != null) {
                  Navigator.pop(context);
                  _updateAppointmentWithTimeAndToken(
                    docId,
                    'Accepted',
                    token,
                    assignedTime,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text(
              'Accept & Assign',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Doctor dwara Token aur Time Firestore me save karne ke liye
  Future<void> _updateAppointmentWithTimeAndToken(
    String docId,
    String newStatus,
    int token,
    String time,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .update({
            'status': newStatus,
            'tokenNumber': token,
            'doctorAssignedTime': time,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted with Token #$token at $time'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.')),
        );
      }
    }
  }

  // Doctor ki availability toggle karne ke liye
  Future<void> _toggleDoctorPresence(bool isPresent) async {
    await FirebaseFirestore.instance
        .collection('clinics')
        .doc(widget.currentDoctorName)
        .set({
          'is_doctor_present': isPresent,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // Token Counter Next karne ke liye
  Future<void> _nextPatient() async {
    await FirebaseFirestore.instance
        .collection('clinics')
        .doc(widget.currentDoctorName)
        .update({
          'current_token': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        });
  }

  // Token Counter Previous karne ke liye
  Future<void> _previousPatient(int currentToken) async {
    if (currentToken > 0) {
      await FirebaseFirestore.instance
          .collection('clinics')
          .doc(widget.currentDoctorName)
          .update({
            'current_token': FieldValue.increment(-1),
            'updated_at': FieldValue.serverTimestamp(),
          });
    }
  }

  // Token Reset karne ke liye
  Future<void> _resetToken() async {
    await FirebaseFirestore.instance
        .collection('clinics')
        .doc(widget.currentDoctorName)
        .set({
          'current_token': 0,
          'is_doctor_present': true,
          'avg_time_per_patient': 10,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.currentDoctorName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: REAL-TIME TOKEN CONTROLS ---
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clinics')
                  .doc(widget.currentDoctorName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton(
                      onPressed: _resetToken,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Initialize Today\'s Live Token Session',
                      ),
                    ),
                  );
                }

                var clinicData = snapshot.data!.data() as Map<String, dynamic>;
                bool isPresent = clinicData['is_doctor_present'] ?? false;
                int currentToken = clinicData['current_token'] ?? 0;

                return Card(
                  elevation: 3,
                  color: Colors.teal.shade50,
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isPresent
                                ? 'Clinic Status: IN CLINIC'
                                : 'Clinic Status: AWAY',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isPresent
                                  ? Colors.teal.shade900
                                  : Colors.red,
                            ),
                          ),
                          activeThumbColor: Colors.teal,
                          value: isPresent,
                          onChanged: (val) => _toggleDoctorPresence(val),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // TOKEN CONTROLS ROW
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Token:',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '#$currentToken',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: isPresent && currentToken > 0
                                      ? () => _previousPatient(currentToken)
                                      : null,
                                  icon: const Icon(Icons.skip_previous),
                                  color: Colors.teal,
                                  tooltip: 'Previous Token',
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: isPresent ? _nextPatient : null,
                                  icon: const Icon(Icons.skip_next),
                                  label: const Text('Next'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Divider(),
                        TextButton.icon(
                          onPressed: () async {
                            bool? confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Reset Token Counter?'),
                                content: const Text(
                                  'Is se aaj ka token counter dobara 0 par set ho jayega.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _resetToken();
                            }
                          },
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.red,
                            size: 18,
                          ),
                          label: const Text(
                            'Reset Counter to #0',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // --- SECTION 2: PENDING APPOINTMENTS ---
            const Text(
              'Your Pending Appointment Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('appointments')
                    .where('doctorName', isEqualTo: widget.currentDoctorName)
                    .where('status', isEqualTo: 'Pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No pending requests for you.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  final requests = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final reqId = requests[index].id;
                      final req =
                          requests[index].data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  req['patientName'] ?? 'Patient',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Text(
                                  'Age: ${req['patientAge'] ?? 'N/A'} • Gender: ${req['gender'] ?? 'N/A'}\nPaid: ${req['totalPaid'] ?? 'N/A'} via ${req['paymentMethod'] ?? 'N/A'}',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _updateAppointmentStatus(
                                        reqId,
                                        'Rejected',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Reject & Refund'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showAssignTokenDialog(reqId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Accept & Assign'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }
}
