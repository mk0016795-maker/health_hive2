import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'patient_appointments.dart';

class BookingPaymentScreen extends StatefulWidget {
  final String doctorName;
  final String doctorFees;
  final String selectedSlot;

  const BookingPaymentScreen({
    super.key,
    required this.doctorName,
    required this.doctorFees,
    required this.selectedSlot,
  });

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  String _bookingFor = 'Myself';
  String? _gender;
  String _selectedPaymentMethod = 'Easypaisa';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitAppointmentRequest() async {
    int doctorFeeInt =
        int.tryParse(widget.doctorFees.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int totalAmount = doctorFeeInt + 50;
    // ======================================
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('appointments').add({
        'patientUid': FirebaseAuth
            .instance
            .currentUser
            ?.uid, // Logged-in user ki ID save karein
        'doctorName': widget.doctorName,
        'selectedSlot': widget.selectedSlot,
        'patientName': _nameController.text.trim(),
        'patientAge': _ageController.text.trim(),
        'patientPhone': _phoneController.text.trim(),
        'gender': _gender,
        'bookingType': _bookingFor,
        'paymentMethod': _selectedPaymentMethod,
        'doctorFees': widget.doctorFees,
        'platformFee': 'Rs. 50',
        'totalPaid': 'Rs. $totalAmount',
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientAppointmentsScreen(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Please check internet.'),
        ),
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
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int doctorFeeInt =
        int.tryParse(widget.doctorFees.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int totalAmount = doctorFeeInt + 50;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Patient Details & Payment'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Who is this appointment for?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Book for Myself'),
                            selected: _bookingFor == 'Myself',
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: _bookingFor == 'Myself'
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            onSelected: (selected) =>
                                setState(() => _bookingFor = 'Myself'),
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Book for Relative'),
                            selected: _bookingFor == 'Relative',
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: _bookingFor == 'Relative'
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            onSelected: (selected) =>
                                setState(() => _bookingFor = 'Relative'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Patient Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: _bookingFor == 'Myself'
                              ? 'Your Full Name'
                              : "Patient's Full Name",
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Age',
                                prefixIcon: const Icon(Icons.cake_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: const Icon(Icons.wc_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: ['Male', 'Female', 'Other']
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _gender = value),
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Contact Phone Number',
                          prefixIcon: const Icon(Icons.phone_android_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Phone number is mandatory' : null,
                      ),
                      const SizedBox(height: 28),

                      const Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _selectedPaymentMethod = 'Easypaisa',
                              ),
                              icon: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: _selectedPaymentMethod == 'Easypaisa'
                                    ? Colors.white
                                    : Colors.green,
                              ),
                              label: const Text('Easypaisa'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    _selectedPaymentMethod == 'Easypaisa'
                                    ? Colors.green.shade600
                                    : Colors.white,
                                foregroundColor:
                                    _selectedPaymentMethod == 'Easypaisa'
                                    ? Colors.white
                                    : Colors.black,
                                side: BorderSide(color: Colors.green.shade600),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _selectedPaymentMethod = 'JazzCash',
                              ),
                              icon: Icon(
                                Icons.wallet_rounded,
                                color: _selectedPaymentMethod == 'JazzCash'
                                    ? Colors.white
                                    : Colors.amber.shade800,
                              ),
                              label: const Text('JazzCash'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    _selectedPaymentMethod == 'JazzCash'
                                    ? Colors.amber.shade800
                                    : Colors.white,
                                foregroundColor:
                                    _selectedPaymentMethod == 'JazzCash'
                                    ? Colors.white
                                    : Colors.black,
                                side: BorderSide(color: Colors.amber.shade800),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.withAlpha(50)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Doctor Fee:',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  widget.doctorFees,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Platform Service Fee:',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Rs. 50',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24, thickness: 1),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Payable:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  'Rs. $totalAmount',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _submitAppointmentRequest,
                          icon: const Icon(Icons.payment_rounded),
                          label: const Text(
                            'Pay Fees & Secure Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
