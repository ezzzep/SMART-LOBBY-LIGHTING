// account_settings.dart
import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  _AccountSettingsState createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  final AuthService _authService = AuthService();
  final TextEditingController _currentEmailController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

    // Show "Sending Email" modal
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while sending
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Sending verification email...'),
          ],
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
      await user.reload(); // Ensure user object is fresh
      print('Re-authentication successful');
      print('Attempting to update email to: ${_emailController.text}');
      await _authService.updateEmail(_emailController.text);
      print('Verification email sent successfully');

      // Close "Sending Email" modal
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show "Verification Email Sent" modal with Re-Login button
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false, // Must use button to dismiss
          builder: (context) => AlertDialog(
            title: const Text('Email Verification Sent'),
            content: Text(
                'A verification email has been sent to ${_emailController.text}. Please verify it to complete the update.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close modal
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                    (route) => false, // Clear stack, go to login
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
      // Close "Sending Email" modal if still open
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
          'Attempting re-authentication with password: ${_passwordController.text}');
      await _authService.reauthenticate(_passwordController.text);
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
        title: const Text(
          'Account Settings',
          style: TextStyle(color: Colors.black),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Manage Your Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _currentEmailController,
                decoration: const InputDecoration(
                  labelText: 'Current Email',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Current Password (for verification)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 16),
              const Text(
                'Change Email',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'New Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Email'),
              ),
              const SizedBox(height: 5),
              ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Delete Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
