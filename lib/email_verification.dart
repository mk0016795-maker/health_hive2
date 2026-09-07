import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Apni Dashboard screens ko import karein
import 'patient_dashboard.dart';
import 'doctor_dashboard.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    // Check karein ke user pehle se verified toh nahi hai
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // 1. Initial verification email bhejein
      sendVerificationEmail();

      // 2. Har 3 second baad automatic check lagayein
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel(); // Screen band hone par timer dispose zaroor karein
    super.dispose();
  }

  /// Verification email bhejney ka method
  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();

      setState(() => canResendEmail = false);
      // User ko resend button Spam hone se bachane ke liye 5 sec delay
      await Future.delayed(const Duration(seconds: 5));
      setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  /// Firebase se check karna ke link click hua ya nahi
  Future<void> checkEmailVerified() async {
    // Current user status reload karna lazmi hai
    await FirebaseAuth.instance.currentUser?.reload();

    setState(() {
      isEmailVerified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      // Role (Patient or Doctor) fetch karke Dashboard par redirect karein
      _redirectUserToDashboard();
    }
  }

  Future<void> _redirectUserToDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // User document fetch karein Firestore se
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      String role = userDoc.get('role') ?? 'patient';
      // Doctor ka naam fetch karein (agar name na ho toh default fallback 'Doctor')
      String doctorName = userDoc.data().toString().contains('name')
          ? userDoc.get('name')
          : 'Doctor';

      if (role == 'doctor') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DoctorDashboardScreen(
              currentDoctorName:
                  doctorName, // <--- Yeh required parameter add kar diya hai
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PatientDashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Dashboard routing error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return isEmailVerified
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
            appBar: AppBar(
              title: const Text('One Click Verification'),
              automaticallyImplyLeading: false,
            ),
            body: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 100,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'We Send You Verification Link',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Kindly click on link (${FirebaseAuth.instance.currentUser?.email}) for verification.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Resend Email Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.email),
                    label: const Text(
                      'Resend Link',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: canResendEmail ? sendVerificationEmail : null,
                  ),
                  const SizedBox(height: 15),

                  // Cancel / Sign Out Button
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text(
                      'Cancel / Sign Out',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    onPressed: () async {
                      timer?.cancel();
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
  }
}
