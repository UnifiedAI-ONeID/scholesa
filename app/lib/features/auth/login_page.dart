import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await _auth.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      context.read<AppState>().clearRole();
      Navigator.pushReplacementNamed(context, '/roles');
    } catch (e) {
      setState(() => error = 'Check your email or password and try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF0B1224), Color(0xFF0F172A), Color(0xFF0B1224)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Welcome back',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to access your role dashboards.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Email address'),
                          const SizedBox(height: 8),
                          _field(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            hint: 'you@example.com',
                          ),
                          const SizedBox(height: 14),
                          _label('Password'),
                          const SizedBox(height: 8),
                          _field(
                            controller: passwordController,
                            obscure: true,
                            hint: '••••••••',
                          ),
                          const SizedBox(height: 14),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                            ),
                          ElevatedButton(
                            onPressed: loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: const Color(0xFF0B1224),
                            ),
                            child: loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: loading ? null : () => Navigator.pushNamed(context, '/register'),
                            child: const Text('Need an account? Register', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700));

  Widget _field({
    required TextEditingController controller,
    bool obscure = false,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}

Widget _glassCard({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white10),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 12))],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}
