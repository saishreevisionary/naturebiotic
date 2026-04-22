import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/features/expenses/screens/expense_detail_screen.dart';

class ManagerExpenseControl extends StatefulWidget {
  const ManagerExpenseControl({super.key});

  @override
  State<ManagerExpenseControl> createState() => _ManagerExpenseControlState();
}

class _ManagerExpenseControlState extends State<ManagerExpenseControl> {
  List<Map<String, dynamic>> _executives = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getExecutives(),
        SupabaseService.getExpenseHistory(),
      ]);
      if (mounted) {
        setState(() {
          _executives = results[0];
          _history = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading manager expenses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pendingReturns =
        _history.where((e) => e['return_status'] == 'PENDING').toList();
    final activeTrips = _history.where((e) => e['status'] == 'ACTIVE').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expense Oversight'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Management'), Tab(text: 'History')],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
          ),
        ),
        body: TabBarView(
          children: [
            _buildManagementTab(pendingReturns, activeTrips),
            _buildHistoryTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAllotmentDialog,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_card_rounded, color: Colors.white),
          label: const Text(
            'Allot Funds',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementTab(
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active,
  ) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('Pending Approvals', Icons.pending_actions_rounded),
          const SizedBox(height: 12),
          ...pending.map((e) => _itemReturnCard(e)),
          const SizedBox(height: 32),
        ],
        _sectionHeader('Active Trips', Icons.local_shipping_rounded),
        const SizedBox(height: 12),
        if (active.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No active trips currently',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
          )
        else
          ...active.map((e) => _itemActiveTripCard(e)),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final e = _history[index];
        final name = e['profiles']?['full_name'] ?? 'Unknown';
        final date = DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.parse(e['created_at']));
        final status = e['status'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpenseDetailScreen(expense: e),
                ),
              );
            },
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('₹${e['amount_allotted']} • $date'),
            trailing: _statusChip(status, e['return_status']),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _itemReturnCard(Map<String, dynamic> e) {
    final name = e['profiles']?['full_name'] ?? 'Executive';
    final amount = e['return_amount'];

    return Card(
      color: Colors.orange.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(
                    Icons.assignment_return_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Submitted ₹$amount for return'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {}, // Optional: View Details
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () async {
                      await SupabaseService.approveReturn(e['id']);
                      _loadData();
                    },
                    child: const Text(
                      'Approve',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemActiveTripCard(Map<String, dynamic> e) {
    final name = e['profiles']?['full_name'] ?? 'Executive';
    final status =
        e['allotment_status'] == 'PENDING'
            ? 'Awaiting Receipt'
            : 'Trip in Progress';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.secondary,
          child: Icon(Icons.person_rounded, color: AppColors.primary),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(status),
        trailing: Text(
          '₹${e['amount_allotted']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  void _showAllotmentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => _AllotmentDialogContent(
            executives: _executives,
            onAllot: (executiveId, amount) async {
              await SupabaseService.allotExpenseFunds(executiveId, amount);
              _loadData();
            },
          ),
    );
  }

  Widget _statusChip(String status, String returnStatus) {
    String label = status;
    Color color = Colors.grey;

    if (status == 'ACTIVE') {
      label = 'Active';
      color = Colors.green;
    } else if (status == 'CLOSED') {
      label = 'Closed';
      color = Colors.blue;
    }

    if (returnStatus == 'PENDING') {
      label = 'Return Pending';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AllotmentDialogContent extends StatefulWidget {
  final List<Map<String, dynamic>> executives;
  final Function(String, double) onAllot;

  const _AllotmentDialogContent({
    required this.executives,
    required this.onAllot,
  });

  @override
  State<_AllotmentDialogContent> createState() =>
      _AllotmentDialogContentState();
}

class _AllotmentDialogContentState extends State<_AllotmentDialogContent> {
  String? _selectedExecutive;
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit =
        _selectedExecutive != null &&
        _amountController.text.isNotEmpty &&
        !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Allot Funds',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _selectedExecutive,
            decoration: const InputDecoration(
              labelText: 'Select Executive',
              border: OutlineInputBorder(),
            ),
            items:
                widget.executives
                    .map(
                      (ex) => DropdownMenuItem(
                        value: ex['id'].toString(),
                        child: Text(ex['full_name'] ?? 'Unknown'),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _selectedExecutive = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() {}),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
              onPressed:
                  canSubmit
                      ? () async {
                        setState(() => _isSubmitting = true);
                        try {
                          final amount = double.parse(_amountController.text);
                          await widget.onAllot(_selectedExecutive!, amount);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Funds allotted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => _isSubmitting = false);
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Error Details'),
                                    content: SingleChildScrollView(
                                      child: Text(e.toString()),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                            );
                          }
                        }
                      }
                      : null,
              child:
                  _isSubmitting
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        'Allot Funds',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
