import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedRoleIndex = 0; // 0: Admin, 1: Teacher, 2: Parent
  final List<String> _roles = ['Admin', 'Teacher', 'Parent'];

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _institutionCodeController = TextEditingController();
  final _userIdController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _institutionCodeController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedRoleIndex == 0) {
        // Admin Login
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        if (email.isEmpty || password.isEmpty) {
          setState(() {
            _errorMessage = "Please enter your Email / Username and Password.";
            _isLoading = false;
          });
          return;
        }

        final result = await ApiService.login(email, password);
        if (result['success'] == true) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          setState(() {
            _errorMessage = result['message'] ?? "Invalid Username or Password.";
          });
        }
      } else {
        // Teacher / Parent Login
        final instCode = _institutionCodeController.text.trim();
        final userId = _userIdController.text.trim();
        final password = _passwordController.text.trim();

        if (instCode.isEmpty || userId.isEmpty || password.isEmpty) {
          setState(() {
            _errorMessage = "Please fill in all fields (Institution Code, ID, Password).";
            _isLoading = false;
          });
          return;
        }

        final role = _roles[_selectedRoleIndex].toLowerCase();
        final result = await ApiService.memberLogin(role, instCode, userId, password);
        if (result['success'] == true) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          setState(() {
            _errorMessage = result['message'] ?? "Invalid Institution Code, ID, or Password.";
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isPassword = false, IconData? prefixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.emerald500) : null,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppTheme.emerald500, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Image.asset('assets/images/thartheeb-logo.png', width: 64, height: 64),
                const SizedBox(height: 16),
                Text(
                  'Tartheeb',
                  style: GoogleFonts.philosopher(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                Text(
                  'Madrasa Management App',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Card for Login
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Role Selector Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: List.generate(_roles.length, (index) {
                            final isSelected = _selectedRoleIndex == index;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedRoleIndex = index;
                                    _errorMessage = null;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.emerald500 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _roles[index],
                                      style: GoogleFonts.inter(
                                        color: isSelected ? Colors.white : Colors.grey.shade600,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message display
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Form Fields
                      if (_selectedRoleIndex == 0) ...[
                        _buildTextField(_emailController, 'Email / Username', prefixIcon: Icons.email_outlined),
                        _buildTextField(_passwordController, 'Password', isPassword: true, prefixIcon: Icons.lock_outline),
                      ] else ...[
                        _buildTextField(_institutionCodeController, 'Institution Code', prefixIcon: Icons.business_outlined),
                        _buildTextField(
                          _userIdController,
                          _selectedRoleIndex == 1 ? 'Teacher ID' : 'Student ID',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        _buildTextField(_passwordController, 'Password', isPassword: true, prefixIcon: Icons.lock_outline),
                      ],

                      const SizedBox(height: 8),

                      // Login Button (Height 56 prevents 'g' descender clipping)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  'Login to Dashboard',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: Text(
                    "Don't have an account? Register here",
                    style: GoogleFonts.inter(
                      color: AppTheme.emerald500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
