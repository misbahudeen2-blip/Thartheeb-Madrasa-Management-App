import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'teachers_tab.dart';
import 'batches_tab.dart';
import 'attendance_tab.dart';
import 'fees_tab.dart';

class MoreTab extends StatelessWidget {
  final String tenantId;
  final String username;
  final String role;
  final Function(int) onSwitchTab;

  const MoreTab({
    super.key,
    required this.tenantId,
    required this.username,
    required this.role,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.emerald50,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.emerald700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.emerald700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Menu Items
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _menuItem(
                  context,
                  'Attendance',
                  Icons.fact_check_outlined,
                  const Color(0xFF10b981),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text('Attendance', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          foregroundColor: AppTheme.slate900,
                        ),
                        body: AttendanceTab(tenantId: tenantId),
                      ),
                    ),
                  ),
                ),
                _divider(),
                _menuItem(
                  context,
                  'Teachers',
                  Icons.person_outline,
                  const Color(0xFF3b82f6),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text('Teachers', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          foregroundColor: AppTheme.slate900,
                        ),
                        body: TeachersTab(tenantId: tenantId),
                      ),
                    ),
                  ),
                ),
                _divider(),
                _menuItem(
                  context,
                  'Batches',
                  Icons.groups_outlined,
                  AppTheme.gold600,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text('Batches', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          foregroundColor: AppTheme.slate900,
                        ),
                        body: BatchesTab(tenantId: tenantId),
                      ),
                    ),
                  ),
                ),
                _divider(),
                _menuItem(
                  context,
                  'Shifts',
                  Icons.access_time,
                  const Color(0xFF8b5cf6),
                  () {},
                ),
                _divider(),
                _menuItem(
                  context,
                  'Fees',
                  Icons.payments_outlined,
                  const Color(0xFFec4899),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text('Fees', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          foregroundColor: AppTheme.slate900,
                        ),
                        body: FeesTab(tenantId: tenantId),
                      ),
                    ),
                  ),
                ),
                _divider(),
                _menuItem(
                  context,
                  'Amal Chart',
                  Icons.checklist,
                  const Color(0xFF06b6d4),
                  () {},
                ),
                _divider(),
                _menuItem(
                  context,
                  'Push Alerts',
                  Icons.notifications_active_outlined,
                  const Color(0xFFf97316),
                  () {},
                ),
                _divider(),
                _menuItem(
                  context,
                  'Settings',
                  Icons.settings_outlined,
                  AppTheme.slate400,
                  () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logout
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _menuItem(
              context,
              'Logout',
              Icons.logout,
              Colors.red.shade500,
              () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Logout', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Logout', style: TextStyle(color: Colors.red.shade500)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ApiService.clearSession();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              isDestructive: true,
            ),
          ),

          const SizedBox(height: 32),

          // Footer
          Text(
            '© 2026 Tartheeb Madrasa Management App',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.slate400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Designed By Misbah Musthafa',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.slate400,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String title, IconData icon, Color color,
      VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: isDestructive ? Colors.red.shade500 : AppTheme.slate900,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? Colors.red.shade300 : Colors.grey.shade400,
        size: 20,
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, indent: 60, color: Colors.grey.shade100);
  }
}
