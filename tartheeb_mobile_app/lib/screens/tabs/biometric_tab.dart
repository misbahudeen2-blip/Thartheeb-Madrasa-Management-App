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
      if (mounted) {
        setState(() {
          _devices = devices is List ? devices : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPunchFeed() async {
    // Punch feed would come from attendance API or SSE
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.emerald500,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(
              children: [
                _statCard('Registered', _registered.toString(), Icons.person_add, const Color(0xFF3b82f6)),
                const SizedBox(width: 8),
                _statCard('Present', _presentToday.toString(), Icons.check_circle, const Color(0xFF10b981)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statCard('Late', _lateToday.toString(), Icons.access_time, const Color(0xFFf59e0b)),
                const SizedBox(width: 8),
                _statCard('Absent', _absentToday.toString(), Icons.cancel, const Color(0xFFef4444)),
              ],
            ),

            const SizedBox(height: 24),

            // Live Punch Feed
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10b981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Punch Feed',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Auto-refresh 5s)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _punchFeed.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.sensors_off, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No recent punches',
                            style: GoogleFonts.inter(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: _punchFeed.map((punch) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.emerald50,
                              child: const Icon(Icons.person, color: AppTheme.emerald700),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    punch['name'] ?? 'Unknown',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    punch['time'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.slate400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10b981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                punch['status'] ?? 'Present',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10b981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 24),

            // Active Devices
            Text(
              'Active Devices',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
                : _devices.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.devices_other, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No devices registered',
                                style: GoogleFonts.inter(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _devices.map((device) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3b82f6).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.router, color: Color(0xFF3b82f6)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device['serial_number'] ?? 'Device',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        device['ip'] ?? 'Unknown IP',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppTheme.slate400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10b981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Online',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10b981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
