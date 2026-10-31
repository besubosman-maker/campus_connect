import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final String targetType; // 'listing' or 'user'
  final String targetId;
  final String targetTitle;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final ReportService _reportService = ReportService();
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Scam or Fraudulent Offer',
    'Counterfeit or Prohibited Item',
    'Inappropriate or Abusive Behavior',
    'Misleading Price / Photos',
    'Suspicious or Dangerous Meetup',
    'Other Issue',
  ];

  late String _selectedReason;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport(UserModel currentUser) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _reportService.submitReport(
        reporterId: currentUser.uid,
        reporterName: currentUser.name,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetTitle: widget.targetTitle,
        reason: _selectedReason,
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚩 Report submitted. Our Super Admin team will investigate immediately.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context);
    final currentUser = auth.userModel;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.targetType == 'listing'
                              ? (locale.isAmharic ? 'ዕቃውን አሳውቅ' : 'Report Listing')
                              : (locale.isAmharic ? 'ተጠቃሚውን ሪፖርት አድርግ' : 'Report User'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          widget.targetTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Reason
              Text(
                locale.isAmharic ? 'ምክንያት ይምረጡ' : 'Select Reason',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _reasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return ChoiceChip(
                    label: Text(reason),
                    selected: isSelected,
                    selectedColor: Colors.redAccent.shade100.withOpacity(0.35),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.red.shade900 : Colors.black87,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? Colors.redAccent : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedReason = reason);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Additional Details Text Field
              Text(
                locale.isAmharic ? 'ተጨማሪ ማብራሪያ (ከተፈለገ)' : 'Additional Details (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: locale.isAmharic
                      ? 'እባክዎ የተፈጠረውን ችግር በአጭሩ ያብራሩ...'
                      : 'Provide any extra context to help our moderation team...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text(locale.isAmharic ? 'ተው' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting || currentUser == null
                          ? null
                          : () => _submitReport(currentUser),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              locale.isAmharic ? 'ሪፖርት ላክ' : 'Submit Report',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
