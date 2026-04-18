import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farms/screens/stock_management_screen.dart';
import 'package:intl/intl.dart';

class FarmSalesListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialTransactions;
  final List<Map<String, dynamic>> allProducts;

  const FarmSalesListScreen({
    super.key, 
    required this.initialTransactions,
    required this.allProducts,
  });

  @override
  State<FarmSalesListScreen> createState() => _FarmSalesListScreenState();
}

class _FarmSalesListScreenState extends State<FarmSalesListScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  Map<String, Map<String, dynamic>> _farmSales = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  void _processData() {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var tx in widget.initialTransactions) {
      final type = tx['transaction_type'];
      if (type != 'DELIVERED' && type != 'RETURN') continue;

      final farmId = tx['farm_id'].toString();
      final itemName = tx['item_name']?.toString().trim().toLowerCase();
      final unit = tx['unit']?.toString().trim().toLowerCase();
      final qty = double.tryParse(tx['quantity'].toString()) ?? 0.0;

      // Calculate Revenue
      final product = widget.allProducts.firstWhere(
        (p) => p['label']?.toString().trim().toLowerCase() == itemName,
        orElse: () => {},
      );
      final List variants = product['variants'] ?? [];
      final variant = variants.firstWhere(
        (v) => v['label']?.toString().trim().toLowerCase() == unit,
        orElse: () => {},
      );
      
      final price = double.tryParse(variant['offer_price']?.toString() ?? '0') ?? 0.0;
      final amount = price * qty;

      if (!grouped.containsKey(farmId)) {
        grouped[farmId] = {
          'farm_id': farmId,
          'farm_name': 'Loading...',
          'total_revenue': 0.0,
          'total_items': 0.0,
          'total_returned': 0.0,
        };
      }

      if (type == 'DELIVERED') {
        grouped[farmId]!['total_revenue'] += amount;
        grouped[farmId]!['total_items'] += qty;
      } else if (type == 'RETURN') {
        grouped[farmId]!['total_revenue'] -= amount;
        grouped[farmId]!['total_items'] -= qty;
        grouped[farmId]!['total_returned'] += qty;
      }
    }

    setState(() {
      _farmSales = grouped;
      _isLoading = false;
    });
    _loadFarmNames();
  }

  Future<void> _loadFarmNames() async {
    final farms = await SupabaseService.getFarms();
    if (!mounted) return;

    setState(() {
      for (var farm in farms) {
        final id = farm['id'].toString();
        if (_farmSales.containsKey(id)) {
          _farmSales[id]!['farm_name'] = farm['name'] ?? 'Unknown Farm';
          _farmSales[id]!['farmer_name'] = farm['farmers']?['name'] ?? 'No Farmer';
          _farmSales[id]!['location'] = farm['location'] ?? 'No Location';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedFarms = _farmSales.values.toList()
      ..sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales by Farm'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _processData(),
              child: sortedFarms.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: sortedFarms.length,
                      itemBuilder: (context, index) => _buildFarmCard(sortedFarms[index]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textGray),
          SizedBox(height: 16),
          Text('No sales records found for this period', style: TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildFarmCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        shadowColor: AppColors.shadow.withOpacity(0.1),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockManagementScreen(
                  farmId: data['farm_id'],
                  farmName: data['farm_name'],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.agriculture_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['farm_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${data['farmer_name']} • ${data['location']}',
                        style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildMiniBadge(
                            Icons.inventory_2_outlined, 
                            '${data['total_items'].toInt()} Items', 
                            Colors.blueGrey
                          ),
                          if (data['total_returned'] > 0)
                            _buildMiniBadge(
                              Icons.replay_circle_filled_rounded, 
                              '${data['total_returned'].toInt()} Returned', 
                              Colors.redAccent
                            ),
                          _buildMiniBadge(
                            Icons.description_outlined, 
                            'View Challans', 
                            AppColors.primary
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(data['total_revenue']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text('Revenue', style: TextStyle(color: AppColors.textGray, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
