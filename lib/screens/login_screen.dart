import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.length < 6 || (!_isLogin && _name.text.trim().isEmpty)) {
      _msg('Fill all fields (password min 6 characters)');
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_isLogin) {
        await auth.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        final cred = await auth.createUserWithEmailAndPassword(email: email, password: pass);
        await cred.user?.updateDisplayName(_name.text.trim());
        await cred.user?.reload();
        // Token refresh taaki backend ko naya name mile
        await auth.currentUser?.getIdToken(true);
      }
    } on FirebaseAuthException catch (e) {
      _msg(switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password',
        'email-already-in-use' => 'Email already registered',
        'invalid-email' => 'Invalid email',
        'weak-password' => 'Password too weak',
        'network-request-failed' => 'No internet connection',
        _ => e.message ?? 'Login failed',
      });
    } catch (e) {
      _msg('Something went wrong');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.apartment_rounded, size: 72, color: cs.primary),
                const SizedBox(height: 8),
                Text('PropBid',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Text('Live Property Bidding'),
                const SizedBox(height: 32),
                if (!_isLogin) ...[
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                ],
                TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 12),
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isLogin ? 'Login' : 'Create account'),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'New user? Register' : 'Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
