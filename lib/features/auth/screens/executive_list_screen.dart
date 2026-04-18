import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/auth/screens/executive_assignment_screen.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_history_screen.dart';

class ExecutiveListScreen extends StatefulWidget {
  const ExecutiveListScreen({super.key});

  @override
  State<ExecutiveListScreen> createState() => _ExecutiveListScreenState();
}

class _ExecutiveListScreenState extends State<ExecutiveListScreen> {
  List<Map<String, dynamic>> _executives = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExecutives();
  }

  Future<void> _loadExecutives() async {
    try {
      final data = await SupabaseService.getExecutives();
      if (mounted) {
        setState(() {
          _executives = data;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Executive Team'),
        actions: [
          IconButton(
            onPressed: _loadExecutives,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _executives.isEmpty
              ? const Center(child: Text('No executives found.'))
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: _executives.length,
                    itemBuilder: (context, index) {
                      final executive = _executives[index];
                      return InkWell(
                        onTap: () {
                          _showOptions(executive);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.secondary),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.secondary,
                                backgroundImage:
                                    executive['avatar_url'] != null
                                        ? NetworkImage(executive['avatar_url'])
                                        : null,
                                child:
                                    executive['avatar_url'] == null
                                        ? Text(
                                          executive['full_name']?[0] ?? 'E',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      executive['full_name'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '@${executive['username'] ?? 'unknown'}',
                                      style: const TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textGray,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
    );
  }

  void _showOptions(Map<String, dynamic> executive) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(), // Only scroll if needed via bottom sheet behavior
              children: [
                Text(
                  executive['full_name'] ?? 'Executive Options',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '@${executive['username']}',
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                _optionItem(
                  Icons.agriculture_rounded,
                  'Assign Farms',
                  'Manage farms assigned to this executive',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                ExecutiveAssignmentScreen(executive: executive),
                      ),
                    ).then((_) => _loadExecutives());
                  },
                ),
                const SizedBox(height: 16),
                _optionItem(
                  Icons.history_rounded,
                  'Attendance & Leaves',
                  'View check-in logs and leave history',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AttendanceHistoryScreen(
                              userId: executive['id'],
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _optionItem(
                  Icons.track_changes_rounded,
                  'Set Sales Target',
                  'Monthly target: ₹${executive['sales_target'] ?? 0}',
                  onTap: () {
                    Navigator.pop(context);
                    _showTargetDialog(executive);
                  },
                ),
                const SizedBox(height: 16),
                _optionItem(
                  Icons.phonelink_erase_rounded,
                  'Reset Device Pairing',
                  'Allow login from a new phone',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Reset Device?'),
                            content: const Text(
                              'This will allow the user to link their account to a new phone. Are you sure?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      await SupabaseService.resetUserDevice(executive['id']);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device pairing reset successfully'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Widget _optionItem(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
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
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showTargetDialog(Map<String, dynamic> executive) {
    final controller = TextEditingController(
      text: (executive['sales_target'] ?? '').toString(),
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Set Target for ${executive['full_name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the monthly sales target for this executive.',
                  style: TextStyle(fontSize: 13, color: AppColors.textGray),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Sales Target (₹)',
                    hintText: 'e.g. 10000',
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final target = double.tryParse(controller.text) ?? 0.0;
                  Navigator.pop(context);

                  try {
                    await SupabaseService.updateSalesTarget(
                      executive['id'],
                      target,
                    );
                    _loadExecutives(); // Refresh list to show new target
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sales target updated successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating target: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
