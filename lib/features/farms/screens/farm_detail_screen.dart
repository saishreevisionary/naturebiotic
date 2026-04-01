import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';

class FarmDetailScreen extends StatelessWidget {
  final Map<String, dynamic> farm;

  const FarmDetailScreen({super.key, required this.farm});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(farm['name'] ?? farm['place'] ?? 'Farm Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.agriculture_rounded, size: 48, color: AppColors.primary),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registration Date', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                      Text('March 31, 2026', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Farm Location & Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _infoRow(Icons.location_on_outlined, 'Place', farm['place'] ?? 'N/A'),
            _infoRow(Icons.square_foot_rounded, 'Total Area', '${farm['area'] ?? '0'} Acres'),
            const SizedBox(height: 32),
            const Text('Infrastructure & Resources', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _infoRow(Icons.waves_rounded, 'Soil Type', farm['soil_type'] ?? 'N/A'),
            _infoRow(Icons.opacity_rounded, 'Irrigation', farm['irrigation_type'] ?? 'N/A'),
            _infoRow(Icons.water_drop_outlined, 'Water Source', farm['water_source'] ?? 'N/A'),
            _infoRow(Icons.inventory_2_outlined, 'Water Quantity', farm['water_quantity'] ?? 'N/A'),
             _infoRow(Icons.flash_on_outlined, 'Power Source', farm['power_source'] ?? 'N/A'),
            const SizedBox(height: 32),
            const Text('Soil & Water Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                   Icon(Icons.description_outlined, color: AppColors.primary),
                   SizedBox(width: 16),
                   Text('No reports uploaded'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
