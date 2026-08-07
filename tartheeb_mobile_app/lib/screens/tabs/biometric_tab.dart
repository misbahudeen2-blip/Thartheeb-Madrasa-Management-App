import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class BiometricTab extends StatefulWidget {
  final String tenantId;
  const BiometricTab({super.key, required this.tenantId});

  @override
  State<BiometricTab> createState() => _BiometricTabState();
}

class _BiometricTabState extends State<BiometricTab> {
  bool _isLoading = true;
  List<dynamic> _devices = [];
  List<dynamic> _punchFeed = [];
  int _registered = 0;
  int _presentToday = 0;
  int _lateToday = 0;
  int _absentToday = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadPunchFeed());
  }

  @override
  void didUpdateWidget(covariant BiometricTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId && widget.tenantId.isNotEmpty) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (widget.tenantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final devices = await ApiService.getDevices(widget.tenantId);
      final students = await ApiService.getStudents(widget.tenantId);
      if (mounted) {
        setState(() {
          _devices = devices is List ? devices : [];
          _registered = students is List ? students.length : 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPunchFeed() async {
    if (widget.tenantId.isEmpty) return;
    try {
      final devices = await ApiService.getDevices(widget.tenantId);
      if (mounted) {
        setState(() {
          _devices = devices is List ? devices : [];
        });
      }
    } catch (e) {
      // silent refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.emerald500,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Biometric Attendance Portal',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate900,
                ),
              ),
              Text(
                'Live punch logs and eSSL/ZKTeco device management',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.slate400),
              ),
              const SizedBox(height: 16),

              // Device Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Biometric Devices',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.slate900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10b981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_devices.length} Online',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.emerald700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
                        : _devices.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: AppTheme.slate400, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'No biometric devices registered yet.',
                                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.slate400),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: _devices.map((dev) {
                                  final name = dev['device_name'] ?? 'eSSL Device';
                                  final sn = dev['sn'] ?? 'SN-UNKNOWN';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.fingerprint_rounded, color: AppTheme.emerald500),
                                    ),
                                    title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                    subtitle: Text('SN: $sn', style: GoogleFonts.inter(fontSize: 12)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Connected',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.green.shade700),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Live Punch Feed Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live Punch Feed',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                  Text(
                    'Auto-refreshing 5s',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                child: _punchFeed.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 48, color: AppTheme.slate400.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No recent punches recorded today',
                                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.slate400),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _punchFeed.map((punch) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.emerald50,
                              child: const Icon(Icons.person_rounded, color: AppTheme.emerald500),
                            ),
                            title: Text(punch['name'] ?? 'Student', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            subtitle: Text(punch['punch_time'] ?? '', style: GoogleFonts.inter(fontSize: 12)),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
