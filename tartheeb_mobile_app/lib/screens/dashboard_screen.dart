import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'tabs/overview_tab.dart';
import 'tabs/students_tab.dart';
import 'tabs/biometric_tab.dart';
import 'tabs/more_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _madrasaName = 'Tartheeb';
  String _tenantId = '';
  String _role = 'admin';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _madrasaName = prefs.getString('madrasa_name') ?? 'Tartheeb';
      _tenantId = prefs.getString('tenant_id') ?? '';
      _role = prefs.getString('role') ?? 'admin';
      _username = prefs.getString('username') ?? 'Admin';
    });
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (_role == 'admin' || _role == 'superadmin')
        ? _madrasaName
        : (_username.isNotEmpty ? _username : _madrasaName);

    final tabs = [
      OverviewTab(tenantId: _tenantId, displayName: displayName),
      StudentsTab(tenantId: _tenantId),
      BiometricTab(tenantId: _tenantId),
      MoreTab(
        tenantId: _tenantId,
        username: displayName,
        role: _role,
        onSwitchTab: switchTab,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/thartheeb-logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _madrasaName,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.slate900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.slate900),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.slate900,
          selectedItemColor: const Color(0xFF10b981),
          unselectedItemColor: AppTheme.slate400,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fingerprint_rounded),
              label: 'Biometrics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
