import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CallTracker {
  static Future<void> makeCall(BuildContext context, String phoneNumber, {String? farmerId}) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      final startTime = DateTime.now();
      await launchUrl(launchUri);

      // We wait for the user to return to the app
      // This is handled via WidgetsBindingObserver in the screen itself, 
      // but we can provide a helper here to process the result.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  static Future<void> processCallResult(BuildContext context, String phoneNumber, DateTime startTime, {String? farmerId}) async {
    final endTime = DateTime.now();
    int durationSeconds = endTime.difference(startTime).inSeconds;

    // On Android, try to get more accurate data from CallLog
    if (Platform.isAndroid) {
      if (await Permission.phone.request().isGranted) {
        // Wait a bit for the system to update the log
        await Future.delayed(const Duration(seconds: 2));
        final Iterable<CallLogEntry> entries = await CallLog.query(
          number: phoneNumber,
          dateFrom: startTime.millisecondsSinceEpoch - 10000, // 10s buffer
        );

        if (entries.isNotEmpty) {
          final lastCall = entries.first;
          durationSeconds = lastCall.duration ?? durationSeconds;
        }
      }
    }

    if (!context.mounted) return;

    // Show Summary Dialog
    final summary = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CallSummaryDialog(phoneNumber: phoneNumber),
    );

    if (summary != null) {
      try {
      final callLogData = {
        'farmer_id': farmerId,
        'phone_number': phoneNumber,
        'start_time': startTime.toIso8601String(),
        'duration_seconds': durationSeconds,
        'summary': summary,
      };

      if (kIsWeb) {
        await SupabaseService.addCallLog(callLogData);
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'call_logs',
          data: callLogData,
          operation: 'INSERT',
        );
        // Attempt sync
        SyncManager().sync();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb ? 'Call log synchronized successfully' : 'Call log saved locally and syncing...'), 
            backgroundColor: Colors.green
          ),
        );
      }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _CallSummaryDialog extends StatefulWidget {
  final String phoneNumber;
  const _CallSummaryDialog({required this.phoneNumber});

  @override
  State<_CallSummaryDialog> createState() => _CallSummaryDialogState();
}

class _CallSummaryDialogState extends State<_CallSummaryDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Call Summary - ${widget.phoneNumber}'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter a brief note about the call...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''), // Empty summary
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save Note'),
        ),
      ],
    );
  }
}
