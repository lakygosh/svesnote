import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:svesnoteapp/home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _repeatPassCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _repeatPassCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
          setState(() => _error = 'Enter a valid email.');
          return false;
        }
        break;
      case 1:
        if (_passCtrl.text.length < 6) {
          setState(() => _error = 'Password must be at least 6 characters.');
          return false;
        }
        if (_passCtrl.text != _repeatPassCtrl.text) {
          setState(() => _error = 'Passwords do not match.');
          return false;
        }
        break;
      case 2:
        if (_usernameCtrl.text.trim().isEmpty) {
          setState(() => _error = 'Choose a username.');
          return false;
        }
        break;
    }
    setState(() => _error = null);
    return true;
  }

  void _handleNext() {
    if (!_validateCurrentStep() || _loading) return;
    if (_step < 2) {
      setState(() => _step += 1);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final username = _usernameCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      var session = response.session;

      if (session == null) {
        final signInResponse = await Supabase.instance.client.auth
            .signInWithPassword(email: email, password: password);
        session = signInResponse.session;
      }

      if (!mounted) return;

      if (session != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _error = 'Check your email to confirm your account.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Registration failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        );
      case 1:
        return Column(
          children: [
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repeatPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repeat password'),
            ),
          ],
        );
      case 2:
        return TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(labelText: 'Username'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step ${_step + 1} of 3',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStepContent(),
                  ),
                ),
              ),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _step -= 1;
                              _error = null;
                            }),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _loading ? null : _handleNext,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step < 2 ? 'Next' : 'Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
