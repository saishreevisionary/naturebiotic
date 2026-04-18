import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class ExecutiveStockAcceptanceScreen extends StatefulWidget {
  const ExecutiveStockAcceptanceScreen({super.key});

  @override
  State<ExecutiveStockAcceptanceScreen> createState() => _ExecutiveStockAcceptanceScreenState();
}

class _ExecutiveStockAcceptanceScreenState extends State<ExecutiveStockAcceptanceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final pending = await SupabaseService.getPendingStoreTransactions();
      if (mounted) {
        setState(() {
          _pendingTransactions = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcceptance(String id, bool accept) async {
    final status = accept ? 'ACCEPTED' : 'REJECTED';
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      await SupabaseService.updateStoreTransactionStatus(id, status);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock ${status.toLowerCase()} successfully')),
        );
        _loadPending();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pending Handovers'),
        actions: [
          IconButton(onPressed: _loadPending, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _pendingTransactions.isEmpty 
              ? _buildEmptyState()
              : _buildPendingList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppColors.textGray.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('All caught up!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text('No pending stock approvals found.', style: TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingTransactions.length,
      itemBuilder: (context, index) {
        final tx = _pendingTransactions[index];
        final isDelivery = tx['transaction_type'] == 'DELIVERY';
        final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
        final dateStr = DateFormat('dd MMM, hh:mm a').format(date);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDelivery ? Colors.orange.withOpacity(0.2) : Colors.purple.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _typeBadge(isDelivery ? 'STORE DELIVERY' : 'RETURN TO STORE', isDelivery ? Colors.orange : Colors.purple),
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  tx['item_name'] ?? 'Unknown Item',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Quantity: ${tx['quantity']} ${tx['unit']}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _handleAcceptance(tx['id'], false),
                        child: const Text('Reject', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAcceptance(tx['id'], true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('Accept Stock'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _typeBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
