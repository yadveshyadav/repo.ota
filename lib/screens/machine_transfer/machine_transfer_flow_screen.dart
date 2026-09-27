import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/machine_transfer/controller/machine_transfer_controller.dart';
import '../../models/machine.dart';
import '../../models/machine_movement.dart';
import '../../models/vendor.dart';
import '../../shared/widgets/premium_card.dart';
import 'machine_transfer_detail_screen.dart';

/// One-Pager Machine Shifting Request Creation Screen matching backend API specification
class MachineTransferFlowScreen extends StatefulWidget {
  final Machine? preSelectedMachine;
  final MachineTransferController? controller;

  const MachineTransferFlowScreen({
    super.key,
    this.preSelectedMachine,
    this.controller,
  });

  @override
  State<MachineTransferFlowScreen> createState() => _MachineTransferFlowScreenState();
}

class _MachineTransferFlowScreenState extends State<MachineTransferFlowScreen> {
  late final MachineTransferController _controller;

  final TextEditingController _aPointController = TextEditingController();
  final TextEditingController _aLatController = TextEditingController(text: '27.8129');
  final TextEditingController _aLngController = TextEditingController(text: '74.5036');

  final TextEditingController _bPointController = TextEditingController();
  final TextEditingController _bLatController = TextEditingController(text: '28.0825');
  final TextEditingController _bLngController = TextEditingController(text: '74.6189');

