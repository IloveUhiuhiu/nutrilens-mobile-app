import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shows the shared bottom sheet for entering a quantity (servings, grams,
/// etc). Used by the barcode, USDA search, and meal-edit flows so they all
/// share one input experience instead of mixing bottom sheets and dialogs.
///
/// Returns the confirmed value, or `null` if the user dismissed the sheet.
Future<double?> showQuantityInputSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required double initialValue,
  required double step,
  required double min,
  double max = 9999,
  required String Function(double value) formatLabel,
  String confirmLabel = 'Xác nhận',
  // Renders a live nutrition preview below the stepper, rebuilt on every
  // value change, so the user sees the impact of the quantity before saving.
  Widget Function(double value)? previewBuilder,
}) {
  return showModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _QuantityInputSheet(
        title: title,
        subtitle: subtitle,
        initialValue: initialValue,
        step: step,
        min: min,
        max: max,
        formatLabel: formatLabel,
        confirmLabel: confirmLabel,
        previewBuilder: previewBuilder,
      );
    },
  );
}

/// The actual `-` / editable-number / `+` stepper used inside the quantity
/// bottom sheet. Exposed publicly so flows that embed the quantity input
/// directly in their own bottom sheet (instead of opening a separate one via
/// [showQuantityInputSheet]) still render the exact same input experience.
class QuantityStepperRow extends StatelessWidget {
  const QuantityStepperRow({
    super.key,
    required this.controller,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTextChanged,
  });

  final TextEditingController controller;
  final double value;
  final double step;
  final double min;
  final double max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: value <= min ? null : onDecrement,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textAlign: TextAlign.center,
            onChanged: onTextChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: value >= max ? null : onIncrement,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _QuantityInputSheet extends StatefulWidget {
  const _QuantityInputSheet({
    required this.title,
    required this.subtitle,
    required this.initialValue,
    required this.step,
    required this.min,
    required this.max,
    required this.formatLabel,
    required this.confirmLabel,
    this.previewBuilder,
  });

  final String title;
  final String? subtitle;
  final double initialValue;
  final double step;
  final double min;
  final double max;
  final String Function(double value) formatLabel;
  final String confirmLabel;
  final Widget Function(double value)? previewBuilder;

  @override
  State<_QuantityInputSheet> createState() => _QuantityInputSheetState();
}

class _QuantityInputSheetState extends State<_QuantityInputSheet> {
  late double _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _controller = TextEditingController(text: widget.formatLabel(_value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setValue(double next) {
    final clamped = next.clamp(widget.min, widget.max).toDouble();
    setState(() {
      _value = clamped;
      _controller.text = widget.formatLabel(_value);
    });
  }

  void _onTextChanged(String text) {
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    setState(() => _value = parsed.clamp(widget.min, widget.max).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + AppTheme.spacingLg;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          QuantityStepperRow(
            controller: _controller,
            value: _value,
            step: widget.step,
            min: widget.min,
            max: widget.max,
            onDecrement: () => _setValue(_value - widget.step),
            onIncrement: () => _setValue(_value + widget.step),
            onTextChanged: _onTextChanged,
          ),
          if (widget.previewBuilder != null) ...[
            const SizedBox(height: 16),
            widget.previewBuilder!(_value),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_value),
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
