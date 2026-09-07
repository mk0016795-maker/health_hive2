import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vibration/vibration.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  // Triggers tracking for 10, 5, 2 tokens and exact turn
  final Set<String> _notifiedStages = {};

  void _triggerVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 1000);
    }
  }

  void _showAlertPopup(String title, String message) {
    _triggerVibration();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.teal),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _checkAndTriggerAlerts({
    required String apptId,
    required int myToken,
    required int currentRunningToken,
  }) {
    int tokensLeft = myToken - currentRunningToken;

    // 10 Tokens Left Alert
    if (tokensLeft == 10) {
      String key = '${apptId}_10';
      if (!_notifiedStages.contains(key)) {
        _notifiedStages.add(key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAlertPopup(
            'Queue Alert!',
            'Aap ki bari mein 10 tokens baaki hain. Tayyari shuru kar lein.',
          );
        });
      }
    }

    // 5 Tokens Left Alert
    if (tokensLeft == 5) {
      String key = '${apptId}_5';
      if (!_notifiedStages.contains(key)) {
        _notifiedStages.add(key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAlertPopup(
            'Queue Alert!',
            'Aap ki bari mein sirf 5 tokens baaki hain. Clinic pohnchne ki tayyari karein.',
          );
        });
      }
    }

    // 2 Tokens Left Alert
    if (tokensLeft == 2) {
      String key = '${apptId}_2';
      if (!_notifiedStages.contains(key)) {
        _notifiedStages.add(key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAlertPopup(
            'Urgent Alert!',
            'Sirf 2 tokens baaki hain! Bara-e-karam clinic ke waiting area mein mawaqif rahein.',
          );
        });
      }
    }

    // Exact Turn Alert
    if (tokensLeft == 0 && currentRunningToken > 0) {
      String key = '${apptId}_turn';
      if (!_notifiedStages.contains(key)) {
        _notifiedStages.add(key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAlertPopup(
            'Your Turn Now!',
            'Aap ki appointment ka time aa gaya hai! Please doctor room mein tashreef le jayein.',
          );
        });
      }
    }
  }

  Future<void> _handleAppointmentAction({
    required String docId,
    required String title,
    required String message,
  }) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title Successful'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appointment Status Tracking',
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
                    .where(
                      'patientUid',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                    )
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
                        'No active or past appointments.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  final appointments = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final docId = appointments[index].id;
                      final appt =
                          appointments[index].data() as Map<String, dynamic>;
                      final currentStatus = appt['status'] ?? 'Pending';
                      final doctorName = appt['doctorName'] ?? 'Doctor';
                      final int? myToken = appt['tokenNumber'];
                      final String assignedTime =
                          appt['doctorAssignedTime'] ?? 'Pending';

                      Color statusColor = Colors.amber;
                      if (currentStatus == 'Accepted') {
                        statusColor = Colors.green;
                      } else if (currentStatus == 'Rejected') {
                        statusColor = Colors.red;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      doctorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentStatus,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Clear / Cancel Appointment',
                                    onPressed: () => _handleAppointmentAction(
                                      docId: docId,
                                      title: 'Clear Appointment',
                                      message: 'Kya aap is appointment ko apni screen se hatana ya cancel karna chahte hain?',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Patient: ${appt['patientName'] ?? 'N/A'} (Age: ${appt['patientAge'] ?? 'N/A'})',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Assigned Time: $assignedTime',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal,
                                ),
                              ),

                              if (currentStatus == 'Accepted' &&
                                  myToken != null) ...[
                                const SizedBox(height: 16),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('clinics')
                                      .doc(doctorName)
                                      .snapshots(),
                                  builder: (context, clinicSnapshot) {
                                    if (!clinicSnapshot.hasData ||
                                        !clinicSnapshot.data!.exists) {
                                      return const Text(
                                        'Waiting for doctor to start live queue...',
                                        style: TextStyle(color: Colors.grey),
                                      );
                                    }

                                    var clinicData =
                                        clinicSnapshot.data!.data()
                                            as Map<String, dynamic>;
                                    int currentRunningToken =
                                        clinicData['current_token'] ?? 0;

                                    // Stage Alerts Verification
                                    _checkAndTriggerAlerts(
                                      apptId: docId,
                                      myToken: myToken,
                                      currentRunningToken: currentRunningToken,
                                    );

                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.blue.shade100,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Current Token',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Your Token: #$myToken',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '$currentRunningToken',
                                            style: const TextStyle(
                                              fontSize: 70,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2563EB),
                                              height: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Now Serving',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
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
