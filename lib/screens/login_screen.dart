import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // --- Existing Logic Controllers (No changes) ---
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _error = '';
  bool _isLoading = false;
  bool _isResettingPassword = false;

  // --- New UI/Animation State ---
  late final AnimationController _bgAnimationController;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  String _activeField = '';

  @override
  void initState() {
    super.initState();

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      if (_emailFocusNode.hasFocus) {
        _activeField = 'email';
      } else if (_passwordFocusNode.hasFocus) {
        _activeField = 'password';
      } else {
        _activeField = '';
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgAnimationController.dispose();
    _emailFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // --- Existing Logic Methods (No changes) ---
  Future<void> _attemptLogin() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    setState(() {
      _error = '';
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await context.read<UserProvider>().login(email, password);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = 'Error: ${e.code}');
      _showErrorSnackbar(_error);
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred.');
      _showErrorSnackbar(_error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackbar('Please enter your email to reset password.');
      return;
    }

    setState(() => _isResettingPassword = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset link sent! Check your email.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // This removes focus from any active TextField when background is tapped
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: _buildGlassmorphicCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFFE73C7E), Color(0xFFEE7752)],
              stops: const [0.0, 1.0],
              transform: GradientRotation(_bgAnimationController.value * 3.1415 * 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassmorphicCard() {
    bool isAnyFieldActive = _activeField.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          // **FIX: Reverted to a simple Column, removing the Stack and background logo**
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/samco_logo.png',
                height: 120,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.restaurant, size: 120, color: Colors.white),
              ),
              const SizedBox(height: 24),
              _AnimatedFocusItem(
                isParentActive: isAnyFieldActive,
                child: Text(
                  'Sign In to Continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _AnimatedFocusItem(
                isParentActive: isAnyFieldActive,
                isActive: _activeField == 'email',
                child: _buildEmailField(),
              ),
              const SizedBox(height: 20),
              _AnimatedFocusItem(
                isParentActive: isAnyFieldActive,
                isActive: _activeField == 'password',
                child: _buildPasswordField(),
              ),
              const SizedBox(height: 12),
              _AnimatedFocusItem(
                isParentActive: isAnyFieldActive,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isResettingPassword ? null : _resetPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isResettingPassword
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                        : Text(
                      'Forgot Password?',
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _AnimatedFocusItem(
                isParentActive: isAnyFieldActive,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE73C7E),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                    ),
                    onPressed: _isLoading ? null : _attemptLogin,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFE73C7E)))
                        : Text(
                      'Sign In',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Email address', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _buildInputDecoration(hintText: 'you@example.com', icon: Icons.email_outlined),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Password', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _attemptLogin(),
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _buildInputDecoration(hintText: '••••••••', icon: Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white.withOpacity(0.7),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
      ),
    );
  }
}

// Helper widget for the focus animation
class _AnimatedFocusItem extends StatelessWidget {
  final bool isParentActive;
  final bool isActive;
  final Widget child;

  const _AnimatedFocusItem({
    required this.isParentActive,
    this.isActive = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool shouldShrink = isParentActive && !isActive;

    return AnimatedScale(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      scale: shouldShrink ? 0.9 : 1.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        opacity: shouldShrink ? 0.5 : 1.0,
        child: child,
      ),
    );
  }
}