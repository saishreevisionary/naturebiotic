import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/inventory/screens/stock_transaction_form.dart';
import 'package:nature_biotic/features/inventory/screens/executive_stock_acceptance_screen.dart';
import 'package:nature_biotic/features/inventory/screens/executive_stock_detail_screen.dart';

class StoreStockScreen extends StatefulWidget {
  const StoreStockScreen({super.key});

  @override
  State<StoreStockScreen> createState() => _StoreStockScreenState();
}

class _StoreStockScreenState extends State<StoreStockScreen> {
  bool _isLoading = true;
  int _pendingCount = 0;
  Map<String, double> _stockInHand = {};
  String _userRole = 'executive';
  String _userName = 'User';
  List<Map<String, dynamic>> _usageHistory = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _executives = [];
  Map<String, double> _executiveStockTotals = {};

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      _userRole = profile?['role'] ?? 'executive';
      _userName = profile?['full_name'] ?? 'User';

      if (_userRole == 'executive') {
        final stock = await SupabaseService.getExecutiveStock();
        final usage = await SupabaseService.getExecutiveStockUsage();
        final pending = await SupabaseService.getPendingStoreTransactions();
        
        if (mounted) {
          setState(() {
            _stockInHand = stock;
            _usageHistory = usage;
            _pendingCount = pending.length;
            _isLoading = false;
          });
        }
      } else {
        final pending = await SupabaseService.getPendingStoreTransactions();
        final stock = await SupabaseService.getUnifiedStoreStock();
        final transactions = await SupabaseService.getStoreTransactions();
        
        List<Map<String, dynamic>> executives = [];
        Map<String, double> execStockTotals = {};
        
        if (_userRole == 'admin' || _userRole == 'store') {
          executives = await SupabaseService.getExecutives();
          // Pre-calculate stock totals for each executive to show in the list
          for (var exec in executives) {
            final execStock = await SupabaseService.getExecutiveStock(userId: exec['id']);
            double total = 0;
            execStock.forEach((key, value) => total += value);
            execStockTotals[exec['id']] = total;
          }
        }
        
        if (mounted) {
          setState(() {
            _pendingCount = pending.length;
            _stockInHand = stock;
            _allTransactions = transactions;
            _executives = executives;
            _executiveStockTotals = execStockTotals;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  List<MapEntry<String, double>> _getLowStockItems() {
    if (_stockInHand == null) return [];
    return _stockInHand.entries.where((e) => (e.value ?? 0.0) < 10).toList();
  }

  void _openTransactionForm(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockTransactionForm(transactionType: type),
      ),
    ).then((_) => _refreshData());
  }

  void _openAcceptanceScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExecutiveStockAcceptanceScreen(),
      ),
    ).then((_) => _refreshData());
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _getLowStockItems();

