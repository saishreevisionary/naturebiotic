import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farmers/screens/add_farmer_screen.dart';
import 'package:nature_biotic/features/farmers/screens/farmer_detail_screen.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FarmerListScreen extends StatefulWidget {
  const FarmerListScreen({super.key});

  @override
  State<FarmerListScreen> createState() => _FarmerListScreenState();
}

class _FarmerListScreenState extends State<FarmerListScreen> {
  List<Map<String, dynamic>> _farmers = [];
  String? _userRole;
  bool _isLoading = true;
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      _userRole = profile?['role'];
      
      final remoteData = await SupabaseService.getFarmers();
      List<Map<String, dynamic>> localData = [];
      
      if (!kIsWeb) {
        localData = await LocalDatabaseService.getData('farmers');
      }

      if (mounted) {
        setState(() {
          // Merge and De-duplicate
          final Map<String, Map<String, dynamic>> combinedMap = {};
          
          for (var farmer in localData) {
            combinedMap[farmer['id'].toString()] = farmer;
          }
          for (var farmer in remoteData) {
            combinedMap[farmer['id'].toString()] = farmer;
          }

          _farmers = combinedMap.values.toList();
          _farmers.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  backgroundColor: AppColors.background.withOpacity(0.8),
                  flexibleSpace: FlexibleSpaceBar(
                    background: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                  title: Text(
                    'Farmers',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: AppColors.textBlack,
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          )
                        ]
                      ),
                      child: IconButton(
                        onPressed: _loadFarmers, 
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.primary)
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search by name, village...',
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                              suffixIcon: _searchController.text.isNotEmpty 
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              FilterChipWidget(
                                label: 'Hot', 
                                color: AppColors.hot,
                                isSelected: _selectedCategory == 'Hot',
                                onTap: () => setState(() => _selectedCategory = _selectedCategory == 'Hot' ? null : 'Hot'),
                              ),
                              const SizedBox(width: 12),
                              FilterChipWidget(
                                label: 'Warm', 
                                color: AppColors.warm,
                                isSelected: _selectedCategory == 'Warm',
                                onTap: () => setState(() => _selectedCategory = _selectedCategory == 'Warm' ? null : 'Warm'),
                              ),
                              const SizedBox(width: 12),
                              FilterChipWidget(
                                label: 'Cold', 
                                color: AppColors.cold,
                                isSelected: _selectedCategory == 'Cold',
                                onTap: () => setState(() => _selectedCategory = _selectedCategory == 'Cold' ? null : 'Cold'),
                              ),
                              const SizedBox(width: 20),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = null;
                                    _searchController.clear();
                                  });
                                },
                                icon: const Icon(Icons.backspace_outlined, size: 16),
                                label: const Text('Clear Filters'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textGray,
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final query = _searchController.text.toLowerCase();
                    final filtered = _farmers.where((f) {
                      final name = (f['name'] ?? '').toString().toLowerCase();
                      final village = (f['village'] ?? '').toString().toLowerCase();
                      final mobile = (f['mobile'] ?? '').toString().toLowerCase();
                      final category = f['category'];
                      
                      final matchesQuery = name.contains(query) || village.contains(query) || mobile.contains(query);
                      final matchesCategory = _selectedCategory == null || category == _selectedCategory;
                      
                      return matchesQuery && matchesCategory;
                    }).toList();

                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_rounded, size: 64, color: AppColors.textGray.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No farmers found',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final farmer = filtered[index];
                            return EntranceAnimation(
                              delay: 50 + (index * 50),
                              child: FarmerCard(
                                id: farmer['id'].toString(),
                                name: farmer['name'] ?? 'N/A',
                                village: farmer['village'] ?? 'N/A',
                                category: farmer['category'] ?? 'Warm',
                                categoryColor: _getCategoryColor(farmer['category']),
                                isVerified: farmer['is_verified'] == true,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FarmerDetailScreen(farmer: farmer),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadFarmers();
                                  }
                                },
                              ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    );
                  }
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
      floatingActionButton: _userRole == 'manager' 
        ? null 
        : EntranceAnimation(
            delay: 500,
            child: ScaleButton(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddFarmerScreen()),
                );
                _loadFarmers();
              },
              child: Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot': return AppColors.hot;
      case 'Warm': return AppColors.warm;
      case 'Cold': return AppColors.cold;
      default: return AppColors.warm;
    }
  }
}

class FilterChipWidget extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterChipWidget({
    super.key, 
    required this.label, 
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class FarmerCard extends StatelessWidget {
  final String id;
  final String name;
  final String village;
  final String category;
  final Color categoryColor;
  final bool isVerified;
  final VoidCallback? onTap;

  const FarmerCard({
    super.key,
    required this.id,
    required this.name,
    required this.village,
    required this.category,
    required this.categoryColor,
    this.isVerified = true,
    this.onTap,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return 'F';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts[0].length > 1) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'farmer_icon_$id',
                  child: Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor.withOpacity(0.8),
                          categoryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBlack,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: AppColors.textGray.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            village,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppColors.textGray.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: categoryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                color: categoryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
