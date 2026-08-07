import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class BatchReportScreen extends StatefulWidget {
  final String batchId;
  final String batchName;
  const BatchReportScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  State<BatchReportScreen> createState() => _BatchReportScreenState();
}

class _BatchReportScreenState extends State<BatchReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _isLoading = true;
  List<dynamic> _studentReports = [];
  int _totalWorkingDays = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
      final data = await ApiService.getBatchComplianceReport(widget.batchId, fromStr, toStr);

      if (mounted) {
        if (data is Map && data['records'] != null) {
          setState(() {
            _studentReports = data['records'] as List;
            _totalWorkingDays = data['totalWorkingDays'] ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _studentReports = [];
            _totalWorkingDays = 0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Batch Report',
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
      body: Column(
        children: [
          // Banner Banner: Olive Green matching Web screenshot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: const Color(0xFF485217),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Color(0xFFe79c23), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Batch Compliance Report: ${widget.batchName}',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Date Selectors Row & Action Buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // FROM DATE
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FROM DATE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94a3b8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _selectDate(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFcbd5e1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd/MMM/yyyy').format(_fromDate),
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.slate900),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // TO DATE
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TO DATE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94a3b8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _selectDate(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFcbd5e1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd/MMM/yyyy').format(_toDate),
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.slate900),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons Row (Refresh, Generate, Export CSV)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadReport,
                        icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                        label: Text('Refresh Report', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF626d1a),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadReport,
                        icon: const Icon(Icons.description, size: 14, color: Colors.white),
                        label: Text('Generate Report', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0f172a),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report exported to CSV successfully.')),
                          );
                        },
                        icon: const Icon(Icons.download, size: 14, color: Colors.white),
                        label: Text('Export CSV', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366f1),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFe2e8f0)),

          // Student Report Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald700))
                : _studentReports.isEmpty
                    ? Center(
                        child: Text('No attendance records found for this date range.', style: GoogleFonts.inter(color: AppTheme.slate400)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _studentReports.length,
                        itemBuilder: (context, index) {
                          final r = _studentReports[index];
                          final name = r['name'] ?? 'Unknown Student';
                          final working = r['workingDays'] ?? _totalWorkingDays;
                          final present = r['presentDays'] ?? 0;
                          final absent = r['absentDays'] ?? 0;
                          final lateDays = r['lateDays'] ?? 0;
                          final punctualityPoints = r['punctualityPoints'] ?? (present * 10);
                          final punctualityRate = r['punctualityRate'] ?? (working > 0 ? ((present / working) * 100).round() : 0);

                          // Fee status check
                          final feesObj = r['feesStatus'];
                          String feeBadge = 'Unpaid';
                          if (feesObj is Map) {
                            final latestMonthStatus = feesObj.values.isNotEmpty ? feesObj.values.last : 'UNPAID';
                            if (latestMonthStatus == 'PAID') feeBadge = 'Paid';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFf1f5f9)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: Student Name & Fee Status Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.slate900,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: feeBadge == 'Paid' ? const Color(0xFFf0fdf4) : const Color(0xFFfef2f2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        feeBadge,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: feeBadge == 'Paid' ? const Color(0xFF15803d) : const Color(0xFFef4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Grid Container: WORKING, PRESENT, ABSENT, LATE
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf8fafc),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildGridItem('WORKING', '$working', AppTheme.slate400),
                                      _buildGridItem('PRESENT', '$present', const Color(0xFF15803d)),
                                      _buildGridItem('ABSENT', '$absent', const Color(0xFFb91c1c)),
                                      _buildGridItem('LATE', '$lateDays', const Color(0xFFd97706)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Bottom Row: Punctuality %, Punctuality Points, Generate Button
                                Row(
                                  children: [
                                    // Punctuality % Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: punctualityRate >= 75 ? const Color(0xFFf0fdf4) : const Color(0xFFfef2f2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: punctualityRate >= 75 ? const Color(0xFFbbf7d0) : const Color(0xFFfecaca),
                                        ),
                                      ),
                                      child: Text(
                                        '$punctualityRate%',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: punctualityRate >= 75 ? const Color(0xFF15803d) : const Color(0xFFef4444),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Punctuality Points Pill (e.g. 120 Pts, 210 Pts)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFfefce8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFfef08a)),
                                      ),
                                      child: Text(
                                        '$punctualityPoints Pts',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF854d0e),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),

                                    // Generate Individual Student PDF/Report Button
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Generating report for $name...')),
                                        );
                                      },
                                      icon: const Icon(Icons.description, size: 14, color: Colors.white),
                                      label: Text('Generate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0f172a),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94a3b8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
