import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/remote/remote_connection.dart';
import '../../platform_io/remote/remote_models.dart';
import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';

/// Result of the custom-paths server browser flow.
class RemoteCustomPathsSelection {
  const RemoteCustomPathsSelection({
    required this.projectName,
    required this.annotationsPath,
    required this.imagesRootPath,
    required this.predictionsPath,
  });

  final String projectName;
  final String annotationsPath;
  final String imagesRootPath;
  final String predictionsPath;
}

class RemoteServerBrowserDialog extends StatefulWidget {
  const RemoteServerBrowserDialog({required this.connection, super.key});

  final RemoteServerConnection connection;

  static Future<String?> pickJsonFile({
    required BuildContext context,
    required RemoteServerConnection connection,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ServerPathPicker(
        connection: connection,
        directoryMode: false,
      ),
    );
  }

  @override
  State<RemoteServerBrowserDialog> createState() =>
      _RemoteServerBrowserDialogState();
}

class _RemoteServerBrowserDialogState extends State<RemoteServerBrowserDialog> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Remote project');
  String? _annotationsPath;
  String? _imagesRootPath;
  String? _predictionsPath;

  AppLocalizations get _l10n => AppLocaleScope.l10n(context);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pick({
    required bool directory,
    required void Function(String) onPicked,
  }) async {
    final String? path = await showDialog<String>(
      context: context,
      builder: (_) => _ServerPathPicker(
        connection: widget.connection,
        directoryMode: directory,
      ),
    );
    if (path != null) {
      setState(() => onPicked(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10n;
    final bool ready = _annotationsPath != null &&
        _imagesRootPath != null &&
        _predictionsPath != null;
    return AlertDialog(
      title: Text(l10n.t(MessageKey.remoteCreateFromServerPaths)),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            _pickRow(
              l10n.t(MessageKey.remoteAnnotations),
              _annotationsPath,
              () => _pick(
                directory: false,
                onPicked: (p) => _annotationsPath = p,
              ),
            ),
            _pickRow(
              l10n.t(MessageKey.remoteImagesRoot),
              _imagesRootPath,
              () => _pick(
                directory: true,
                onPicked: (p) => _imagesRootPath = p,
              ),
            ),
            _pickRow(
              l10n.t(MessageKey.remotePredictions),
              _predictionsPath,
              () => _pick(
                directory: false,
                onPicked: (p) => _predictionsPath = p,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop(
                    RemoteCustomPathsSelection(
                      projectName: _nameController.text.trim(),
                      annotationsPath: _annotationsPath!,
                      imagesRootPath: _imagesRootPath!,
                      predictionsPath: _predictionsPath!,
                    ),
                  )
              : null,
          child: Text(l10n.t(MessageKey.remoteOpenProject)),
        ),
      ],
    );
  }

  Widget _pickRow(String label, String? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('…')),
        ],
      ),
    );
  }
}

/// A navigable picker over the server's allowed roots. Returns an absolute
/// server path (file when [directoryMode] is false, directory otherwise).
class _ServerPathPicker extends StatefulWidget {
  const _ServerPathPicker({
    required this.connection,
    required this.directoryMode,
  });

  final RemoteServerConnection connection;
  final bool directoryMode;

  @override
  State<_ServerPathPicker> createState() => _ServerPathPickerState();
}

class _ServerPathPickerState extends State<_ServerPathPicker> {
  List<ServerRoot> _roots = const [];
  String? _rootId;
  String _path = '';
  ServerBrowseListing? _listing;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  AppLocalizations get _l10n => AppLocaleScope.l10n(context);

  Future<void> _loadRoots() async {
    setState(() => _busy = true);
    try {
      final List<ServerRoot> roots = await widget.connection.listRoots();
      setState(() {
        _roots = roots;
        _busy = false;
      });
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _open(String rootId, String path) async {
    setState(() => _busy = true);
    try {
      final ServerBrowseListing listing = await widget.connection.browse(
        rootId: rootId,
        path: path,
        jsonOnly: !widget.directoryMode,
      );
      setState(() {
        _rootId = rootId;
        _path = path;
        _listing = listing;
        _busy = false;
      });
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  String _absChild(String name) {
    final String base = _listing?.absPath ?? '';
    return base.isEmpty ? name : '$base/$name';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10n;
    return AlertDialog(
      title: Text(
        widget.directoryMode
            ? l10n.t(MessageKey.remoteSelectImagesRoot)
            : l10n.t(MessageKey.remoteBrowseServer),
      ),
      content: SizedBox(
        width: 560,
        height: 420,
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _listing == null
                    ? _buildRoots()
                    : _buildListing(l10n),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.directoryMode && _listing != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_listing!.absPath ?? ''),
            child: const Text('Select this folder'),
          ),
      ],
    );
  }

  Widget _buildRoots() {
    return ListView(
      children: [
        for (final ServerRoot root in _roots)
          ListTile(
            leading: const Icon(Icons.storage),
            title: Text(root.label),
            onTap: () => _open(root.id, ''),
          ),
      ],
    );
  }

  Widget _buildListing(AppLocalizations l10n) {
    final ServerBrowseListing listing = _listing!;
    final List<Widget> rows = [];
    if (_path.isNotEmpty) {
      final int slash = _path.lastIndexOf('/');
      final String parent = slash == -1 ? '' : _path.substring(0, slash);
      rows.add(
        ListTile(
          leading: const Icon(Icons.arrow_upward),
          title: Text(l10n.t(MessageKey.remoteUp)),
          onTap: () => _open(_rootId!, parent),
        ),
      );
    }
    for (final ServerBrowseEntry entry in listing.entries) {
      if (entry.isDirectory) {
        rows.add(
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(entry.name),
            onTap: () => _open(_rootId!, entry.path),
          ),
        );
      } else if (!widget.directoryMode) {
        rows.add(
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(entry.name),
            onTap: () => Navigator.of(context).pop(_absChild(entry.name)),
          ),
        );
      }
    }
    return ListView(children: rows);
  }
}
