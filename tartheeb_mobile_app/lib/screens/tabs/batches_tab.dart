import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'attendance_tab.dart';

class BatchesTab extends StatefulWidget {
  final String tenantId;
  const BatchesTab({super.key, required this.tenantId});

  @override
  State<BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<BatchesTab> {
  List<dynamic> _batches = [];
  List<dynamic> _shifts = [];
  List<dynamic> _allStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant BatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId && widget.tenantId.isNotEmpty) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (widget.tenantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final batchData = await ApiService.getBatches(widget.tenantId);
      final shiftData = await ApiService.getShifts(widget.tenantId);
      final studentData = await ApiService.getStudents(widget.tenantId);

      if (mounted) {
        setState(() {
          _batches = batchData is List ? batchData : [];
          _shifts = shiftData is List ? shiftData : [];
          _allStudents = studentData is List ? studentData : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditBatchDialog([Map<String, dynamic>? existingBatch]) {
    final isEditing = existingBatch != null;
    final nameCtrl = TextEditingController(text: isEditing ? (existingBatch['batch_name'] ?? existingBatch['name'] ?? '') : '');
    final batchIdCtrl = TextEditingController(text: isEditing ? (existingBatch['batch_id']?.toString() ?? '') : '');
    String selectedShiftId = isEditing ? (existingBatch['shift_id']?.toString() ?? '') : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEditing ? 'Edit Batch' : 'Add New Batch',
                style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.slate900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: batchIdCtrl,
                enabled: !isEditing,
                decoration: InputDecoration(
                  labelText: 'Batch ID *',
                  prefixIcon: const Icon(Icons.tag, size: 20, color: AppTheme.emerald700),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isEditing ? Colors.grey.shade100 : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Batch Name * (e.g. CLASS 2 A)',
                  prefixIcon: const Icon(Icons.groups, size: 20, color: AppTheme.emerald700),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedShiftId.isEmpty ? null : selectedShiftId,
                decoration: InputDecoration(
                  labelText: 'Assigned Shift',
                  prefixIcon: const Icon(Icons.access_time, size: 20, color: AppTheme.emerald700),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _shifts.map((s) {
                  final shiftName = s['shift_name'] ?? s['name'] ?? 'Shift';
                  final times = s['start_time'] != null ? '${s['start_time']}-${s['end_time'] ?? ''}' : '';
                  return DropdownMenuItem<String>(
                    value: s['shift_id']?.toString() ?? '',
                    child: Text('$shiftName $times', style: GoogleFonts.inter(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) => selectedShiftId = v ?? '',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || batchIdCtrl.text.trim().isEmpty) return;
                    try {
                      await ApiService.createBatch(widget.tenantId, {
                        'batch_id': batchIdCtrl.text.trim(),
                        'batch_name': nameCtrl.text.trim(),
                        'shift_id': selectedShiftId,
                        if (isEditing) 'old_batch_id': existingBatch['batch_id']?.toString(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isEditing ? 'Update Batch' : 'Save Batch',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showBatchStudentsModal(dynamic b) {
    final batchId = b['batch_id']?.toString() ?? '';
    final batchName = b['batch_name'] ?? b['name'] ?? 'Batch Students';
    final studentsInBatch = _allStudents.where((s) => s['batch_id']?.toString() == batchId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$batchName - Students List',
                        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                      ),
                      Text(
                        'Total Enrolled: ${studentsInBatch.length} Students',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate400),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: studentsInBatch.isEmpty
                  ? Center(
                      child: Text('No students assigned to this batch.', style: GoogleFonts.inter(color: AppTheme.slate400)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: studentsInBatch.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final s = studentsInBatch[index];
                        final name = s['name'] ?? 'Unknown';
                        final roll = s['roll_number']?.toString() ?? '-';
                        final card = s['card_number']?.toString() ?? '-';
                        final phone = s['primary_number'] ?? s['phone'] ?? '-';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.emerald700.withValues(alpha: 0.1),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.emerald700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('Roll: $roll | Card: $card', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.slate400)),
                                  ],
                                ),
                              ),
                              if (phone != '-')
                                Text(
                                  phone,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.emerald700),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchReportModal(dynamic b) async {
    final batchId = b['batch_id']?.toString() ?? '';
    final batchName = b['batch_name'] ?? b['name'] ?? 'Batch';
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$batchName - Daily Report', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: FutureBuilder<dynamic>(
          future: ApiService.getAttendance(widget.tenantId, todayStr),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(color: AppTheme.emerald700)),
              );
            }
            final attData = snapshot.data;
            final records = (attData is Map ? attData['records'] : []) as List? ?? [];
            final batchRecords = records.where((r) => r['batchName'] == batchName).toList();
            final present = batchRecords.where((r) => r['status'] == 'Present' || r['status'] == 'Late').length;
            final absent = batchRecords.where((r) => r['status'] == 'Absent').length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: $todayStr', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReportStat('Total', batchRecords.length, Colors.blue),
                    _buildReportStat('Present', present, Colors.green),
                    _buildReportStat('Absent', absent, Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Compliance Summary:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  batchRecords.isEmpty
                      ? 'No attendance logs recorded for this batch today.'
                      : '${((present / (batchRecords.isEmpty ? 1 : batchRecords.length)) * 100).toStringAsFixed(1)}% Present today',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate900),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(color: AppTheme.emerald700)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.slate400)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header matching Web screenshot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              color: Colors.white,
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.slate900),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Management',
                          style: GoogleFonts.cairo(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate900,
                          ),
                        ),
                        Text(
                          'Create and manage class batches',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditBatchDialog(),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: Text(
                      'Add Batch',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF798720),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFe2e8f0)),

            // Batch List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald700))
                  : _batches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No batches found', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 16)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.emerald700,
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _batches.length,
                            itemBuilder: (context, index) {
                              final b = _batches[index];
                              final batchId = b['batch_id']?.toString() ?? '';
                              final batchName = (b['batch_name'] ?? b['name'] ?? batchId).toString().toUpperCase();
                              final shiftName = b['shift_name'] ?? 'Morning';
                              final startTime = b['start_time'] ?? '06:30';
                              final endTime = b['end_time'] ?? '07:45';
                              final shiftTiming = '$shiftName $startTime-$endTime';
                              final teacherName = b['teacher_name'] ?? 'None';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                    // Row 1: Batch Name & Shift Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          batchName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppTheme.slate900,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFf1f5f9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            shiftTiming,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748b),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 2: Assigned Teacher
                                    Text(
                                      'Assigned Teacher: $teacherName',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF64748b),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Row 3: Action Icons Row at Bottom Right
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // 1. 👥 View Batch Students
                                        IconButton(
                                          icon: const Icon(Icons.groups_rounded, color: Color(0xFF3b82f6), size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          tooltip: 'View Students',
                                          onPressed: () => _showBatchStudentsModal(b),
                                        ),

                                        // 2. ✏️ Edit Batch
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: Color(0xFFf59e0b), size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          tooltip: 'Edit Batch',
                                          onPressed: () => _showAddEditBatchDialog(b),
                                        ),

                                        // 3. 📄 Batch Report
                                        IconButton(
                                          icon: const Icon(Icons.description_rounded, color: Color(0xFF10b981), size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          tooltip: 'Batch Report',
                                          onPressed: () => _showBatchReportModal(b),
                                        ),

                                        // 4. ✔️ Quick Attendance
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF6366f1), size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          tooltip: 'Attendance',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AttendanceTab(tenantId: widget.tenantId),
                                              ),
                                            );
                                          },
                                        ),

                                        // 5. 🗑️ Delete Batch
                                        IconButton(
                                          icon: const Icon(Icons.delete_rounded, color: Color(0xFFef4444), size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          tooltip: 'Delete Batch',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Batch'),
                                                content: Text('Are you sure you want to delete $batchName?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true && batchId.isNotEmpty) {
                                              await ApiService.deleteBatch(widget.tenantId, batchId);
                                              _loadData();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
