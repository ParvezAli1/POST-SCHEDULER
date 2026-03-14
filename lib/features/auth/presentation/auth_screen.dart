import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/services.dart';
import '../../../core/widgets/app_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_looksLikeEmail(email)) {
      setState(() {
        _error = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.trim().isEmpty) {
      setState(() {
        _error = 'Please enter your password.';
      });
      return;
    }

    if (!_isLogin && password.trim().length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final authRepository = AppServices.authRepository;

    final ok = _isLogin
        ? await authRepository.login(email: email, password: password)
        : await authRepository.signup(email: email, password: password);

    if (!mounted) {
      return;
    }

    if (!ok) {
      setState(() {
        _busy = false;
        _error = _isLogin
            ? 'Login failed. Check your email/password or enable Email/Password in Firebase.'
            : 'Signup failed. Email may already be used or provider is disabled.';
      });
      return;
    }

    if (!_isLogin) {
      setState(() {
        _isLogin = true;
        _busy = false;
        _error = null;
        _passwordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully. Please login.'),
        ),
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(homeRoute, (route) => false);
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await AppServices.authRepository.signInWithGoogle();

    if (!mounted) {
      return;
    }

    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Google sign-in was canceled or failed.';
      });
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(homeRoute, (route) => false);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final ok = await AppServices.authRepository.sendPasswordResetEmail(
      email: email,
    );

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Enter a valid email to reset password.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 84, showLabel: false)),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Login to continue scheduling your posts.'
                        : 'Create an account to start scheduling posts.',
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: true, label: Text('Login')),
                      ButtonSegment<bool>(value: false, label: Text('Sign up')),
                    ],
                    selected: {_isLogin},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isLogin = selection.first;
                        _emailController.clear();
                        _passwordController.clear();
                        _error = null;
                        _busy = false;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Please wait...'
                          : (_isLogin ? 'Login' : 'Create account'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _continueWithGoogle,
                    icon: const _GoogleLogoIcon(),
                    label: const Text('Continue with Google'),
                  ),
                  if (_isLogin) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }
}

class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDADCE0)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
