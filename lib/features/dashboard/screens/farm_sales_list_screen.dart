import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farms/screens/stock_management_screen.dart';
import 'package:intl/intl.dart';

class FarmSalesListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialTransactions;
  final List<Map<String, dynamic>> allProducts;
  final List<Map<String, dynamic>> allFarms;
  final String mode; // 'SALES', 'COLLECTION', 'OUTSTANDING'

  const FarmSalesListScreen({
    super.key, 
    required this.initialTransactions,
    required this.allProducts,
    this.allFarms = const [],
    this.mode = 'SALES',
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
      final type = tx['transaction_type']?.toString().toUpperCase();
      final farmId = tx['farm_id']?.toString();
      if (farmId == null) continue;
      
      if (!grouped.containsKey(farmId)) {
        grouped[farmId] = {
          'farm_id': farmId,
          'farm_name': 'Farm #$farmId',
          'farmer_name': 'Searching...',
          'location': '...',
          'total_revenue': 0.0,
          'total_collection': 0.0,
          'total_items': 0.0,
          'total_returned': 0.0,
        };
      }

      // Calculate Revenue (for SALES and OUTSTANDING)
      if (type == 'RECEIVED' || type == 'RETURN') {
        final itemName = tx['item_name']?.toString().trim().toLowerCase();
        final rawUnit = tx['unit']?.toString().trim().toLowerCase() ?? '';
        final unit = rawUnit.split(' {₹')[0].trim();
        final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;

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

        if (type == 'RECEIVED') {
          grouped[farmId]!['total_revenue'] += amount;
          grouped[farmId]!['total_items'] += qty;
        } else if (type == 'RETURN') {
          grouped[farmId]!['total_revenue'] -= amount;
          grouped[farmId]!['total_items'] -= qty;
          grouped[farmId]!['total_returned'] += qty;
        }
      }

      // Calculate Collection (for COLLECTION and OUTSTANDING)
      if (type == 'RECEIVED') {
        double amt = double.tryParse(tx['collected_amount']?.toString() ?? '0') ?? 0.0;
        if (amt == 0 && tx['unit'] != null && tx['unit'].toString().contains('{₹')) {
          try {
            final unitStr = tx['unit'].toString();
            final start = unitStr.indexOf('{₹') + 2;
            final end = unitStr.indexOf('}', start);
            if (end != -1) {
              amt = double.tryParse(unitStr.substring(start, end)) ?? 0.0;
            }
          } catch (_) {}
        }
        grouped[farmId]!['total_collection'] += amt;
      }
    }

    setState(() {
      _farmSales = grouped;
      _isLoading = false;
    });
    
    // First try to resolve from passed allFarms
    if (widget.allFarms.isNotEmpty) {
      _applyFarmData(widget.allFarms);
    }
    
    // Then fetch fresh data
    _loadFarmNames();
  }

  void _applyFarmData(List<Map<String, dynamic>> farms) {
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

  Future<void> _loadFarmNames() async {
    final farms = await SupabaseService.getFarms();
    _applyFarmData(farms);
  }

  @override
  Widget build(BuildContext context) {
    var list = _farmSales.values.toList();
    
    // Filter based on mode
    if (widget.mode == 'SALES') {
      list = list.where((f) => f['total_revenue'] > 0).toList();
      list.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    } else if (widget.mode == 'COLLECTION') {
      list = list.where((f) => f['total_collection'] > 0).toList();
      list.sort((a, b) => (b['total_collection'] as double).compareTo(a['total_collection'] as double));
    } else if (widget.mode == 'OUTSTANDING') {
      list = list.where((f) => (f['total_revenue'] - f['total_collection']).abs() > 0.1).toList();
      list.sort((a, b) => ((b['total_revenue'] - b['total_collection']) as double).compareTo((a['total_revenue'] - a['total_collection']) as double));
    }

    String title = 'Sales by Farm';
    if (widget.mode == 'COLLECTION') title = 'Collections by Farm';
    if (widget.mode == 'OUTSTANDING') title = 'Outstanding by Farm';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _processData(),
              child: list.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: list.length,
                      itemBuilder: (context, index) => _buildFarmCard(list[index]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No sales records found';
    if (widget.mode == 'COLLECTION') message = 'No collections found';
    if (widget.mode == 'OUTSTANDING') message = 'No outstanding balances';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textGray),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildFarmCard(Map<String, dynamic> data) {
    double displayValue = 0;
    String label = '';
    Color valueColor = AppColors.primary;

    if (widget.mode == 'SALES') {
      displayValue = data['total_revenue'];
      label = 'Revenue';
    } else if (widget.mode == 'COLLECTION') {
      displayValue = data['total_collection'];
      label = 'Collected';
      valueColor = Colors.teal;
    } else if (widget.mode == 'OUTSTANDING') {
      displayValue = data['total_revenue'] - data['total_collection'];
      label = 'Outstanding';
      valueColor = Colors.orange;
    }

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
                    color: valueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.mode == 'COLLECTION' ? Icons.payments_rounded : Icons.agriculture_rounded, 
                    color: valueColor
                  ),
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
                        children: [
                          if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING')
                            _buildMiniBadge(
                              Icons.inventory_2_outlined, 
                              '${data['total_items'].toInt()} Items', 
                              Colors.blueGrey
                            ),
                          if (data['total_returned'] > 0 && widget.mode == 'SALES')
                            _buildMiniBadge(
                              Icons.replay_circle_filled_rounded, 
                              '${data['total_returned'].toInt()} Returned', 
                              Colors.redAccent
                            ),
                          _buildMiniBadge(
                            Icons.description_outlined, 
                            'View Details', 
                            valueColor
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
                      currencyFormat.format(displayValue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: valueColor,
                      ),
                    ),
                    Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
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

