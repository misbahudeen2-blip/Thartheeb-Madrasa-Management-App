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
  Map<String, String> _attendanceStatus = {}; // studentId -> status
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadBatches();
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
      if (mounted) {
        final students = (data is List ? data : [])
            .where((s) => s['batch_id']?.toString() == _selectedBatch)
            .toList();
        setState(() {
          _students = students;
          _attendanceStatus = {};
          for (var s in students) {
            _attendanceStatus[s['id'].toString()] = 'present';
          }
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
      final records = _attendanceStatus.entries.map((e) => {
        'student_id': e.key,
        'status': e.value,
      }).toList();

      await ApiService.submitManualAttendance(
        widget.tenantId,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
        _selectedBatch,
        records,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance submitted successfully!'),
            backgroundColor: const Color(0xFF10b981),
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
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF10b981);
      case 'late': return const Color(0xFFf59e0b);
      case 'absent': return const Color(0xFFef4444);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date picker row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDate(-1),
              ),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Text(
                  DateFormat('EEEE, MMM d, y').format(_selectedDate),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.slate900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _selectedDate.isBefore(DateTime.now())
                    ? () => _changeDate(1)
                    : null,
              ),
            ],
          ),
        ),

        // Batch selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            value: _selectedBatch.isEmpty ? null : _selectedBatch,
            decoration: InputDecoration(
              labelText: 'Select Batch',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _batches.map((b) {
              return DropdownMenuItem<String>(
                value: b['batch_id']?.toString() ?? '',
                child: Text(b['name'] ?? b['batch_id']?.toString() ?? ''),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => _selectedBatch = v ?? '');
              _loadStudentsForBatch();
            },
          ),
        ),

        // Student attendance list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
              : _students.isEmpty
                  ? Center(
                      child: Text(
                        'No students in this batch',
                        style: GoogleFonts.inter(color: AppTheme.slate400),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final id = student['id'].toString();
                        final name = student['name'] ?? 'Unknown';
                        final status = _attendanceStatus[id] ?? 'present';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ..._buildStatusToggles(id, status),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // Submit button
        if (_students.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'Submit Attendance',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildStatusToggles(String studentId, String currentStatus) {
    final statuses = ['present', 'late', 'absent'];
    final labels = ['P', 'L', 'A'];
    return List.generate(3, (i) {
      final isSelected = currentStatus == statuses[i];
      final color = _statusColor(statuses[i]);
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: () {
            setState(() => _attendanceStatus[studentId] = statuses[i]);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                labels[i],
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
