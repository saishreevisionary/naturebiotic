import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';

class ReportGeneratorScreen extends StatelessWidget {
  const ReportGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const Center(
              child: Column(
                children: [
                   Icon(Icons.check_circle_rounded, size: 60, color: AppColors.primary),
                   SizedBox(height: 12),
                   Text(
                    'Analysis Complete',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                   Text(
                    'Generated on 31 March 2026',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
             _reportSection(
              title: 'Problem Identified',
              content: 'Pest attack (Mealybugs) observed on young mango shoots. Requires immediate attention to prevent spread.',
              icon: Icons.bug_report_rounded,
            ),
            const SizedBox(height: 20),
             _reportSection(
              title: 'Previous Inputs',
              content: 'Organic fertilizer applied on 10 March 2026. Irrigation cycle maintained every 3 days.',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 20),
             _reportSection(
              title: 'Recommended Products',
              content: 'Nature Biotic Organic Pest-Ex (500ml per acre)\nNeem Oil Spray (1% concentration)',
              icon: Icons.shopping_bag_rounded,
              isList: true,
            ),
            const SizedBox(height: 20),
             _reportSection(
              title: 'Estimated Cost',
              content: 'Total Budget: ₹1,500 - ₹2,000 per acre',
              icon: Icons.payments_rounded,
              accent: true,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {},
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Export PDF Report'),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _reportSection({
    required String title,
    required String content,
    required IconData icon,
    bool isList = false,
    bool accent = false,
  }) {
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
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textBlack.withOpacity(0.8),
              height: 1.5,
              fontWeight: accent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
