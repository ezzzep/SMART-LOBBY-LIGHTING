import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _emailError;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password requirement flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validate password against requirements
  void _validatePassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    });
  }

  // Check if the new password is the same as the current password
  Future<bool> _isSameAsCurrentPassword(
      String email, String newPassword) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: newPassword,
      );
      return true; // If sign-in succeeds, the new password is the same as the current one
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        return false; // New password is different
      }
      return false; // Other errors, assume it's different to avoid blocking the user
    }
  }

  Future<void> _updatePassword() async {
    setState(() {
      _emailError = null;
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String currentPassword = _currentPasswordController.text.trim();
    String newPassword = _newPasswordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    // Basic field validation
    if (email.isEmpty) {
      setState(() {
        _emailError = "Please enter your email.";
        _isLoading = false;
      });
      return;
    }

    if (currentPassword.isEmpty) {
      setState(() {
        _currentPasswordError = "Please enter your current password.";
        _isLoading = false;
      });
      return;
    }

    if (newPassword.isEmpty) {
      setState(() {
        _newPasswordError = "Please enter a new password.";
        _isLoading = false;
      });
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordError = "Please confirm your new password.";
        _isLoading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _confirmPasswordError = "Passwords do not match.";
        _isLoading = false;
      });
      return;
    }

    // Password strength validation
    if (!_hasMinLength) {
      setState(() {
        _newPasswordError = "Password must be at least 8 characters long.";
        _isLoading = false;
      });
      return;
    }
    if (!_hasUppercase) {
      setState(() {
        _newPasswordError =
            "Password must contain at least one uppercase letter.";
        _isLoading = false;
      });
      return;
    }
    if (!_hasLowercase) {
      setState(() {
        _newPasswordError =
            "Password must contain at least one lowercase letter.";
        _isLoading = false;
      });
      return;
    }
    if (!_hasNumber) {
      setState(() {
        _newPasswordError = "Password must contain at least one number.";
        _isLoading = false;
      });
      return;
    }
    if (!_hasSpecialChar) {
      setState(() {
        _newPasswordError =
            "Password must contain at least one special character.";
        _isLoading = false;
      });
      return;
    }

    try {
      // Step 1: Verify the user's identity by signing in with the current password
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: currentPassword,
      );

      User? user = userCredential.user;
      if (user == null) {
        setState(() {
          _emailError = "Failed to authenticate user.";
          _isLoading = false;
        });
        return;
      }

      // Step 2: Check if the new password is the same as the current password
      bool isSameAsCurrent = await _isSameAsCurrentPassword(email, newPassword);
      if (isSameAsCurrent) {
        setState(() {
          _newPasswordError =
              "New password cannot be the same as the current password.";
          _isLoading = false;
        });
        return;
      }

      // Step 3: Update the password
      await user.updatePassword(newPassword);

      Fluttertoast.showToast(
        msg:
            "Password updated successfully. Please sign in with your new password.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );

      // Sign out the user after updating the password
      await FirebaseAuth.instance.signOut();

      // Navigate back to the login screen
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Failed to update password. Please try again.";
      if (e.code == 'user-not-found') {
        errorMessage = "No user found with this email.";
        setState(() {
          _emailError = errorMessage;
        });
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect current password.";
        setState(() {
          _currentPasswordError = errorMessage;
        });
      } else if (e.code == 'weak-password') {
        errorMessage = "The new password is too weak.";
        setState(() {
          _newPasswordError = errorMessage;
        });
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address.";
        setState(() {
          _emailError = errorMessage;
        });
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            "Please sign out and sign in again to update your password.";
        setState(() {
          _emailError = errorMessage;
        });
      }
      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Change Password",
          style: GoogleFonts.raleway(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Email Field
              Text(
                'Email Address',
                style: GoogleFonts.raleway(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  filled: true,
                  hintText: 'Enter your email',
                  hintStyle: const TextStyle(
                    color: Color(0xff6A6A6A),
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  fillColor: const Color(0xffF7F7F9),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  errorText: _emailError,
                  enabledBorder: OutlineInputBorder(
                    borderSide: _emailError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: _emailError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : const BorderSide(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) => setState(() {
                  _emailError = null;
                }),
              ),
              const SizedBox(height: 20),
              // Current Password Field
              Text(
                'Current Password',
                style: GoogleFonts.raleway(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: _obscureCurrentPassword,
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  filled: true,
                  hintText: 'Enter your current password',
                  hintStyle: const TextStyle(
                    color: Color(0xff6A6A6A),
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  fillColor: const Color(0xffF7F7F9),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  errorText: _currentPasswordError,
                  enabledBorder: OutlineInputBorder(
                    borderSide: _currentPasswordError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: _currentPasswordError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : const BorderSide(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() =>
                        _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                ),
                onChanged: (_) => setState(() {
                  _currentPasswordError = null;
                }),
              ),
              const SizedBox(height: 20),
              // New Password Field
              Text(
                'New Password',
                style: GoogleFonts.raleway(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: _obscureNewPassword,
                controller: _newPasswordController,
                decoration: InputDecoration(
                  filled: true,
                  hintText: 'Enter new password',
                  hintStyle: const TextStyle(
                    color: Color(0xff6A6A6A),
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  fillColor: const Color(0xffF7F7F9),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  errorText: _newPasswordError,
                  enabledBorder: OutlineInputBorder(
                    borderSide: _newPasswordError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: _newPasswordError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : const BorderSide(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                onChanged: (value) {
                  _validatePassword(value);
                  setState(() {
                    _newPasswordError = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              // Password requirements feedback
              _buildPasswordRequirement(
                "At least 8 characters",
                _hasMinLength,
              ),
              _buildPasswordRequirement(
                "At least one uppercase letter",
                _hasUppercase,
              ),
              _buildPasswordRequirement(
                "At least one lowercase letter",
                _hasLowercase,
              ),
              _buildPasswordRequirement(
                "At least one number",
                _hasNumber,
              ),
              _buildPasswordRequirement(
                "At least one special character",
                _hasSpecialChar,
              ),
              const SizedBox(height: 20),
              // Confirm Password Field
              Text(
                'Confirm New Password',
                style: GoogleFonts.raleway(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: _obscureConfirmPassword,
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  filled: true,
                  hintText: 'Confirm new password',
                  hintStyle: const TextStyle(
                    color: Color(0xff6A6A6A),
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  fillColor: const Color(0xffF7F7F9),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  errorText: _confirmPasswordError,
                  enabledBorder: OutlineInputBorder(
                    borderSide: _confirmPasswordError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: _confirmPasswordError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : const BorderSide(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                onChanged: (_) => setState(() {
                  _confirmPasswordError = null;
                }),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(83, 166, 234, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(double.infinity, 60),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Update Password",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String requirement, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.cancel,
          color: isMet ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          requirement,
          style: GoogleFonts.raleway(
            textStyle: TextStyle(
              color: isMet ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
