import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AttendanceTab extends StatefulWidget {
  final String tenantId;
  const AttendanceTab({super.key, required this.tenantId});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  DateTime _selectedDate = DateTime.now();
  String _selectedBatch = '';
  List<dynamic> _batches = [];
  List<dynamic> _students = [];
  Map<String, String> _attendanceStatus = {}; // userId -> status ('present', 'late', 'absent', 'holiday')
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _activeFilter = 'ALL'; // 'ALL', 'present', 'absent', 'holiday'

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void didUpdateWidget(covariant AttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId && widget.tenantId.isNotEmpty) {
      _loadBatches();
    }
  }

  Future<void> _loadBatches() async {
    if (widget.tenantId.isEmpty) return;
    try {
      final data = await ApiService.getBatches(widget.tenantId);
      if (mounted) {
        setState(() {
          _batches = data is List ? data : [];
          if (_batches.isNotEmpty) {
            _selectedBatch = _batches[0]['batch_id']?.toString() ?? '';
            _loadStudentsForBatch();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStudentsForBatch() async {
    if (_selectedBatch.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getStudents(widget.tenantId);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      dynamic attData;
      try {
        attData = await ApiService.getAttendance(widget.tenantId, dateStr);
      } catch (_) {}

      final serverRecords = (attData is Map ? attData['records'] : []) as List? ?? [];

      if (mounted) {
        final students = (data is List ? data : [])
            .where((s) => s['batch_id']?.toString() == _selectedBatch)
            .toList();
        
        final Map<String, String> statusMap = {};
        for (var s in students) {
          final uid = (s['user_id'] ?? s['id'])?.toString() ?? '';
          if (uid.isNotEmpty) {
            final existing = serverRecords.firstWhere(
              (r) => r['userId']?.toString() == uid,
              orElse: () => null,
            );
            if (existing != null && existing['status'] != null) {
              statusMap[uid] = existing['status'].toString().toLowerCase();
            } else {
              statusMap[uid] = 'absent';
            }
          }
        }
        
        setState(() {
          _students = students;
          _attendanceStatus = statusMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAttendance() async {
    setState(() => _isSubmitting = true);
    try {
      final records = _attendanceStatus.entries.map((e) {
        final rawStatus = e.value;
        final formattedStatus = rawStatus.isNotEmpty
            ? rawStatus[0].toUpperCase() + rawStatus.substring(1)
            : 'Absent';
        return {
          'user_id': e.key,
          'status': formattedStatus,
        };
      }).toList();

      await ApiService.submitManualAttendance(
        widget.tenantId,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
        _selectedBatch,
        records,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance submitted successfully!'),
            backgroundColor: Color(0xFF10b981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  int _countStatus(String status) {
    return _attendanceStatus.values.where((s) => s == status).length;
  }

  List<dynamic> get _filteredStudents {
    if (_activeFilter == 'ALL') return _students;
    return _students.where((s) {
      final uid = (s['user_id'] ?? s['id'])?.toString() ?? '';
      return _attendanceStatus[uid] == _activeFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Attendance',
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
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppTheme.slate900),
                  onPressed: () => _changeDate(-1),
                ),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.emerald500),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(_selectedDate),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppTheme.slate900),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          // Batch Selector Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DropdownButtonFormField<String>(
              value: _selectedBatch.isEmpty ? null : _selectedBatch,
              decoration: InputDecoration(
                labelText: 'Select Batch',
                labelStyle: GoogleFonts.inter(color: AppTheme.emerald700, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.emerald500),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.emerald700, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _batches.map((b) {
                final batchName = b['batch_name'] ?? b['name'] ?? b['batch_id']?.toString() ?? '';
                return DropdownMenuItem<String>(
                  value: b['batch_id']?.toString() ?? '',
                  child: Text(
                    batchName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedBatch = v ?? '');
                _loadStudentsForBatch();
              },
            ),
          ),

          // Status Filter Tabs (Present / Absent / Holiday)
          if (_students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterBadge('ALL', 'All (${_students.length})', Colors.grey.shade700, Colors.grey.shade100),
                  const SizedBox(width: 8),
                  _buildFilterBadge('present', '☑ Present (${_countStatus('present')})', const Color(0xFF15803d), const Color(0xFFf0fdf4)),
                  const SizedBox(width: 8),
                  _buildFilterBadge('absent', '☒ Absent (${_countStatus('absent')})', const Color(0xFFb91c1c), const Color(0xFFfef2f2)),
                  const SizedBox(width: 8),
                  _buildFilterBadge('holiday', '🏖 Holiday (${_countStatus('holiday')})', const Color(0xFF1d4ed8), const Color(0xFFeff6ff)),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Student attendance list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          _students.isEmpty ? 'No students in this batch' : 'No students matching filter',
                          style: GoogleFonts.inter(color: AppTheme.slate400),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final userId = (student['user_id'] ?? student['id'])?.toString() ?? '';
                          final name = student['name'] ?? 'Unknown';
                          final rollNumber = student['roll_number']?.toString() ?? '';
                          final status = _attendanceStatus[userId] ?? 'absent';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
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
                                // Student Header Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.slate900,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (rollNumber.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Roll: $rollNumber',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.slate900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            // Handle student deletion if needed
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Full-Text Button Options (Present / Late / Absent / Holiday)
                                Row(
                                  children: [
                                    _buildFullTextButton(userId, 'present', 'Present', const Color(0xFF10b981), const Color(0xFFef4444)),
                                    const SizedBox(width: 6),
                                    _buildFullTextButton(userId, 'late', 'Late', const Color(0xFFf59e0b), const Color(0xFFef4444)),
                                    const SizedBox(width: 6),
                                    _buildFullTextButton(userId, 'absent', 'Absent', const Color(0xFFef4444), const Color(0xFFef4444)),
                                    const SizedBox(width: 6),
                                    _buildFullTextButton(userId, 'holiday', 'Holiday', const Color(0xFF3b82f6), const Color(0xFFef4444)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Submit Button
          if (_students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Submit Attendance',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBadge(String filterValue, String label, Color textColor, Color bgColor) {
    final isSelected = _activeFilter == filterValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = filterValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? textColor : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? textColor : AppTheme.slate400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullTextButton(
    String userId,
    String statusValue,
    String label,
    Color selectedBgColor,
    Color absentColor,
  ) {
    final currentStatus = _attendanceStatus[userId] ?? 'absent';
    final isSelected = currentStatus == statusValue;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _attendanceStatus[userId] = statusValue;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedBgColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? selectedBgColor : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
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
