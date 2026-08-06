import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class FeesTab extends StatefulWidget {
  final String tenantId;
  const FeesTab({super.key, required this.tenantId});

  @override
  State<FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<FeesTab> {
  List<dynamic> _students = [];
  List<dynamic> _batches = [];
  String _selectedBatch = '';
  int _selectedMonth = DateTime.now().month;
  bool _isLoading = true;

  final _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.tenantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final batches = await ApiService.getBatches(widget.tenantId);
      final students = await ApiService.getStudents(widget.tenantId);
      if (mounted) {
        setState(() {
          _batches = batches is List ? batches : [];
          _students = students is List ? students : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredStudents {
    if (_selectedBatch.isEmpty) return _students;
    return _students.where((s) => s['batch_id']?.toString() == _selectedBatch).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Batch filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<String>(
            value: _selectedBatch.isEmpty ? null : _selectedBatch,
            decoration: InputDecoration(
              labelText: 'Filter by Batch',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true, fillColor: Colors.white,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Batches')),
              ..._batches.map((b) => DropdownMenuItem<String>(
                value: b['batch_id']?.toString() ?? '',
                child: Text(b['name'] ?? ''),
              )),
            ],
            onChanged: (v) => setState(() => _selectedBatch = v ?? ''),
          ),
        ),

        // Month selector
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 12,
            itemBuilder: (context, index) {
              final isSelected = (index + 1) == _selectedMonth;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMonth = index + 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.emerald500 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.emerald500 : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      _months[index],
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isSelected ? Colors.white : AppTheme.slate900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Student fee list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
              : _filteredStudents.isEmpty
                  ? Center(
                      child: Text('No students found', style: GoogleFonts.inter(color: AppTheme.slate400)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final name = student['name'] ?? 'Unknown';
                        final fee = student['monthly_fee']?.toString() ?? '0';
                        // Simulated paid/pending status
                        final isPaid = index % 3 != 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.emerald50,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.emerald700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text('₹$fee / month', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate400)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? const Color(0xFF10b981).withValues(alpha: 0.1)
                                      : const Color(0xFFef4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPaid ? 'Paid' : 'Pending',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isPaid ? const Color(0xFF10b981) : const Color(0xFFef4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