  final TextEditingController _requiredDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MachineTransferController();
    _initData();
  }

  Future<void> _initData() async {
    await _controller.initOnePagerForm(preSelectedMachine: widget.preSelectedMachine);
    if (_controller.selectedMachine != null) {
      _aPointController.text = _controller.selectedMachine!.location.isNotEmpty
          ? _controller.selectedMachine!.location
          : 'Origin Point A';
    }
    _requiredDateController.text = _controller.requiredDate;
  }

  @override
  void dispose() {
    _aPointController.dispose();
    _aLatController.dispose();
    _aLngController.dispose();
    _bPointController.dispose();
    _bLatController.dispose();
    _bLngController.dispose();
    _requiredDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _requiredDateController.text = dateStr;
      _controller.setRequiredDate(dateStr);
    }
  }

  Future<void> _handleSubmit() async {
    _controller.setAPoint(
      _aPointController.text,
      lat: double.tryParse(_aLatController.text) ?? 27.8129,
      lng: double.tryParse(_aLngController.text) ?? 74.5036,
    );
    _controller.setBPoint(
      _bPointController.text,
      lat: double.tryParse(_bLatController.text) ?? 28.0825,
      lng: double.tryParse(_bLngController.text) ?? 74.6189,
    );

    final result = await _controller.submitOnePagerShiftRequest();
    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MachineTransferDetailScreen(transferId: result.id),
        ),
      );
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: AppColors.criticalRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLoading = _controller.isLoading;
        final isSubmitting = _controller.isSubmitting;

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            foregroundColor: AppColors.white,
            title: const Text('Machine Shifting Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            elevation: 0,
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Header Banner
                      _buildHeaderBanner(),

                      const SizedBox(height: 16),

                      // Section 1: Machine & Vendor
                      _buildSection1MachineVendor(),

                      const SizedBox(height: 16),

                      // Section 2: Reason & Shifting Mode
                      _buildSection2ReasonAndMode(),

                      const SizedBox(height: 16),

                      // Section 3: Origin Point A
                      _buildSection3OriginPointA(),

                      const SizedBox(height: 16),

                      // Section 4: Destination Point B
                      _buildSection4DestinationPointB(),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : _handleSubmit,
                          icon: isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            isSubmitting ? 'SUBMITTING REQUEST...' : 'SUBMIT SHIFTING REQUEST',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: const Row(
        children: [
          Icon(Icons.alt_route_rounded, color: AppColors.primaryGreen, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One-Pager Shift Request',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                ),
                SizedBox(height: 2),
                Text(
                  'Fill in machinery, reason, origin Point A, and destination Point B to initiate SCM approval.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection1MachineVendor() {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.precision_manufacturing_outlined, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text('1. Machine & Vendor', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 12),

          // Machine Dropdown
          const Text('MACHINE *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Machine>(
            initialValue: _controller.availableMachines.contains(_controller.selectedMachine)
                ? _controller.selectedMachine
                : null,
            hint: const Text('Select Machine'),
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.white,
            ),
            items: _controller.availableMachines.map((m) {
              return DropdownMenuItem<Machine>(
                value: m,
                child: Text('${m.machineName} (${m.chassisNumber})', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                _controller.selectMachine(val);
                _aPointController.text = val.location.isNotEmpty ? val.location : 'Origin Site';
              }
            },
          ),

          const SizedBox(height: 14),

          // Vendor Dropdown
          const Text('VENDOR *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Vendor>(
            initialValue: _controller.availableVendors.contains(_controller.selectedVendor)
                ? _controller.selectedVendor
                : null,
            hint: const Text('Select Operating Vendor'),
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.white,
            ),
            items: _controller.availableVendors.map((v) {
              return DropdownMenuItem<Vendor>(
                value: v,
                child: Text(v.vendorName, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _controller.setSelectedVendor(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSection2ReasonAndMode() {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_outlined, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text('2. Shifting Reason & Mode', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Reason Master Dropdown
          const Text('REASON FOR SHIFTING *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          DropdownButtonFormField<MachineShiftReason>(
            initialValue: _controller.selectedReason,
            hint: const Text('Select Shifting Reason'),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.white,
            ),
            items: _controller.availableReasons.map((r) {
              return DropdownMenuItem<MachineShiftReason>(
                value: r,
                child: Text(r.name),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _controller.setSelectedReason(val);
            },
          ),

          const SizedBox(height: 14),

          // Mode of Shifting Toggle (OWN_HDD / BY_TRUCK)
          const Text('MODE OF SHIFTING *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.precision_manufacturing_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('OWN HDD', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  selected: _controller.modeOfShifting == 'OWN_HDD',
                  selectedColor: AppColors.primaryGreen,
                  labelStyle: TextStyle(
                    color: _controller.modeOfShifting == 'OWN_HDD' ? AppColors.white : AppColors.deepNavy,
                  ),
                  onSelected: (_) => _controller.setModeOfShifting('OWN_HDD'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('BY TRUCK', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  selected: _controller.modeOfShifting == 'BY_TRUCK',
                  selectedColor: AppColors.primaryGreen,
                  labelStyle: TextStyle(
                    color: _controller.modeOfShifting == 'BY_TRUCK' ? AppColors.white : AppColors.deepNavy,
                  ),
                  onSelected: (_) => _controller.setModeOfShifting('BY_TRUCK'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Required Date Field
          const Text('REQUIRED DATE *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          TextField(
            controller: _requiredDateController,
            readOnly: true,
            onTap: _selectDate,
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryGreen),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection3OriginPointA() {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trip_origin_rounded, color: AppColors.movingBlue, size: 18),
              SizedBox(width: 8),
              Text('3. Origin (Point A)', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 12),

          const Text('POINT A NAME / SITE *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          TextField(
            controller: _aPointController,
            decoration: const InputDecoration(
              hintText: 'e.g. Ring 3 Crossing, Sujangarh',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.white,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LATITUDE', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _aLatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LONGITUDE', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _aLngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection4DestinationPointB() {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.criticalRed, size: 18),
              SizedBox(width: 8),
              Text('4. Destination (Point B)', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 12),

          const Text('POINT B NAME / SITE *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 6),
          TextField(
            controller: _bPointController,
            decoration: const InputDecoration(
              hintText: 'e.g. Ratangarh Feeder Route, Block 2',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.white,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LATITUDE', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _bLatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LONGITUDE', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _bLngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
