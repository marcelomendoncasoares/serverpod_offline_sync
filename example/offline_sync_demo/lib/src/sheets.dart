part of 'demo_view.dart';

/// Opens the right-hand sheet that creates and switches to a new demo user.
Future<void> showCreateUserSheet(
  BuildContext context,
  DemoController controller,
) {
  return openSheet(
    context: context,
    position: OverlayPosition.right,
    builder: (context) => _CreateUserSheet(controller: controller),
  );
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet({required this.controller});

  final DemoController controller;

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _textController.text;
    closeOverlay(context);
    unawaited(widget.controller.createOrSwitchUser(username));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create demo user').large().semiBold(),
            const Gap(4),
            const Text(
              'Authenticates by username only and opens its replicas.',
            ).small().muted(),
            const Gap(12),
            const Text('Username').small().muted(),
            const Gap(4),
            TextField(
              controller: _textController,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const Gap(12),
            PrimaryButton(
              onPressed: _submit,
              child: const Text('Create & switch'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the right-hand sheet showing the complete record for [ref].
Future<void> showRowDetailSheet(
  BuildContext context,
  DemoController controller,
  DemoRowRef ref,
  ReplicaSlot slot,
) {
  return openSheet(
    context: context,
    position: OverlayPosition.right,
    builder: (context) =>
        _RowDetailSheet(controller: controller, ref: ref, slot: slot),
  );
}

class _RowDetailSheet extends StatefulWidget {
  const _RowDetailSheet({
    required this.controller,
    required this.ref,
    required this.slot,
  });

  final DemoController controller;
  final DemoRowRef ref;
  final ReplicaSlot slot;

  @override
  State<_RowDetailSheet> createState() => _RowDetailSheetState();
}

class _RowDetailSheetState extends State<_RowDetailSheet> {
  final _controllers = <String, TextEditingController>{};
  RowDetail? _detail;
  bool _loading = true;
  bool _saveFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final detail = await widget.controller.loadDetail(widget.ref, widget.slot);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
      if (detail != null) {
        for (final field in detail.editable) {
          _controllers[field.key] = TextEditingController(text: field.value);
        }
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_saving) return;
    unawaited(_saveAsync());
  }

  Future<void> _saveAsync() async {
    setState(() {
      _saveFailed = false;
      _saving = true;
    });

    final values = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
    final saved = await widget.controller.applyEdit(
      widget.ref,
      widget.slot,
      values,
    );

    if (!mounted) return;
    if (saved) {
      closeOverlay(context);
      return;
    }

    final detail = _detail;
    if (detail != null) {
      for (final field in detail.editable) {
        _controllers[field.key]?.text = field.value;
      }
    }

    setState(() {
      _saveFailed = true;
      _saving = false;
    });
  }

  void _delete() {
    closeOverlay(context);
    unawaited(widget.controller.deleteRow(widget.ref, widget.slot));
  }

  void _copyValue(String value) {
    unawaited(Clipboard.setData(ClipboardData(text: value)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
          ? const Center(child: Text('Row not found on this replica.'))
          : _buildDetail(context, _detail!),
    );
  }

  Widget _buildDetail(BuildContext context, RowDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(tableLabel(detail.tableName)).large().semiBold(),
              const Gap(8),
              _StatusPill(
                text: detail.visible ? 'visible' : 'hidden',
                warn: !detail.visible,
              ),
              const Spacer(),
              Tooltip(
                tooltip: (context) =>
                    const TooltipContainer(child: Text('Close details')),
                child: IconButton.ghost(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => closeOverlay(context),
                ),
              ),
            ],
          ),
          const Gap(4),
          Text(detail.slot.label).small().muted(),
          const Gap(12),
          _kv(context, 'Row UUID', detail.uuid),
          _kv(context, 'Scope id', detail.scopeId ?? '—'),
          _kv(
            context,
            'Visibility',
            detail.visible ? 'visible' : 'hidden on this replica',
          ),
          const Gap(16),
          if (_controllers.isNotEmpty) ...[
            const Text('Edit fields').semiBold(),
            const Gap(8),
            for (final field in detail.editable)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(field.key).small().muted(),
                    const Gap(4),
                    TextField(
                      controller: _controllers[field.key],
                      onTap: () => _copyValue(_controllers[field.key]!.text),
                      onChanged: (_) {
                        if (_saveFailed) {
                          setState(() => _saveFailed = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: _SaveButton(
                    failed: _saveFailed,
                    saving: _saving,
                    onPressed: _save,
                  ),
                ),
                const Gap(8),
                _SolidDestructiveButton(
                  onPressed: _delete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ] else
            _SolidDestructiveButton(
              onPressed: _delete,
              child: const Text('Delete'),
            ),
          const Gap(16),
          const Text('Full record').semiBold(),
          const Gap(8),
          for (final entry in detail.fields.entries)
            _kv(context, entry.key, '${entry.value}'),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _copyValue(value),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: Text(label).xSmall().muted()),
              Expanded(child: Text(value).xSmall()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.failed,
    required this.saving,
    required this.onPressed,
  });

  final bool failed;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(saving ? 'Saving' : 'Save');
    if (failed) {
      return _SolidDestructiveButton(onPressed: onPressed, child: child);
    }

    return PrimaryButton(onPressed: onPressed, child: child);
  }
}

class _SolidDestructiveButton extends StatelessWidget {
  const _SolidDestructiveButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ButtonStyleOverride.inherit(
      decoration: (context, states, value) {
        if (states.contains(WidgetState.disabled)) return value;

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final color = scheme.brightness == Brightness.dark
            ? const Color(0xFFDC2626)
            : scheme.destructive;

        return BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? const Color(0xFFB91C1C)
              : color,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        );
      },
      child: DestructiveButton(onPressed: onPressed, child: child),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.warn});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Badge(
      text: text,
      background: warn ? scheme.destructive : scheme.primary,
      foreground: warn ? Colors.white : scheme.primaryForeground,
    );
  }
}
