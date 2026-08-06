import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class BatchesTab extends StatefulWidget {
  final String tenantId;
  const BatchesTab({super.key, required this.tenantId});

  @override
  State<BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<BatchesTab> {
  List<dynamic> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    if (widget.tenantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getBatches(widget.tenantId);
      if (mounted) {
        setState(() {
          _batches = data is List ? data : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddBatchDialog() {
    final nameCtrl = TextEditingController();
    final batchIdCtrl = TextEditingController();

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
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add New Batch', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: batchIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Batch ID',
                  prefixIcon: const Icon(Icons.tag, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Batch Name *',
                  prefixIcon: const Icon(Icons.groups, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await ApiService.createBatch(widget.tenantId, {
                        'batch_id': batchIdCtrl.text.trim(),
                        'name': nameCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadBatches();
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Save Batch', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
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
                  color: AppTheme.emerald500,
                  onRefresh: _loadBatches,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _batches.length,
                    itemBuilder: (context, index) {
                      final b = _batches[index];
                      final name = b['name'] ?? 'Batch ${index + 1}';
                      final batchId = b['batch_id']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.gold50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.groups, color: AppTheme.gold600, size: 22),
                          ),
                          title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text('ID: $batchId', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.slate400)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                            onPressed: () async {
                              if (batchId.isNotEmpty) {
                                await ApiService.deleteBatch(widget.tenantId, batchId);
                                _loadBatches();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBatchDialog,
        backgroundColor: AppTheme.emerald500,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
