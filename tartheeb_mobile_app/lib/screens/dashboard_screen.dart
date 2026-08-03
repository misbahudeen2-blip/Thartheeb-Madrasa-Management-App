import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _madrasaName = 'Quba Madrasa';
  String _tenantId = 'qubamadrasaoffice@gmail.com';
  int _total = 0;
  int _present = 0;
  int _late = 0;
  int _absent = 0;
  List<dynamic> _attendanceList = [];
  List<dynamic> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() async {
    final session = await ApiService.getSession();
    final tenant = session['tenant_id'] ?? 'qubamadrasaoffice@gmail.com';
    final name = session['madrasa_name'] ?? 'Quba Madrasa';
    final today = DateTime.now().toString().split(' ')[0];

    final summary = await ApiService.getAttendanceSummary(tenant, today);
    final deviceList = await ApiService.getDevices();

    if (mounted) {
      setState(() {
        _tenantId = tenant;
        _madrasaName = name;
        _total = summary['total'] ?? 0;
        _present = summary['present'] ?? 0;
        _late = summary['late'] ?? 0;
        _absent = summary['absent'] ?? 0;
        _attendanceList = summary['records'] ?? [];
        _devices = deviceList;
        _isLoading = false;
      });
    }
  }

  void _sendWhatsAppMessage(Map<String, dynamic> record) async {
    final name = record['name'] ?? 'Student';
    final status = record['status'] ?? 'Present';
    final time = record['checkInTime'] ?? '-';
    final phone = record['parentPhone'] ?? '919876543210';
    final today = DateTime.now().toString().split(' ')[0];

    final msg = WhatsAppService.formatAttendanceMessage(
      studentName: name,
      status: status,
      time: time,
      date: today,
      madrasaName: _madrasaName,
    );

    final success = await WhatsAppService.sendDirectMessage(
      phoneNumber: phone,
      message: msg,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _madrasaName,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'LIVE AWS CLOUD PORTAL',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboardData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await ApiService.clearSession();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : RefreshIndicator(
              onRefresh: () async => _loadDashboardData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stat Cards Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildStatCard('Total Students', '$_total', Colors.blue, Icons.people_outline),
                      _buildStatCard('Present Today', '$_present', Colors.green, Icons.check_circle_outline),
                      _buildStatCard('Late Arrivals', '$_late', Colors.amber, Icons.access_time),
                      _buildStatCard('Absent', '$_absent', Colors.red, Icons.cancel_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // eSSL Connected Biometric Machines Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.fingerprint, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Connected eSSL Machines',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _devices.isEmpty
                            ? Text(
                                'Connecting to eSSL Push devices...',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              )
                            : Column(
                                children: _devices.map((d) {
                                  final sn = d['serial_number'] ?? '-';
                                  final status = d['status'] ?? 'ONLINE';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('SN: $sn', style: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: Text(
                                            status,
                                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF047857), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today Attendance Records list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Attendance Feed',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        '${_attendanceList.length} records',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_attendanceList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No attendance punches recorded today yet.',
                          style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attendanceList.length,
                      itemBuilder: (context, index) {
                        final r = _attendanceList[index];
                        final name = r['name'] ?? 'Student';
                        final status = r['status'] ?? 'Present';
                        final time = r['checkInTime'] ?? '-';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Check-in: $time | Batch: ${r['batchName'] ?? '-'}', style: GoogleFonts.inter(fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusBadge(status),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 22),
                                  onPressed: () => _sendWhatsAppMessage(r),
                                  tooltip: 'Send WhatsApp Notification',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, MaterialColor color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color.shade800)),
              Icon(icon, size: 18, color: color.shade700),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade900)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF047857);
    if (status == 'Late') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    } else if (status == 'Absent') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
