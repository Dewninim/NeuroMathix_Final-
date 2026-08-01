import 'package:flutter/material.dart';

import '../services/teacher_service.dart';

class TeacherMessageDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? defaultSubject;
  final String? defaultMessage;

  const TeacherMessageDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    this.defaultSubject,
    this.defaultMessage,
  });

  @override
  State<TeacherMessageDialog> createState() => _TeacherMessageDialogState();
}

class _TeacherMessageDialogState extends State<TeacherMessageDialog> {
  final TeacherService _service = TeacherService();
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;
  final TextEditingController _practiceController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(
      text: widget.defaultSubject ?? 'Learning support',
    );
    _messageController = TextEditingController(
      text: widget.defaultMessage ?? '',
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _practiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Message ${widget.studentName}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Quick templates',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Review overdue'),
                    onPressed: () {
                      _subjectController.text = 'Please complete your review';
                      _messageController.text =
                          'Your personalized review is overdue. Please complete it today so the concept does not fall below the recommended retention level.';
                    },
                  ),
                  ActionChip(
                    label: const Text('Practice more'),
                    onPressed: () {
                      _subjectController.text = 'Additional practice recommended';
                      _messageController.text =
                          'Your recent performance shows that this concept needs more practice. Focus on the repeated error pattern and try the practice question below.';
                    },
                  ),
                  ActionChip(
                    label: const Text('Good progress'),
                    onPressed: () {
                      _subjectController.text = 'Good progress';
                      _messageController.text =
                          'You are improving well. Keep following the review schedule and try to solve the next questions without using hints first.';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _messageController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _practiceController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Optional practice question',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a subject and message.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _service.sendDirectMessage(
        studentId: widget.studentId,
        subject: subject,
        message: message,
        practiceQuestion: _practiceController.text.trim().isEmpty
            ? null
            : _practiceController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}
