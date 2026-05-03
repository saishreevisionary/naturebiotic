import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';

class StartTripForm extends StatefulWidget {
  final String expenseId;
  final VoidCallback onStarted;
  final Future<String?> Function() onCapture;

  const StartTripForm({
    super.key,
    required this.expenseId,
    required this.onStarted,
    required this.onCapture,
  });

  @override
  State<StartTripForm> createState() => _StartTripFormState();
}

class _StartTripFormState extends State<StartTripForm> {
  String? _selectedVehicle;
  String? _selectedOwnership;
  final _odometerController = TextEditingController();
  String? _odometerPhoto;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final bool canStart =
        _selectedVehicle != null &&
        _selectedOwnership != null &&
        _odometerController.text.isNotEmpty &&
        _odometerPhoto != null &&
        !_isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Start Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Type',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _choiceChip(
                  'Two Wheeler',
                  _selectedVehicle == 'TWO_WHEELER',
                  () => setState(() => _selectedVehicle = 'TWO_WHEELER'),
                ),
                const SizedBox(width: 12),
                _choiceChip(
                  'Four Wheeler',
                  _selectedVehicle == 'FOUR_WHEELER',
                  () => setState(() => _selectedVehicle = 'FOUR_WHEELER'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Vehicle Ownership',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _choiceChip(
                  'Own Vehicle',
                  _selectedOwnership == 'OWN',
                  () => setState(() => _selectedOwnership = 'OWN'),
                ),
                const SizedBox(width: 12),
                _choiceChip(
                  'Company Vehicle',
                  _selectedOwnership == 'COMPANY',
                  () => setState(() => _selectedOwnership = 'COMPANY'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _odometerController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current Odometer Reading',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            _buildPhotoSelector(
              'Take Odometer Photo',
              _odometerPhoto,
              () async {
                final url = await widget.onCapture();
                if (url != null) setState(() => _odometerPhoto = url);
              },
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed:
                    canStart
                        ? () async {
                          setState(() => _isSubmitting = true);
                          try {
                            await SupabaseService.updateTripStart(
                              expenseId: widget.expenseId,
                              vehicleType: _selectedVehicle!,
                              ownership: _selectedOwnership!,
                              odometer: double.parse(_odometerController.text),
                              photoUrl: _odometerPhoto,
                            );
                            widget.onStarted();
                          } catch (e) {
                            setState(() => _isSubmitting = false);
                          }
                        }
                        : null,
                child:
                    _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Start Trip',
                          style: TextStyle(color: Colors.white),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip(String label, bool isSelected, VoidCallback onSelected) {
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textGray,
        ),
      ),
    );
  }

  Widget _buildPhotoSelector(
    String label,
    String? photoUrl,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textGray.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.02),
        ),
        constraints: const BoxConstraints(maxHeight: 200),
        child:
            photoUrl != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photoUrl, fit: BoxFit.contain),
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class EndTripDialogContent extends StatefulWidget {
  final String expenseId;
  final double startOdometer;
  final VoidCallback onEnded;
  final Future<String?> Function() onCapture;

  const EndTripDialogContent({
    super.key,
    required this.expenseId,
    required this.startOdometer,
    required this.onEnded,
    required this.onCapture,
  });

  @override
  State<EndTripDialogContent> createState() => _EndTripDialogContentState();
}

class _EndTripDialogContentState extends State<EndTripDialogContent> {
  final _odometerController = TextEditingController();
  String? _odometerPhoto;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final double endOdo = double.tryParse(_odometerController.text) ?? 0.0;
    final double distance = endOdo - widget.startOdometer;
    
    final bool canEnd =
        _odometerController.text.isNotEmpty &&
        endOdo >= widget.startOdometer &&
        _odometerPhoto != null &&
        !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'End Trip',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _odometerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'End Odometer Reading',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_odometerController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              distance >= 0 
                ? 'Total Distance: ${distance.toStringAsFixed(1)} KM'
                : 'Reading must be >= ${widget.startOdometer}',
              style: TextStyle(
                color: distance >= 0 ? AppColors.primary : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildPhotoSelector(
            'Take End Odometer Photo',
            _odometerPhoto,
            () async {
              final url = await widget.onCapture();
              if (url != null) setState(() => _odometerPhoto = url);
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed:
                  canEnd
                      ? () async {
                        setState(() => _isSubmitting = true);
                        try {
                          await SupabaseService.updateTripEnd(
                            expenseId: widget.expenseId,
                            odometer: double.parse(_odometerController.text),
                            photoUrl: _odometerPhoto,
                          );
                          Navigator.pop(context);
                          widget.onEnded();
                        } catch (e) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                      : null,
              child:
                  _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        'End Trip & Finish Tracking',
                        style: TextStyle(color: Colors.white),
                      ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPhotoSelector(
    String label,
    String? photoUrl,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textGray.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.02),
        ),
        constraints: const BoxConstraints(maxHeight: 200),
        child:
            photoUrl != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photoUrl, fit: BoxFit.contain),
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