    if (_userRole == 'executive') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Stock'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textBlack,
          actions: [
            IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: CustomScrollView(
                  slivers: [
                    if (_pendingCount > 0) SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _buildPendingAlert(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Actions',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _compactActionCard('Return', Icons.keyboard_return_rounded, Colors.purple, () => _openTransactionForm('RETURN')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stock in Your Hand',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    _buildInventoryList(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Analytics (Recent Usage)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            if (_usageHistory.isEmpty)
                              const Center(child: Text('No usage recorded yet.'))
                            else
                              ..._usageHistory.map((u) => _buildUsageItem(u)),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  _buildHero(),
                  SliverToBoxAdapter(
                    child: TabBar(
                      isScrollable: false,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textGray,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: [
                        const Tab(text: 'Store Stock'),
                        const Tab(text: 'Purchase'),
                        const Tab(text: 'Executive'),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _buildStoreStockTab(lowStock),
                    _buildPurchaseHistoryTab(),
                    _buildExecutiveStockTab(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStoreStockTab(List<MapEntry<String, double>> lowStock) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          if (_pendingCount > 0) SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _buildPendingAlert(),
            ),
          ),
          if (lowStock.isNotEmpty) SliverToBoxAdapter(
            child: _buildLowStockAlerts(lowStock),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _compactActionCard('Purchase', Icons.add_shopping_cart_rounded, Colors.blue, () => _openTransactionForm('PURCHASE')),
                      const SizedBox(width: 16),
                      _compactActionCard('Delivery', Icons.local_shipping_rounded, Colors.orange, () => _openTransactionForm('DELIVERY')),
                      const SizedBox(width: 16),
                      _compactActionCard('Return', Icons.keyboard_return_rounded, Colors.purple, () => _openTransactionForm('RETURN')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stock in Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_stockInHand?.length ?? 0} Items',
                    style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          _buildInventoryList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildPurchaseHistoryTab() {
    final transactions = _allTransactions ?? [];
    final purchases = transactions.where((t) => t['transaction_type'] == 'PURCHASE').toList();
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: purchases.length,
        itemBuilder: (context, index) {
          final tx = purchases[index];
          return _buildTransactionHistoryCard(tx);
        },
      ),
    );
  }

  Widget _buildExecutiveStockTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _executives.isEmpty 
        ? const Center(child: Text('No executives found'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _executives.length,
            itemBuilder: (context, index) {
              final exec = _executives[index];
              final totalStock = _executiveStockTotals[exec['id']] ?? 0.0;
              
              return EntranceAnimation(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        exec['full_name']?[0] ?? 'E',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      exec['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Total Units in Hand: $totalStock'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExecutiveStockDetailScreen(
                            executiveId: exec['id'],
                            executiveName: exec['full_name'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildTransactionHistoryCard(Map<String, dynamic> tx) {
    final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
    
    return EntranceAnimation(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx['item_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textGray, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+${tx['quantity']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(tx['unit'] ?? 'Units', style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return SliverAppBar(
      expandedHeight: 200,
      backgroundColor: AppColors.primary,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                AppColors.primary.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.inventory_2_rounded, size: 180, color: Colors.white.withOpacity(0.1)),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()},',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                    ),
                    Text(
                      (_userName?.isEmpty ?? true) ? 'User' : _userName.split(' ')[0],
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    if (_userRole != 'executive') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _heroStat('Total Stock', (_stockInHand?.length ?? 0).toString()),
                          const SizedBox(width: 24),
                          _heroStat('Low Stock', _getLowStockItems().length.toString()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
      ],
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLowStockAlerts(List<MapEntry<String, double>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            'Low Stock Alerts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${item.value} units left', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _compactActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_stockInHand == null || _stockInHand.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No stock recorded yet.')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final key = _stockInHand.keys.elementAt(index);
            final qty = _stockInHand[key]!;
            final isLow = qty < 10;

            return EntranceAnimation(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isLow ? Colors.red.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                        color: isLow ? Colors.red : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Available Stock', style: TextStyle(color: AppColors.textGray.withOpacity(0.7), fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$qty', style: TextStyle(color: isLow ? Colors.red : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                        const Text('Units', style: TextStyle(color: AppColors.textGray, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: _stockInHand.length,
        ),
      ),
    );
  }

  Widget _buildPendingAlert() {
    return EntranceAnimation(
      child: GestureDetector(
        onTap: _openAcceptanceScreen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notification_important_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_pendingCount Pending Handovers',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const Text(
                      'You have stock waiting for your acceptance.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return EntranceAnimation(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGray.withOpacity(0.7), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInventorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stock in Hand', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Showing verified available items in store.', style: TextStyle(color: AppColors.textGray)),
            const SizedBox(height: 24),
            Expanded(
              child: (_stockInHand == null || _stockInHand.isEmpty) 
                  ? const Center(child: Text('No stock recorded yet.'))
                  : ListView.builder(
                      itemCount: _stockInHand.length,
                      itemBuilder: (context, index) {
                        final key = _stockInHand.keys.elementAt(index);
                        final qty = _stockInHand[key];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('$qty Units', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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

  Widget _buildUsageItem(Map<String, dynamic> usage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.outbox_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usage['item_name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Used at: ${usage['farms']?['name'] ?? 'Unknown Farm'}', style: TextStyle(color: AppColors.textGray, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-${usage['quantity']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              Text(usage['unit'] ?? 'Units', style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
            ],
          ),
        ],
      ),
    );
  }
}
