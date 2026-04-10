import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class ReportGeneratorScreen extends StatefulWidget {
  final Map<String, dynamic>? report;
  final String? farmName;
  final String? cropName;
  final String? farmerName;

  const ReportGeneratorScreen({
    super.key, 
    this.report,
    this.farmName,
    this.cropName,
    this.farmerName,
  });

  @override
  State<ReportGeneratorScreen> createState() => _ReportGeneratorScreenState();
}

class _ReportGeneratorScreenState extends State<ReportGeneratorScreen> {
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final farmId = widget.report?['farm_id'];
    if (farmId == null) return;

    setState(() => _isLoadingHistory = true);
    try {
      final allReports = await SupabaseService.getReportsForFarm(farmId.toString());
      
      // Filter history to show only reports from the same farm, 
      // excluding the current one and any future ones (if viewing an old report)
      final currentCreatedAt = widget.report?['created_at'];
      final currentDate = currentCreatedAt != null 
          ? DateTime.parse(currentCreatedAt.toString()) 
          : DateTime.now();
      
      final currentId = widget.report?['id'];
      
      setState(() {
        _history = allReports.where((r) {
          if (currentId != null && r['id'] == currentId) return false;
          final rDate = DateTime.parse(r['created_at'].toString());
          return rDate.isBefore(currentDate);
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading report history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Today';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return 'Today';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final currentHistory = widget.report?['previous_inputs'] ?? '';
    
    // Aggregate all history entries into a formatted string for the PDF
    String combinedHistory = currentHistory;
    if (_history.isNotEmpty) {
      combinedHistory += '\n\nHistorical Records:';
      for (var h in _history) {
        final hDate = _formatDate(h['created_at']);
        final hInputs = h['previous_inputs'] ?? 'No data';
        combinedHistory += '\n--- $hDate ---\n$hInputs';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 60, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Analysis Complete',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Generated on ${_formatDate(widget.report?['created_at'])}',
                    style: const TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _reportSection(
              title: 'Problem Identified',
              content: widget.report?['problem'] ?? 'No problem description provided.',
              icon: Icons.bug_report_rounded,
            ),
            const SizedBox(height: 20),
            _buildHistorySection(currentHistory),
            const SizedBox(height: 20),
            _reportSection(
              title: 'Recommended Products',
              content: widget.report?['recommendations'] ?? 'No recommendations yet.',
              icon: Icons.shopping_bag_rounded,
              isList: true,
            ),
            const SizedBox(height: 20),
            _reportSection(
              title: 'Estimated Cost',
              content: 'Total Budget: ${widget.report?['estimated_cost'] ?? '0.00'}',
              icon: Icons.payments_rounded,
              accent: true,
            ),
            const SizedBox(height: 20),
            if (widget.report?['signature_url'] != null)
              _reportSection(
                title: 'Executive Signature',
                content: '',
                icon: Icons.gesture_rounded,
                customContent: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                  ),
                  child: Image.network(
                    widget.report!['signature_url'],
                    height: 100,
                    width: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),
                  ),
                ),
              ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () async {
                if (widget.report == null) return;
                
                // Construct a modified report map that includes the combined history for the PDF
                final reportForPdf = Map<String, dynamic>.from(widget.report!);
                reportForPdf['previous_inputs'] = combinedHistory;

                await PdfService.generateAndShare(
                  report: reportForPdf,
                  farmName: widget.farmName ?? 'Unknown Farm',
                  cropName: widget.cropName ?? 'Unknown Crop',
                  farmerName: widget.farmerName ?? 'Valued Farmer',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_rounded),
                  SizedBox(width: 12),
                  Text('Export PDF Report'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Finish & Return Home'),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(String currentHistory) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(
                'Previous Inputs History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentHistory.isEmpty ? 'No data provided in current report.' : currentHistory,
            style: TextStyle(fontSize: 14, color: AppColors.textBlack.withOpacity(0.8), height: 1.5),
          ),
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_history.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            const Text(
              'Historical Logs',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _history.map((h) {
                return Container(
                  width: 250, // Fixed width for each history card
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(h['created_at']),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        h['previous_inputs'] ?? 'No data',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reportSection({
    required String title,
    required String content,
    required IconData icon,
    bool isList = false,
    bool accent = false,
    Widget? customContent,
  }) {
    List<Widget> contentWidgets = [];

    if (title == 'Problem Identified') {
      final parts = content.split(', ');
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent ? AppColors.primary.withOpacity(0.05) : AppColors.secondary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: accent ? Border.all(color: AppColors.primary.withOpacity(0.2)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: parts.map((part) {
                if (part.contains('{img:')) {
                  final problemName = part.split('{img:')[0].trim();
                  final imageUrl = part.split('{img:')[1].replaceAll('}', '').trim();
                  return Container(
                    width: 250, // Fixed width to allow wrapping
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(problemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            height: 150,
                            width: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              width: 250,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(part, style: const TextStyle(fontSize: 14)),
                  );
                }
              }).toList(),
            ),
          ],
        ),
      );
    }
 else {
      contentWidgets.add(
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textBlack.withOpacity(0.8),
            height: 1.5,
            fontWeight: accent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent ? AppColors.primary.withOpacity(0.05) : AppColors.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: accent ? Border.all(color: AppColors.primary.withOpacity(0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (customContent != null) customContent else ...contentWidgets,
        ],
      ),
    );
  }
}
