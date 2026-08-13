import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/domain_models.dart';
import '../../core/services/chat_service.dart';
import '../../core/utils/size_config.dart';

/// A dialog showing the per-shot conversation with attachment support.
class ShotChatDialog extends StatefulWidget {
  final String shotId;
  final String shotCode;
  const ShotChatDialog({
    super.key,
    required this.shotId,
    required this.shotCode,
  });

  @override
  State<ShotChatDialog> createState() => _ShotChatDialogState();
}

class _ShotChatDialogState extends State<ShotChatDialog> {
  final ChatService _service = ChatService();
  final TextEditingController _input = TextEditingController();
  final TextEditingController _attachName = TextEditingController();
  final TextEditingController _attachUrl = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _showAttach = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _attachName.dispose();
    _attachUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp = await _service.getMessages(widget.shotId);
      _messages = ((resp['messages'] as List<dynamic>?) ?? const [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // keep empty on failure
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _attachName.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        shotId: widget.shotId,
        message: text,
        attachmentName: _attachName.text.trim().isEmpty
            ? null
            : _attachName.text.trim(),
        attachmentUrl: _attachUrl.text.trim().isEmpty
            ? null
            : _attachUrl.text.trim(),
      );
      _input.clear();
      _attachName.clear();
      _attachUrl.clear();
      _showAttach = false;
      await _load();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 480,
        height: 560,
        child: Column(
          children: [
            ListTile(
              title: Text('Chat \u2022 ${widget.shotCode}'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      padding: EdgeInsets.all(
                        SizeConfig.scaleWidth(context, 12),
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
            ),
            if (_showAttach)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.scaleWidth(context, 12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _attachName,
                      decoration: const InputDecoration(
                        labelText: 'Attachment name',
                        isDense: true,
                      ),
                    ),
                    TextField(
                      controller: _attachUrl,
                      decoration: const InputDecoration(
                        labelText: 'Attachment URL',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file,
                      color: _showAttach ? AppColors.brandGreen : null,
                    ),
                    onPressed: () => setState(() => _showAttach = !_showAttach),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.brandGreen),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: SizeConfig.scaleHeight(context, 10)),
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 10)),
        decoration: BoxDecoration(
          color: AppColors.brandGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(
            SizeConfig.scaleWidth(context, 10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.senderName ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: SizeConfig.fontSize(context, 12),
                color: AppColors.brandGreen,
              ),
            ),
            if (m.message.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: SizeConfig.scaleHeight(context, 2),
                ),
                child: Text(
                  m.message,
                  style: TextStyle(fontSize: SizeConfig.fontSize(context, 13)),
                ),
              ),
            if (m.attachmentName != null)
              Padding(
                padding: EdgeInsets.only(
                  top: SizeConfig.scaleHeight(context, 4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      size: SizeConfig.iconSize(context, 14),
                    ),
                    SizedBox(width: SizeConfig.scaleWidth(context, 4)),
                    Text(
                      m.attachmentName!,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
