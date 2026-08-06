import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class TeachersTab extends StatefulWidget {
  final String tenantId;
  const TeachersTab({super.key, required this.tenantId});

  @override
  State<TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<TeachersTab> {
  List<dynamic> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    if (widget.tenantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getTeachers(widget.tenantId);
      if (mounted) {
        setState(() {
          _teachers = data is List ? data : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddTeacherDialog() {
    final nameCtrl = TextEditingController();
    final userIdCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(ctx)),
                  Text('Add New Teacher', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('Teacher Name *', nameCtrl, Icons.person),
                    _field('User ID *', userIdCtrl, Icons.badge),
                    _field('Email', emailCtrl, Icons.email, inputType: TextInputType.emailAddress),
                    _field('Password *', passwordCtrl, Icons.lock, obscure: true),
                    _field('Salary', salaryCtrl, Icons.payments, inputType: TextInputType.number),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          try {
                            await ApiService.createTeacher(widget.tenantId, {
                              'name': nameCtrl.text.trim(),
                              'user_id': userIdCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'password': passwordCtrl.text,
                              'salary': salaryCtrl.text.trim(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadTeachers();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Save Teacher', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType inputType = TextInputType.text, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.emerald500, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald500))
          : _teachers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No teachers found', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.emerald500,
                  onRefresh: _loadTeachers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _teachers.length,
                    itemBuilder: (context, index) {
                      final t = _teachers[index];
                      final name = t['name'] ?? 'Unknown';
                      final userId = t['user_id'] ?? '';
                      final email = t['email'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFeff6ff),
                            child: Text(name[0].toUpperCase(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF3b82f6))),
                          ),
                          title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text('ID: $userId • $email', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate400)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                            onPressed: () async {
                              final id = t['id']?.toString() ?? '';
                              if (id.isNotEmpty) {
                                await ApiService.deleteTeacher(widget.tenantId, id);
                                _loadTeachers();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTeacherDialog,
        backgroundColor: AppTheme.emerald500,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
