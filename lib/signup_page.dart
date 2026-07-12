// Signup Page — proj2 UI + proj1 real Firebase Auth
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _isStudent  = true;
  bool _showPass   = false;

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _createAccount() async {
    final provider = Provider.of<AppAuthProvider>(context, listen: false);
    await provider.signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      role: _isStudent ? 'student' : 'teacher',
    );
    if (!mounted) return;
    if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created')));
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/bg2.jpg', fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0d1f3c), Color(0xFF1a2f5e)])))),
        Container(color: Colors.black.withValues(alpha: 0.50)),
        Row(children: [
          // Left panel
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 36),
                  SizedBox(height: 4),
                  Text('NEUROMATHIX', style: TextStyle(color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                ]),
                const SizedBox(height: 80),
                const Text('Start your journey to\nmathematical mastery',
                  style: TextStyle(color: Colors.white, fontSize: 36,
                      fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 32),
                ...['AI that adapts to your learning pace',
                  "Never forget what you've learned",
                  "Understand the 'why' behind every answer",
                  'Track your progress in real-time']
                  .map((s) => Padding(padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      Container(width: 6, height: 6,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                      const SizedBox(width: 12),
                      Text(s, style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w600)),
                    ]))),
              ]))),
          // Right card
          Align(alignment: Alignment.center,
            child: Container(width: 520,
              margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 40, offset: const Offset(0, 16))]),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Create your account', style: TextStyle(color: Color(0xFF111827),
                      fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Join thousands of learners improving with AI',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                  const SizedBox(height: 24),
                  // Student / Teacher toggle
                  Container(height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(30)),
                    child: Row(children: [
                      _roleTab('Student', _isStudent, () => setState(() => _isStudent = true)),
                      _roleTab('Teacher', !_isStudent, () => setState(() => _isStudent = false)),
                    ])),
                  const SizedBox(height: 20),
                  _label('Full name'), const SizedBox(height: 6),
                  _field(controller: _nameCtrl, hint: 'Your full name'),
                  const SizedBox(height: 16),
                  _label('Email address'), const SizedBox(height: 6),
                  _field(controller: _emailCtrl, hint: 'you@university.edu'),
                  const SizedBox(height: 16),
                  _label('Password'), const SizedBox(height: 6),
                  _field(controller: _passCtrl, hint: '••••••••••',
                    obscure: !_showPass,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _showPass = !_showPass),
                      child: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF9CA3AF), size: 20))),
                  const SizedBox(height: 6),
                  const Text('Must be at least 8 characters',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _createAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E95),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0),
                      child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create account →', style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 15)))),
                  const SizedBox(height: 16),
                  Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => LoginPage())),
                      child: const Text('Sign in', style: TextStyle(color: Color(0xFF1F4E95),
                          fontWeight: FontWeight.w700, fontSize: 14))),
                  ])),
                ])))),
        ]),
      ]));
  }

  Widget _roleTab(String label, bool active, VoidCallback onTap) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1F4E95) : Colors.transparent,
          borderRadius: BorderRadius.circular(26)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : const Color(0xFF6B7280),
          fontWeight: FontWeight.w600, fontSize: 14)))));

  Widget _label(String t) => Text(t,
    style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w500, fontSize: 14));

  Widget _field({required TextEditingController controller, required String hint,
      bool obscure = false, Widget? suffix}) {
    return TextField(controller: controller, obscureText: obscure,
      style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix) : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF1F4E95), width: 1.5))));
  }
}
