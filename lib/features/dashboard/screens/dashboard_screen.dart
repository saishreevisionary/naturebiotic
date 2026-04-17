import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/auth/screens/create_executive_screen.dart';
import 'package:nature_biotic/features/auth/screens/executive_list_screen.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_screen.dart';
import 'package:nature_biotic/features/attendance/screens/leave_request_screen.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_history_screen.dart';
import 'package:nature_biotic/features/attendance/screens/admin_attendance_screen.dart';
import 'package:nature_biotic/features/attendance/screens/admin_leave_approval_screen.dart';
import 'package:nature_biotic/features/calls/screens/executive_dialer_screen.dart';
import 'package:nature_biotic/features/calls/screens/admin_call_logs_screen.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/features/farmers/screens/farmer_list_screen.dart';
import 'package:nature_biotic/features/farms/screens/farm_list_screen.dart';
import 'package:nature_biotic/features/crops/screens/crop_list_screen.dart';
import 'package:nature_biotic/features/reports/screens/reports_list_screen.dart';
import 'package:nature_biotic/features/dashboard/screens/farm_sales_list_screen.dart';
import 'package:nature_biotic/features/auth/screens/login_logs_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isAdmin = false;
  String _userName = 'User';
  String _avatarUrl = '';
  bool _isLoading = true;
  Map<String, dynamic>? _todayAttendance;
  double _totalSalesRevenue = 0.0;
  double _totalReturnValue = 0.0;
  int _totalItemsSold = 0;
  int _totalItemsReturned = 0;
  String _selectedPeriod = 'All Time';
  
  // Stats
  int _farmerCount = 0;
  int _farmCount = 0;
  int _cropCount = 0;
  int _reportCount = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  int _teamPresentCount = 0;
  int _teamAbsentCount = 0;

  // Raw Data for local filtering
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _allFarmers = [];
  List<Map<String, dynamic>> _allFarms = [];
  List<Map<String, dynamic>> _allCrops = [];
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  
  // Scroll & Animation Logic
  late ScrollController _scrollController;
  double _scrollOpacity = 1.0;
  double _scrollScale = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadDashboardData();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    setState(() {
      _scrollOpacity = (1 - (offset / 200)).clamp(0.0, 1.0);
      _scrollScale = (1 - (offset / 1000)).clamp(0.8, 1.0);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      final isAdmin = profile?['role'] == 'admin';
      final attendance = await SupabaseService.getTodayAttendance();
      
      final farmers = await SupabaseService.getFarmers();
      final farms = await SupabaseService.getFarms();
      final crops = await SupabaseService.getAllCrops();
      final reports = await SupabaseService.getReports();
      final transactions = await SupabaseService.getAllStockTransactions();
      final products = await SupabaseService.getHierarchicalDropdownOptions('product_name');
      final activities = await SupabaseService.getRecentActivities();
      
      // Attendance Stats
      final personalStats = await SupabaseService.getPersonalMonthlyStats();
      final teamStats = isAdmin ? await SupabaseService.getTeamTodayStats() : null;

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _userName = profile?['full_name']?.split(' ')[0] ?? 'User';
          _avatarUrl = profile?['avatar_url'] ?? '';
          _todayAttendance = attendance;
          _recentActivities = activities;
          
          _allFarmers = farmers;
          _allFarms = farms;
          _allCrops = crops;
          _allReports = reports;
          _allTransactions = transactions;
          _allProducts = products;
          
          _presentCount = personalStats['present'] ?? 0;
          _absentCount = personalStats['absent'] ?? 0;
          if (teamStats != null) {
            _teamPresentCount = teamStats['present'] ?? 0;
            _teamAbsentCount = teamStats['absent'] ?? 0;
          }
          
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final startDate = _getStartDateForPeriod(_selectedPeriod);
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    bool isInPeriod(dynamic item) {
      if (startDate == null) return true;
      final createdStr = item['created_at']?.toString() ?? item['start_time']?.toString();
      if (createdStr == null) return false;
      final dt = DateTime.tryParse(createdStr);
      return dt != null && dt.isAfter(startDate);
    }

    _farmerCount = _allFarmers.where(isInPeriod).length;
    _farmCount = _allFarms.where(isInPeriod).length;
    _cropCount = _allCrops.where(isInPeriod).length;
    _reportCount = _allReports.where(isInPeriod).length;

    double revenue = 0;
    double returnValue = 0;
    double itemsSold = 0;
    double itemsReturned = 0;
    
    final validTransactions = _allTransactions.where((tx) {
      final type = tx['transaction_type'];
      final isRelevant = type == 'DELIVERED' || type == 'RETURN';
      final periodOk = isInPeriod(tx);
      if (!_isAdmin) {
        return isRelevant && periodOk && tx['executive_id'] == currentUserId;
      }
      return isRelevant && periodOk;
    }).toList();

    for (var tx in validTransactions) {
      final type = tx['transaction_type'];
      final itemName = tx['item_name']?.toString().trim().toLowerCase();
      final unit = tx['unit']?.toString().trim().toLowerCase();
      final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;
      
      final parent = _allProducts.firstWhere(
        (p) => p['label']?.toString().trim().toLowerCase() == itemName, 
        orElse: () => {}
      );
      
      if (parent.isNotEmpty) {
        final variants = List<Map<String, dynamic>>.from(parent['variants'] ?? []);
        final variant = variants.firstWhere(
          (v) => v['label']?.toString().trim().toLowerCase() == unit, 
          orElse: () => {}
        );
        
        if (variant.isNotEmpty) {
          final price = double.tryParse(variant['offer_price']?.toString() ?? '0') ?? 0.0;
          final amount = price * qty;
          
          if (type == 'DELIVERED') {
            revenue += amount;
            itemsSold += qty;
          } else if (type == 'RETURN') {
            revenue -= amount;
            returnValue += amount;
            itemsReturned += qty;
            itemsSold -= qty;
          }
        }
      }
    }
    _totalSalesRevenue = revenue;
    _totalReturnValue = returnValue;
    _totalItemsSold = itemsSold.toInt();
    _totalItemsReturned = itemsReturned.toInt();
    _filteredTransactions = validTransactions;
  }

  DateTime? _getStartDateForPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Year':
        return DateTime(now.year, 1, 1);
      default:
        return null;
    }
  }

  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final diff = DateTime.now().difference(dateTime);
      
      if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
      if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isWide = MediaQuery.sizeOf(context).width > 1100;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_fab',
        onPressed: _loadDashboardData,
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntranceAnimation(
                delay: 0,
                child: Opacity(
                  opacity: _scrollOpacity,
                  child: Transform.scale(
                    scale: _scrollScale,
                    child: _buildHeroSection(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              EntranceAnimation(
                delay: 150,
                child: _buildFilterBar(),
              ),
              const SizedBox(height: 16),
              EntranceAnimation(
                delay: 200,
                child: _buildQuickActions(isWide: false),
              ),
              const SizedBox(height: 32),
              EntranceAnimation(
                delay: 350,
                child: _buildSalesCard(),
              ),
              const SizedBox(height: 24),
              _buildStatsGrid(isWide: false),
              const SizedBox(height: 32),
              if (_isAdmin) ..._buildAdminSections(isWide: false) 
              else ..._buildUserSections(isWide: false),
              const SizedBox(height: 32),
              _buildRecentActivitiesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content Area
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(),
                const SizedBox(height: 40),
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
                const SizedBox(height: 20),
                _buildStatsGrid(isWide: true),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Launch',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          _buildQuickActions(isWide: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Financial Summary',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          _buildSalesCard(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (!_isAdmin) ...[
                  const Text('Action Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: _buildUserSections(isWide: true).map((w) => SizedBox(width: 350, child: w)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Sidebar Content Area
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildFilterBar(),
                const SizedBox(height: 40),
                if (_isAdmin) ...[
                  const Text('Admin Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ..._buildAdminSections(isWide: true),
                  const SizedBox(height: 40),
                ],
                _buildRecentActivitiesSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid({required bool isWide}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isWide ? 4 : (constraints.maxWidth > 600 ? 4 : 2);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 1.4 : 1.1,
          children: [
            StatCard(
              title: _selectedPeriod == 'All Time' ? 'Total Farmers' : 'New Farmers',
              value: _farmerCount.toString(),
              icon: Icons.people_alt_rounded,
              gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmerListScreen())),
            ),
            StatCard(
              title: _selectedPeriod == 'All Time' ? 'Total Farms' : 'New Farms',
              value: _farmCount.toString(),
              icon: Icons.agriculture_rounded,
              gradient: const [Color(0xFF8BC34A), Color(0xFF558B2F)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmListScreen())),
            ),
            StatCard(
              title: _selectedPeriod == 'All Time' ? 'Total Crops' : 'New Crops',
              value: _cropCount.toString(),
              icon: Icons.eco_rounded,
              gradient: const [Color(0xFF009688), Color(0xFF00695C)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CropListScreen())),
            ),
            StatCard(
              title: _selectedPeriod == 'All Time' ? 'Reports' : 'Recent Reports',
              value: _reportCount.toString(),
              icon: Icons.analytics_rounded,
              gradient: const [Color(0xFF673AB7), Color(0xFF4527A0)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsListScreen())),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildAdminSections({required bool isWide}) {
    return [
      _actionWrapper(
        isWide,
        delay: 700,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
              const SizedBox(width: 16),
              const Expanded(
                child: Text('Create Executive Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateExecutiveScreen())),
                icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _actionWrapper(
        isWide,
        delay: 800,
        child: _workActionCard(
          context,
          title: 'Team Attendance',
          subtitle: 'Shift Overview',
          icon: Icons.fact_check_rounded,
          color: Colors.blue,
          fullWidth: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusBadge('P', _teamPresentCount, Colors.green),
              const SizedBox(width: 8),
              _statusBadge('A', _teamAbsentCount, Colors.red),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.blue, size: 20),
            ],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAttendanceScreen())),
        ),
      ),
      const SizedBox(height: 16),
      _actionWrapper(
        isWide,
        delay: 900,
        child: _workActionCard(
          context,
          title: 'Executive Call Logs',
          subtitle: 'Monitor Phone Activities',
          icon: Icons.phone_callback_rounded,
          color: Colors.green,
          fullWidth: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminCallLogsScreen())),
        ),
      ),
      const SizedBox(height: 16),
      _actionWrapper(
        isWide,
        delay: 1000,
        child: _workActionCard(
          context,
          title: 'Security & Device Logs',
          subtitle: 'Monitor Hardware Usage',
          icon: Icons.security_rounded,
          color: Colors.orange,
          fullWidth: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginLogsScreen())),
        ),
      ),
    ];
  }

  List<Widget> _buildUserSections({required bool isWide}) {
    return [
      _actionWrapper(
        isWide,
        delay: 700,
        child: _workActionCard(
          context,
          title: 'Attendance',
          subtitle: _todayAttendance == null 
            ? 'No check-in' 
            : (_todayAttendance!['check_out_time'] == null ? 'Duty On' : 'Shift Done'),
          icon: Icons.camera_enhance_rounded,
          color: AppColors.primary,
          fullWidth: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusBadge('P', _presentCount, Colors.green),
              const SizedBox(width: 8),
              _statusBadge('A', _absentCount, Colors.red),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
            ],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceScreen())).then((_) => _loadDashboardData()),
        ),
      ),
      const SizedBox(height: 16),
      _actionWrapper(
        isWide,
        delay: 800,
        child: _workActionCard(
          context,
          title: 'Work Logs',
          subtitle: 'Attendance History',
          icon: Icons.history_edu_rounded,
          color: Colors.blue,
          fullWidth: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen())),
        ),
      ),
      const SizedBox(height: 16),
      _actionWrapper(
        isWide,
        delay: 900,
        child: _workActionCard(
          context,
          title: 'Nature Biotic Dialer',
          subtitle: 'Call Farmers & Contacts',
          icon: Icons.call_rounded,
          color: Colors.green,
          fullWidth: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExecutiveDialerScreen())),
        ),
      ),
    ];
  }

  Widget _actionWrapper(bool isWide, {required int delay, required Widget child}) {
    if (isWide) return child;
    return EntranceAnimation(delay: delay, child: child);
  }

  Widget _buildRecentActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activities',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
        ),
        const SizedBox(height: 16),
        if (_recentActivities.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Text('No recent activities', style: TextStyle(color: AppColors.textGray))))
        else
          ..._recentActivities.asMap().entries.map((entry) {
            return ActivityItem(
              title: entry.value['title'],
              subtitle: entry.value['subtitle'],
              time: _getTimeAgo(entry.value['created_at']),
            );
          }),
      ],
    );
  }

  Widget _buildHeroSection() {
    String greeting = 'Good ${_getGreeting()}';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withBlue(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_userName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep growing with Nature Biotic',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Hero(
                  tag: 'profile_avatar',
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.secondary,
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                    child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 35, color: AppColors.primary) : null,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, size: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildQuickActions({required bool isWide}) {
    final actions = [
      _quickActionIcon(
        icon: Icons.camera_enhance_rounded,
        label: 'Check In',
        color: Colors.orange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceScreen())),
      ),
      _quickActionIcon(
        icon: Icons.person_add_rounded,
        label: 'Add Farmer',
        color: Colors.blue,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmerListScreen())),
      ),
      _quickActionIcon(
        icon: Icons.add_chart_rounded,
        label: 'Analysis',
        color: Colors.purple,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsListScreen())),
      ),
      _quickActionIcon(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        color: Colors.cyan,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmListScreen(isStockMode: true))),
      ),
      _quickActionIcon(
        icon: Icons.dialpad_rounded,
        label: 'Dialer',
        color: Colors.green,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExecutiveDialerScreen())),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isWide)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'The Launchpad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        if (isWide)
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: actions,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: actions,
            ),
          ),
      ],
    );
  }

  Widget _quickActionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      hoverColor: color.withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label, 
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBlack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                ],
              ),
            ),
            if (trailing != null) 
              trailing
            else
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSalesCard() {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FarmSalesListScreen(
                initialTransactions: _filteredTransactions,
                allProducts: _allProducts,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAdmin ? 'Team Sales Revenue' : 'My Total Sales',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(_totalSalesRevenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_totalItemsSold Items',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Sold',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_totalItemsReturned Items',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Returned',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _isAdmin ? 'Across All Regions' : 'Generated from Deliveries',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final periods = ['Today', 'This Week', 'This Month', 'This Year', 'All Time'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedPeriod = period;
                    _applyFilters();
                  });
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textGray,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: isSelected ? 4 : 0,
              side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.2)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class EntranceAnimation extends StatelessWidget {
  final Widget child;
  final int delay;

  const EntranceAnimation({super.key, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.last.withOpacity(0.3),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: Offset(0, _isHovered ? 10 : 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;

  const ActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: AppColors.textGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
