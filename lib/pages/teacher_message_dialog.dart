import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/teacher_app_shell.dart';

class TeacherMessageDialog extends StatefulWidget {
  final String studentName;

  const TeacherMessageDialog({
    super.key,
    required this.studentName,
  });

  @override
  State<TeacherMessageDialog> createState() => _TeacherMessageDialogState();
}

class _TeacherMessageDialogState extends State<TeacherMessageDialog> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  DateTime _date = DateTime(2026, 2, 6);

  @override
  void initState() {
    super.initState();
    _toController.text = widget.studentName;
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.studentName,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 22),

                const _FieldLabel('To'),
                const SizedBox(height: 10),
                _InputPill(controller: _toController, hint: ''),
                const SizedBox(height: 18),

                const _FieldLabel('Subject'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _InputPill(controller: _subjectController, hint: ''),
                    ),
                    const SizedBox(width: 14),
                    _DatePill(
                      date: _date,
                      onPick: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                Text(
                  'Quick templates',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TemplateButton(
                      label: 'Review Soon',
                      onTap: () => _messageController.text =
                          'Please review the module soon and let me know if you need help.',
                    ),
                    _TemplateButton(
                      label: 'Practice More!',
                      onTap: () => _messageController.text =
                          'You should practice more questions to strengthen your understanding.',
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  'Message',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _BigMessageBox(
                  controller: _messageController,
                  hint: 'Type your Message here..',
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Cancel',
                        primary: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Send',
                        primary: true,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- LABEL ---------------- */

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800),
    );
  }
}

/* ---------------- INPUT ---------------- */

class _InputPill extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _InputPill({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.black45, fontSize: 11),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/* ---------------- DATE ---------------- */

class _DatePill extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPick;

  const _DatePill({
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final label = '${two(date.month)}/${two(date.day)}/${date.year}';

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.calendar_month_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/* ---------------- TEMPLATE ---------------- */

class _TemplateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/* ---------------- MESSAGE BOX ---------------- */

class _BigMessageBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _BigMessageBox({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.black45, fontSize: 11),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/* ---------------- ACTION BUTTON ---------------- */

class _ActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: primary ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}