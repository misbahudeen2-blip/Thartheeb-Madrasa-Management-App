import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
  List<dynamic> _attendanceRecords = [];
  int _registered = 0;
  int _presentToday = 0;
  int _biometricCount = 0;
  int _manualCount = 0;
  int _absentToday = 0;
  Timer? _refreshTimer;
  String _feedFilter = 'ALL'; // 'ALL', 'biometric', 'manual'

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadAttendanceFeed());
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
    await _loadAttendanceFeed();
  }

  Future<void> _loadAttendanceFeed() async {
    if (widget.tenantId.isEmpty) return;
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final devices = await ApiService.getDevices(widget.tenantId);
      final attData = await ApiService.getAttendance(widget.tenantId, todayStr);

      if (mounted) {
        final records = (attData is Map ? attData['records'] : []) as List? ?? [];
        final total = attData is Map ? (attData['totalStudents'] ?? records.length) : records.length;
        final present = attData is Map ? (attData['presentCount'] ?? 0) : 0;
        final bio = attData is Map ? (attData['biometricCount'] ?? 0) : 0;
        final man = attData is Map ? (attData['manualCount'] ?? 0) : 0;
        final absent = attData is Map ? (attData['absentCount'] ?? 0) : 0;

        setState(() {
          _devices = devices is List ? devices : [];
          _attendanceRecords = records.where((r) => r['status'] != 'Absent').toList();
          _registered = total;
          _presentToday = present;
          _biometricCount = bio;
          _manualCount = man;
          _absentToday = absent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredRecords {
    if (_feedFilter == 'biometric') {
      return _attendanceRecords.where((r) => r['entryMode'] == 'biometric').toList();
    } else if (_feedFilter == 'manual') {
      return _attendanceRecords.where((r) => r['entryMode'] == 'manual').toList();
    }
    return _attendanceRecords;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Biometric & Attendance Portal',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: AppTheme.slate900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.emerald500,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attendance Overview Summary Card
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
                          'Today\'s Attendance Summary',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.slate900,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(DateTime.now()),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emerald700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildStatTile(
                          'Total Students',
                          '$_registered',
                          Icons.school_outlined,
                          AppTheme.slate900,
                          Colors.grey.shade100,
                        ),
                        const SizedBox(width: 8),
                        _buildStatTile(
                          'Present Today',
                          '$_presentToday',
                          Icons.check_circle_outline,
                          const Color(0xFF10b981),
                          const Color(0xFFf0fdf4),
                          subtitle: '($_biometricCount 👆 • $_manualCount 📝)',
                        ),
                        const SizedBox(width: 8),
                        _buildStatTile(
                          'Absent',
                          '$_absentToday',
                          Icons.cancel_outlined,
                          const Color(0xFFef4444),
                          const Color(0xFFfef2f2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Zero-punch Machine Banner (on rain/online class days)
              if (_biometricCount == 0 && _manualCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFeff6ff),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFbfdbfe)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_outlined, color: Color(0xFF1d4ed8), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No machine punches today. $_manualCount students marked via Manual Attendance (Online/Rain Day).',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1e40af),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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

              // Live Punch & Attendance Feed Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live Punch & Manual Logs',
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                  Text(
                    'Auto-refreshing 10s',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Feed Filter Badges (ALL / Biometric Only / Manual Only)
              Row(
                children: [
                  _buildFeedFilterBadge('ALL', 'All (${_attendanceRecords.length})'),
                  const SizedBox(width: 8),
                  _buildFeedFilterBadge('biometric', '👆 Machine (${_attendanceRecords.where((r) => r['entryMode'] == 'biometric').length})'),
                  const SizedBox(width: 8),
                  _buildFeedFilterBadge('manual', '📝 Manual (${_attendanceRecords.where((r) => r['entryMode'] == 'manual').length})'),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
                child: _filteredRecords.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 44, color: AppTheme.slate400.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No attendance logs matching filter',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.slate400),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _filteredRecords.map((rec) {
                          final isManual = rec['entryMode'] == 'manual';
                          final name = rec['name'] ?? 'Student';
                          final batch = rec['batchName'] ?? '';
                          final time = rec['checkInTime'] ?? '-';
                          final status = rec['status'] ?? 'Present';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isManual ? const Color(0xFFfafafa) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isManual ? Colors.blue.shade100 : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isManual ? const Color(0xFFeff6ff) : AppTheme.emerald50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isManual ? Icons.edit_note_rounded : Icons.fingerprint_rounded,
                                    color: isManual ? const Color(0xFF2563eb) : AppTheme.emerald500,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.slate900,
                                        ),
                                      ),
                                      Text(
                                        '$batch • $time',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate400),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isManual ? const Color(0xFFdbeafe) : const Color(0xFFdcfce7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isManual ? '📝 Manual Entry' : '👆 $status',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isManual ? const Color(0xFF1d4ed8) : const Color(0xFF15803d),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildStatTile(String label, String value, IconData icon, Color color, Color bgColor, {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate900.withValues(alpha: 0.7),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedFilterBadge(String filterValue, String label) {
    final isSelected = _feedFilter == filterValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _feedFilter = filterValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.emerald500 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.emerald500 : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.slate900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
