import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class StudentsTab extends StatefulWidget {
  final String tenantId;
  const StudentsTab({super.key, required this.tenantId});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void didUpdateWidget(covariant StudentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId && widget.tenantId.isNotEmpty) {
      _loadStudents();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (widget.tenantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getStudents(widget.tenantId);
      if (mounted) {
        setState(() {
          _students = data is List ? data : [];
          _filteredStudents = _students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterStudents(String query) {
    if (query.isEmpty) {
      setState(() => _filteredStudents = _students);
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredStudents = _students.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final roll = (s['roll_number'] ?? '').toString().toLowerCase();
          final father = (s['father'] ?? '').toString().toLowerCase();
          return name.contains(q) || roll.contains(q) || father.contains(q);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppTheme.emerald500,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(
          'Add Student',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.emerald500,
        onRefresh: _loadStudents,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _filterStudents,
                decoration: InputDecoration(
                  hintText: 'Search students by name, roll no, father...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.slate400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.emerald500),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterStudents('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // Student List / Empty State / Loading
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined, size: 64, color: AppTheme.slate400.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'No students found',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.slate400,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Try refreshing or adding a new student.',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.slate400),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final name = student['name'] ?? 'Student';
                              final father = student['father'] ?? 'N/A';
                              final batch = student['batch_name'] ?? 'No Batch';
                              final roll = student['roll_number'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.emerald50,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.emerald700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.slate900,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Roll: $roll  •  Father: $father  •  $batch',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.slate400,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
