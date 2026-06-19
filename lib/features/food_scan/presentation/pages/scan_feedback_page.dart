import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../cubit/scan_feedback_cubit.dart';

const _issueOptions = [
  _IssueOption(
    value: 'wrong_component',
    label: 'Sai nguyên liệu',
    description: 'AI nhận diện sai hoặc thiếu nguyên liệu trong món ăn.',
  ),
  _IssueOption(
    value: 'wrong_food_region',
    label: 'Sai vùng nhận diện',
    description: 'Vùng khoanh nhận diện sai vị trí món ăn trong ảnh.',
  ),
];

class ScanFeedbackPage extends StatefulWidget {
  const ScanFeedbackPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<ScanFeedbackPage> createState() => _ScanFeedbackPageState();
}

class _ScanFeedbackPageState extends State<ScanFeedbackPage> {
  final _selectedIssues = <String>{};
  final _ingredientControllers = <TextEditingController>[];
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ingredientControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_selectedIssues.isEmpty) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng chọn ít nhất một loại lỗi.',
        type: AppAlertType.warning,
      );
      return;
    }

    final actualComponents = _ingredientControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final cubit = context.read<ScanFeedbackCubit>();
    await cubit.submit(
      jobId: widget.jobId,
      issueTypes: _selectedIssues.toList(),
      actualComponents: actualComponents,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    if (cubit.state.succeeded) {
      AppAlerts.showToast(
        context,
        message: 'Cảm ơn! Phản hồi của bạn đã được ghi nhận.',
        type: AppAlertType.success,
      );
      context.pop();
    } else {
      AppAlerts.showToast(
        context,
        message: cubit.state.errorMessage ?? 'Không thể gửi phản hồi.',
        type: AppAlertType.critical,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: BlocBuilder<ScanFeedbackCubit, ScanFeedbackState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Báo lỗi nhận diện',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Giúp chúng tôi cải thiện AI bằng cách mô tả lỗi nhận diện.',
                style: TextStyle(color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 20),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Loại lỗi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._issueOptions.map((opt) => CheckboxListTile(
                          value: _selectedIssues.contains(opt.value),
                          title: Text(opt.label),
                          subtitle: Text(
                            opt.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedIssues.add(opt.value);
                              } else {
                                _selectedIssues.remove(opt.value);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Nguyên liệu thực tế',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addIngredientField,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm'),
                        ),
                      ],
                    ),
                    const Text(
                      'Chỉ cần nhập tên nguyên liệu, không cần khối lượng hay dinh dưỡng.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ..._ingredientControllers.asMap().entries.map((entry) {
                      final i = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: entry.value,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'VD: Cơm trắng',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            if (_ingredientControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => _removeIngredientField(i),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PremiumCard(
                child: TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú thêm',
                    hintText: 'Mô tả thêm về lỗi nhận diện...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: state.isLoading ? null : _submit,
                icon: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Gửi phản hồi'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IssueOption {
  const _IssueOption({
    required this.value,
    required this.label,
    required this.description,
  });

  final String value;
  final String label;
  final String description;
}
