import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/core/call_tracker.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class ExecutiveDialerScreen extends StatefulWidget {
  const ExecutiveDialerScreen({super.key});

  @override
  State<ExecutiveDialerScreen> createState() => _ExecutiveDialerScreenState();
}

class _ExecutiveDialerScreenState extends State<ExecutiveDialerScreen> with WidgetsBindingObserver {
  String _phoneNumber = '';
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = false;
  
  // Tracking
  DateTime? _callStartTime;
  String? _dialedNumber;
  String? _selectedFarmerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFarmers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _callStartTime != null && _dialedNumber != null) {
      final startTime = _callStartTime!;
      final dialedNumber = _dialedNumber!;
      final farmerId = _selectedFarmerId;
      
      // Reset tracking state immediately to prevent multi-prompts
      _callStartTime = null;
      _dialedNumber = null;
      _selectedFarmerId = null;

      // Handle call result
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          CallTracker.processCallResult(
            context, 
            dialedNumber, 
            startTime, 
            farmerId: farmerId
          );
        }
      });
    }
  }

  Future<void> _loadFarmers() async {
    setState(() => _isLoading = true);
    try {
      final farmers = await SupabaseService.getFarmers();
      setState(() => _farmers = farmers);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _onDigitPress(String digit) {
    setState(() {
      _phoneNumber += digit;
    });
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  void _initiateCall(String number, {String? farmerId}) {
    if (number.isEmpty) return;
    
    _callStartTime = DateTime.now();
    _dialedNumber = number;
    _selectedFarmerId = farmerId;
    
    CallTracker.makeCall(context, number, farmerId: farmerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nature Biotic Dialer'),
      ),
      body: Column(
        children: [
          // Display Area
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              _phoneNumber.isEmpty ? 'Enter Number' : _phoneNumber,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _phoneNumber.isEmpty ? Colors.grey[400] : AppColors.primary,
              ),
            ),
          ),
          
          // Contact Suggestions
          if (_phoneNumber.isNotEmpty)
            Expanded(
              child: ListView(
                children: _farmers
                    .where((f) => f['phone']?.toString().contains(_phoneNumber) ?? false)
                    .map((f) => ListTile(
                          leading: const CircleAvatar(backgroundColor: AppColors.secondary, child: Icon(Icons.person, color: AppColors.primary)),
                          title: Text(f['name'] ?? ''),
                          subtitle: Text(f['phone'] ?? ''),
                          onTap: () => _initiateCall(f['phone'] ?? '', farmerId: f['id'].toString()),
                        ))
                    .toList(),
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // Dial Pad
          _buildDialPad(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDialPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('1'),
            _dialButton('2'),
            _dialButton('3'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('4'),
            _dialButton('5'),
            _dialButton('6'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('7'),
            _dialButton('8'),
            _dialButton('9'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('*'),
            _dialButton('0'),
            _dialButton('#'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 64), // Balance for backspace
            FloatingActionButton(
              onPressed: () => _initiateCall(_phoneNumber),
              backgroundColor: Colors.green,
              child: const Icon(Icons.call, color: Colors.white),
            ),
            const SizedBox(width: 24),
            IconButton(
              onPressed: _onBackspace,
              icon: const Icon(Icons.backspace_outlined),
              iconSize: 28,
            ),
          ],
        ),
      ],
    );
  }

  Widget _dialButton(String digit) {
    return MaterialButton(
      onPressed: () => _onDigitPress(digit),
      height: 70,
      minWidth: 70,
      shape: const CircleBorder(),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
