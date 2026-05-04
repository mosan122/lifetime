import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Diálogo con [TextEditingController] propio (se dispone en [dispose] del estado).
Future<String?> showPersonNameAlertDialog({
  required BuildContext context,
  required String title,
  String? initialValue,
  String hintText = 'Nombre',
  String submitLabel = 'Guardar',
  TextCapitalization textCapitalization = TextCapitalization.none,
  bool useRootNavigator = false,
}) {
  return showDialog<String?>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (ctx) => PersonNameAlertDialog(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
      submitLabel: submitLabel,
      textCapitalization: textCapitalization,
    ),
  );
}

class PersonNameAlertDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final String hintText;
  final String submitLabel;
  final TextCapitalization textCapitalization;

  const PersonNameAlertDialog({
    super.key,
    required this.title,
    this.initialValue,
    required this.hintText,
    required this.submitLabel,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<PersonNameAlertDialog> createState() => _PersonNameAlertDialogState();
}

class _PersonNameAlertDialogState extends State<PersonNameAlertDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cream,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(
            widget.submitLabel,
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
