import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';

class FarmerDetailScreen extends StatelessWidget {
  final Map<String, dynamic> farmer;

  const FarmerDetailScreen({super.key, required this.farmer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(farmer['name'] ?? 'Farmer Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.person, size: 60, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              farmer['name'] ?? 'N/A',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(farmer['category']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                farmer['category'] ?? 'Warm',
                style: TextStyle(
                  color: _getCategoryColor(farmer['category']),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _infoSection(Icons.phone_outlined, 'Mobile Number', farmer['mobile'] ?? 'N/A'),
            _infoSection(Icons.location_on_outlined, 'Village', farmer['village'] ?? 'N/A'),
            _infoSection(Icons.home_outlined, 'Address', farmer['address'] ?? 'N/A'),
            const SizedBox(height: 32),
            const Text(
              'Farms & Crops',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary),
              ),
              child: const Row(
                children: [
                   Icon(Icons.agriculture_rounded, color: AppColors.primary),
                   SizedBox(width: 16),
                   Text('No farms added yet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textGray, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot': return Colors.red;
      case 'Warm': return Colors.orange;
      case 'Cold': return Colors.blue;
      default: return Colors.orange;
    }
  }
}
