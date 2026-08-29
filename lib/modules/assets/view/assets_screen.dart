import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/access_provider.dart';
import '../../../core/utils/size_config.dart';
import '../../../core/services/asset_service.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final AssetService _service = AssetService();
  List<AttachmentModel> _assets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _service.getAssets();
      _assets = ((resp['assets'] as List<dynamic>?) ?? const [])
          .map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(AttachmentModel a) async {
    final user = context.read<AuthController>().currentUser;
    if (!context.read<AccessProvider>().deleteEnabledForDepartment(
      user?.department,
    )) {
      return;
    }
    try {
      await _service.deleteAsset(a.attachmentId);
      await _load();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _add() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AssetDialog(service: _service),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add Asset'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shared documents & supporting material',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingWidget();
    if (_error != null && _assets.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Could not load assets',
        description: _error!,
        actionLabel: 'Retry',
        onActionPressed: _load,
      );
    }
    final user = context.read<AuthController>().currentUser;
    final deleteEnabled = context
        .watch<AccessProvider>()
        .deleteEnabledForDepartment(user?.department);
    if (_assets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.folder_outlined,
        title: 'No assets',
        description: 'Add shared documents or reference material.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _assets.length,
        separatorBuilder: (_, _) =>
            SizedBox(height: SizeConfig.scaleHeight(context, 8)),
        itemBuilder: (_, i) {
          final a = _assets[i];
          return GlassContainer(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.scaleWidth(context, 12),
              vertical: SizeConfig.scaleHeight(context, 4),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.brandGreen,
              ),
              title: Text(
                a.fileName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: SizeConfig.fontSize(context, 13),
                ),
              ),
              subtitle: Text(
                '${a.uploaderName ?? 'Unknown'}  \u2022  ${a.fileType ?? 'file'}'
                '${a.shotId != null ? '  \u2022  ${a.shotId}' : ''}',
                style: TextStyle(fontSize: SizeConfig.fontSize(context, 11)),
              ),
              trailing: deleteEnabled
                  ? IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: SizeConfig.iconSize(context, 18),
                      ),
                      onPressed: () => _delete(a),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _AssetDialog extends StatefulWidget {
  final AssetService service;
  const _AssetDialog({required this.service});

  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _type = TextEditingController();
  final _shotId = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _type.dispose();
    _shotId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Asset'),
      content: SizedBox(
        width: SizeConfig.scaleWidth(context, 380),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'File name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'File URL'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _type,
                decoration: const InputDecoration(
                  labelText: 'File type (optional)',
                ),
              ),
              TextFormField(
                controller: _shotId,
                decoration: const InputDecoration(
                  labelText: 'Shot ID (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  height: SizeConfig.iconSize(context, 18),
                  width: SizeConfig.iconSize(context, 18),
                  child: CircularProgressIndicator(
                    strokeWidth: SizeConfig.scaleWidth(context, 2),
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.addAsset({
        'fileName': _name.text.trim(),
        'fileUrl': _url.text.trim(),
        if (_type.text.trim().isNotEmpty) 'fileType': _type.text.trim(),
        if (_shotId.text.trim().isNotEmpty) 'shotId': _shotId.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}
