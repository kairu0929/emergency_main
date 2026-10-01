import 'dart:io';
import 'package:first_flutter_project/auth_serv.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
 
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
 
  @override
  State<SignupPage> createState() => _SignupPageState();
}
 
class _SignupPageState extends State<SignupPage> {
  final authService = AuthService();
  
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  File? _voterIdImage;

    SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  void signUp() async {
    final phoneRegex = RegExp(r'^\+?[0-9]+$'); 
    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final phoneNumber = _phoneController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    print('=== SIGNUP DEBUG ===');
    print('First name: $firstName');
    print('Last name: $lastName');
    print('Phone: $phoneNumber');
    print('Email: "$email"');
    print('Password length: ${password.length}');
    print('Confirm length: ${confirmPassword.length}');
    print('Voter ID: $_voterIdImage');
    print('====================');
    print("First: ${_firstNameController.text}");
    print("Email: ${_emailController.text}");
    print("Password: ${_passwordController.text}");

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar("Password don't match"),
      );
      return;
    }

    if (firstName == null || firstName.isEmpty ||
        lastName == null || lastName.isEmpty ||
        phoneNumber == null || phoneNumber.isEmpty ||
        email == null || email.isEmpty ||
        password == null || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar("Please fill in all fields"),
      );
      return;
    }

    if (!phoneRegex.hasMatch(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar("Please enter a valid phone number"),
      );
      return;
    }

    if (_voterIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar("Please upload a photo of your Voter's ID"),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar("Password must be at least 8 characters"),
      );
      return;

    }

    try {
      await authService.signUp(firstName, lastName, phoneNumber, email, password, _voterIdImage);
      Navigator.pop(context);
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snackBar("Error: $e"));
      }
    }
  }
 
  Future<void> _pickVoterId() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UPLOAD VOTER\'S ID',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 20),
            _sheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker()
                    .pickImage(source: ImageSource.camera, imageQuality: 85);
                if (picked != null) {
                  setState(() => _voterIdImage = File(picked.path));
                }
              },
            ),
            const SizedBox(height: 12),
            _sheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) {
                  setState(() => _voterIdImage = File(picked.path));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
 
  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE53935), size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
 
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 16),
                ),
              ),
 
              const SizedBox(height: 28),
 
              const Text(
                'Create\nAccount.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
 
              const SizedBox(height: 8),
              const Text(
                'Register as a resident of Cluster 6',
                style: TextStyle(color: Color(0xFF888888), fontSize: 14),
              ),
 
              const SizedBox(height: 36),
 
              // First & Last name row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('FIRST NAME'),
                        const SizedBox(height: 8),
                        _buildTextField(
                            hint: 'Juan', icon: Icons.person_outline,
                            controller: _firstNameController),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('LAST NAME'),
                        const SizedBox(height: 8),
                        _buildTextField(
                            hint: 'Dela Cruz', icon: Icons.badge_outlined,
                            controller: _lastNameController),
                      ],
                    ),
                  ),
                ],
              ),
 
              const SizedBox(height: 20),
              _buildLabel('PHONE NUMBER'),
              const SizedBox(height: 8),
              _buildTextField(
                  hint: '+63 9XX XXX XXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  controller: _phoneController),
 
              const SizedBox(height: 20),
              _buildLabel('EMAIL'),
              const SizedBox(height: 8),
              _buildTextField(
                  hint: 'Enter your email', icon: Icons.alternate_email,
                  controller: _emailController),
 
              const SizedBox(height: 20),
              _buildLabel('PASSWORD'),
              const SizedBox(height: 8),
              _buildTextField(
                hint: 'Create a password',
                icon: Icons.lock_outline,
                controller: _passwordController,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF555555),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
 
              const SizedBox(height: 20),
              _buildLabel('CONFIRM PASSWORD'),
              const SizedBox(height: 8),
              _buildTextField(
                hint: 'Repeat your password',
                icon: Icons.lock_outline,
                controller: _confirmPasswordController,
                obscure: _obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF555555),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
 
              // ── VOTER'S ID SECTION ──
              const SizedBox(height: 28),
              _buildLabel("VOTER'S ID"),
              const SizedBox(height: 4),
              const Text(
                'Required for Cluster 6 residency verification',
                style: TextStyle(color: Color(0xFF555555), fontSize: 12),
              ),
              const SizedBox(height: 12),
 
              GestureDetector(
                onTap: _pickVoterId,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _voterIdImage != null
                          ? const Color(0xFFE53935).withOpacity(0.6)
                          : const Color(0xFF2A2A2A),
                      width: 1.5,
                    ),
                  ),
                  child: _voterIdImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                _voterIdImage!,
                                fit: BoxFit.cover,
                              ),
                              // Overlay with change button
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(13)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          color: Colors.white70, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Verified badge
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'ID uploaded',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.upload_file_outlined,
                                color: Color(0xFFE53935),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Upload Voter\'s ID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Take a photo or choose from gallery',
                              style: TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
 
              // Info note
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF444444), size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your account will be reviewed by an admin before activation. '
                      'Make sure your Voter\'s ID shows your Cluster 6 address clearly.',
                      style: const TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
 
              const SizedBox(height: 36),
 
              // Signup button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'CREATE ACCOUNT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
 
              const SizedBox(height: 24),
 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
 
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }
 
  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      obscureText: obscure,
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF444444), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
 