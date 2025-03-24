import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  _AccountSettingsState createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _currentEmailController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _deletePasswordController =
      TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureDeletePassword = true;
  late TabController _tabController;

  // Password validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentEmail();
    _newPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.removeListener(_validatePassword);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    });
  }

  Future<void> _loadCurrentEmail() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await user.reload();
        final refreshedUser = _authService.currentUser;
        if (refreshedUser != null) {
          setState(() {
            _currentEmailController.text = refreshedUser.email ?? '';
          });
        } else {
          setState(() {
            _currentEmailController.text = 'No email available';
          });
        }
      } else {
        setState(() {
          _currentEmailController.text = 'Not logged in';
        });
      }
    } catch (e) {
      setState(() {
        _currentEmailController.text = 'Error fetching email: $e';
      });
    }
  }

  Future<void> _updateEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: SizedBox(
          height: 100,
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 40),
              Flexible(
                child: const Text('Sending verification email...'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user logged in');

      print('Current user email: ${user.email}');
      print(
          'User providers: ${user.providerData.map((p) => p.providerId).toList()}');
      bool isEmailPasswordUser = user.providerData
          .any((provider) => provider.providerId == 'password');
      if (!isEmailPasswordUser) {
        throw Exception(
            'Email update is not supported for this sign-in method.');
      }

      print(
          'Attempting re-authentication with password: ${_passwordController.text}');
      await _authService.reauthenticate(_passwordController.text);
      await user.reload();
      print('Re-authentication successful');
      print('Attempting to update email to: ${_emailController.text}');
      await _authService.updateEmail(_emailController.text);
      print('Verification email sent successfully');

      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Email Verification Sent'),
            content: Text(
                'A verification email has been sent to ${_emailController.text}. Please verify it to complete the update.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                    (route) => false,
                  );
                },
                child: const Text('Re-Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Update email error: $e');
      if (context.mounted) {
        Navigator.pop(context);
      }
      setState(() {
        _errorMessage = 'Failed to update email: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if passwords match
      if (_newPasswordController.text != _confirmPasswordController.text) {
        throw Exception('New password and confirmation do not match');
      }

      // Check password requirements
      if (!(_hasMinLength &&
          _hasUppercase &&
          _hasLowercase &&
          _hasNumber &&
          _hasSpecialChar)) {
        throw Exception(
            'Password must be at least 8 characters long and include uppercase, lowercase, number, and special character');
      }

      print(
          'User providers: ${user.providerData.map((p) => p.providerId).toList()}');
      bool isEmailPasswordUser = user.providerData
          .any((provider) => provider.providerId == 'password');
      if (!isEmailPasswordUser) {
        throw Exception(
            'Password update is not supported for this sign-in method.');
      }

      print(
          'Attempting re-authentication with password: ${_passwordController.text}');
      await _authService.reauthenticate(_passwordController.text);
      await user.reload();
      print('Re-authentication successful');
      print('Attempting to update password');
      await _authService.updatePassword(_newPasswordController.text);
      print('Password updated successfully');

      // Clear all password fields
      _passwordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Show success modal
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Your password has been updated successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Update password error: $e');
      setState(() {
        _errorMessage = 'Failed to update password: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user logged in');

      print(
          'User providers: ${user.providerData.map((p) => p.providerId).toList()}');
      bool isEmailPasswordUser = user.providerData
          .any((provider) => provider.providerId == 'password');
      if (!isEmailPasswordUser) {
        throw Exception(
            'Account deletion is not supported for this sign-in method.');
      }

      print(
          'Attempting re-authentication with password: ${_deletePasswordController.text}');
      await _authService.reauthenticate(_deletePasswordController.text);
      print('Re-authentication successful');
      print('Deleting account');
      await _authService.deleteAccount();
      print('Account deletion successful');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );

      await _authService.signout(context: context);
    } catch (e) {
      print('Delete account error: $e');
      setState(() {
        _errorMessage = 'Failed to delete account: $e';
      });
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
        title: const Text('Account Settings',
            style: TextStyle(color: Colors.black)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Email'),
            Tab(text: 'Password'),
            Tab(text: 'Delete'),
          ],
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Email Tab
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Update Email',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'New Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateEmail,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Email'),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          // Password Tab
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Update Password',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword),
                      ),
                    ),
                    obscureText: _obscureNewPassword,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                  ),
                  const SizedBox(height: 16),
                  // Password requirements
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password must contain:',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          Text(
                            '• At least 8 characters ',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _hasMinLength ? '✓' : '✗',
                            style: TextStyle(
                              color: _hasMinLength ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '• Uppercase letter ',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _hasUppercase ? '✓' : '✗',
                            style: TextStyle(
                              color: _hasUppercase ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '• Lowercase letter ',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _hasLowercase ? '✓' : '✗',
                            style: TextStyle(
                              color: _hasLowercase ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '• Number ',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _hasNumber ? '✓' : '✗',
                            style: TextStyle(
                              color: _hasNumber ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '• Special character ',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _hasSpecialChar ? '✓' : '✗',
                            style: TextStyle(
                              color:
                                  _hasSpecialChar ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Password'),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          // Delete Tab
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Delete Your Account',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _currentEmailController,
                    decoration: const InputDecoration(
                        labelText: 'Current Email',
                        border: OutlineInputBorder()),
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deletePasswordController,
                    decoration: InputDecoration(
                      labelText: 'Password (for deletion)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureDeletePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() =>
                            _obscureDeletePassword = !_obscureDeletePassword),
                      ),
                    ),
                    obscureText: _obscureDeletePassword,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _deleteAccount,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Delete Account'),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
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
