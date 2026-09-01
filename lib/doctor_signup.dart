import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'approval_pending.dart';

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Input Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // Added Email for Auth
  final _passwordController =
      TextEditingController(); // Added Password for Auth
  final _pmdcController = TextEditingController();
  final _feesController = TextEditingController();

  String? _selectedSpecialty;
  final List<String> _specialties = [
    'Cardiologist',
    'Therapist',
    'Neurologist',
    'Pediatrician',
    'General Physician',
  ];

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Real-time Cloud Doctor Registry function
  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Create Doctor Credentials in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Save Medical Credentials into Firestore with PENDING verification tag
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': 'Dr. ' + _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'pmdcNumber': _pmdcController.text.trim(),
            'specialty': _selectedSpecialty,
            'role': 'Doctor',
            'isVerified': false, // Crucial security status verification flag
            'createdAt': FieldValue.serverTimestamp(),
            'fees': _feesController.text
                .trim(), // Doctor ki manually entered fees save karein
          });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ApprovalPendingScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Failed to register profile.';
      if (e.code == 'email-already-in-use') {
        errorMsg = 'This email is already in use by another provider.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pmdcController.dispose();
    _feesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Doctor Registration'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Join Health Hive Provider Network',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please provide accurate professional details. Your profile will go live after admin verification.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Name Input
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name (Without Dr. prefix)',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Medical Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'Please enter professional email'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Create Console Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.teal,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) => value!.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // PMDC Number Input
                      TextFormField(
                        controller: _pmdcController,
                        decoration: InputDecoration(
                          labelText: 'PMDC / PMC Registration Number',
                          prefixIcon: const Icon(Icons.verified_user_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: 'e.g., 12345-P',
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'PMDC number is mandatory for verification'
                            : null,
                      ),
                      // Manually Entered Consultation Fees Field
                      TextFormField(
                        controller: _feesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Consultation Fees (Rs.)',
                          prefixIcon: const Icon(Icons.money_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: 'e.g., 1500',
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'Please enter your consultation fees'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),

                      // Specialty Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedSpecialty,
                        decoration: InputDecoration(
                          labelText: 'Select Specialization',
                          prefixIcon: const Icon(
                            Icons.medical_services_rounded,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _specialties.map((String specialty) {
                          return DropdownMenuItem<String>(
                            value: specialty,
                            child: Text(specialty),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSpecialty = value;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select your specialty'
                            : null,
                      ),
                      const SizedBox(height: 40),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _registerDoctor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit Profile for Verification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
