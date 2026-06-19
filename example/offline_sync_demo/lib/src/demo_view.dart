import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'demo_controller.dart';
import 'models.dart';
import 'snapshot.dart';

/// The full dashboard: global toolbar, presets, two replica panels, status bar.
class DemoDashboard extends StatelessWidget {
  const DemoDashboard({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(controller: controller),
          const Gap(12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  child: _PresetPanel(controller: controller),
                ),
                const Gap(12),
                Expanded(
                  child: _ReplicaPanel(
                    controller: controller,
                    slot: ReplicaSlot.a,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _ReplicaPanel(
                    controller: controller,
                    slot: ReplicaSlot.b,
                  ),
                ),
                const Gap(12),
                Expanded(child: _ServerPanel(controller: controller)),
              ],
            ),
          ),
          const Gap(12),
          _StatusBar(controller: controller),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => OutlinedContainer(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(
              state: controller.online
                  ? CheckboxState.checked
                  : CheckboxState.unchecked,
              onChanged: controller.anyBusy
                  ? null
                  : (value) => unawaited(
                      controller.setOnline(value == CheckboxState.checked),
                    ),
              trailing: const Text('Connectivity'),
            ),
            Checkbox(
              state: controller.showHidden
                  ? CheckboxState.checked
                  : CheckboxState.unchecked,
              onChanged: controller.anyBusy
                  ? null
                  : (value) => unawaited(
                      controller.setShowHidden(value == CheckboxState.checked),
                    ),
              trailing: const Text('Show hidden rows'),
            ),
            OutlineButton(
              onPressed: controller.anyBusy
                  ? null
                  : () => unawaited(controller.refreshAll()),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  material.Icon(material.Icons.refresh, size: 16),
                  Gap(6),
                  Text('Refresh'),
                ],
              ),
            ),
            _ReplicaIsolationInfoButton(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _ReplicaIsolationInfoButton extends StatelessWidget {
  const _ReplicaIsolationInfoButton({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton.ghost(
      icon: const material.Icon(material.Icons.info_outline, size: 18),
      onPressed: () {
        showPopover(
          context: context,
          alignment: Alignment.bottomCenter,
          builder: (context) => OutlinedContainer(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(controller.replicaIsolationMessage),
            ),
          ),
        );
      },
    );
  }
}

class _PresetPanel extends StatelessWidget {
  const _PresetPanel({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        ...controller.replicas.values,
        controller.server,
      ]),
      builder: (context, _) => OutlinedContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const material.Icon(material.Icons.ads_click, size: 14),
                const Gap(6),
                Expanded(
                  child: Text(
                    'Seeding into ${controller.focusedTargetLabel}.',
                  ).small().muted(),
                ),
              ],
            ),
            const Gap(12),
            Tabs(
              index: controller.presetTab,
              onChanged: controller.setPresetTab,
              expand: true,
              children: const [
                TabItem(child: Text('CRUD')),
                TabItem(child: Text('Unique')),
                TabItem(child: Text('FK')),
              ],
            ),
            const Gap(12),
            Expanded(
              child: SingleChildScrollView(
                child: switch (controller.presetTab) {
                  0 => _CrudPresets(controller: controller),
                  1 => _UniquePresets(controller: controller),
                  _ => _ForeignKeyPresets(controller: controller),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrudPresets extends StatelessWidget {
  const _CrudPresets({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final disabled = controller.focusedTargetBusy;
    return _PresetGroup(
      children: [
        _PresetButton(
          icon: material.Icons.account_tree,
          title: 'Seed city/person/address/town',
          detail: 'Creates an ordinary editable graph on the seed target.',
          disabled: disabled,
          onPressed: controller.seedBasicGraph,
        ),
        _PresetButton(
          icon: material.Icons.data_object,
          title: 'Seed typed row',
          detail: 'Exercises bool, DateTime, int64, blob, enum, and UUID.',
          disabled: disabled,
          onPressed: controller.seedTypedRow,
        ),
        _PresetButton(
          icon: material.Icons.person_add_alt,
          title: 'Add person',
          detail: 'Creates one simple row on the seed target.',
          disabled: disabled,
          onPressed: controller.addPerson,
        ),
      ],
    );
  }
}

class _UniquePresets extends StatelessWidget {
  const _UniquePresets({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final disabled = controller.focusedTargetBusy;
    return _PresetGroup(
      children: [
        _PresetButton(
          icon: material.Icons.call_split,
          title: 'Concurrent unique insert',
          detail: 'Inserts a Unique row (same name) on the seed target.',
          recipe: '1. Seed on A → 2. Seed on B → 3. Sync A → 4. Sync B',
          disabled: disabled,
          onPressed: controller.createConcurrentUniqueInserts,
        ),
        _PresetButton(
          icon: material.Icons.key,
          title: 'UUID unique conflict',
          detail: 'Inserts a UniqueUuid row (same value) on the seed target.',
          recipe: '1. Seed on A → 2. Seed on B → 3. Sync A → 4. Sync B',
          disabled: disabled,
          onPressed: controller.createUuidUniqueConflict,
        ),
      ],
    );
  }
}

class _ForeignKeyPresets extends StatelessWidget {
  const _ForeignKeyPresets({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final disabled = controller.focusedTargetBusy;
    return _PresetGroup(
      children: [
        _PresetButton(
          icon: material.Icons.block,
          title: 'Restrict blocks delete',
          detail: 'Seeds a parent Person on the seed target.',
          recipe:
              '1. Seed on A → 2. Sync A → 3. Sync B → 4. Delete parent on '
              'A, add RestrictChild on B → 5. Sync both',
          disabled: disabled,
          onPressed: controller.createRestrictMergeScenario,
        ),
        _PresetButton(
          icon: material.Icons.account_tree,
          title: 'Add RestrictChild',
          detail: 'Attaches a restricting child to the first visible Person.',
          recipe: 'Use after the parent Person has been synced to this target.',
          disabled: disabled,
          onPressed: controller.addRestrictChild,
        ),
        _PresetButton(
          icon: material.Icons.link_off,
          title: 'Set-null projection',
          detail: 'Seeds a mayor candidate Person on the seed target.',
          recipe:
              '1. Seed on A → 2. Sync A → 3. Sync B → 4. Delete parent on '
              'A, add Town mayor ref on B → 5. Sync both',
          disabled: disabled,
          onPressed: controller.createSetNullProjectionScenario,
        ),
        _PresetButton(
          icon: material.Icons.hub,
          title: 'FK chain sketch',
          detail: 'Creates a root, cascade middle, blocker, and grandchildren.',
          disabled: disabled,
          onPressed: controller.seedForeignKeyChain,
        ),
      ],
    );
  }
}

class _PresetGroup extends StatelessWidget {
  const _PresetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children).gap(10);
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.icon,
    required this.title,
    required this.detail,
    required this.disabled,
    required this.onPressed,
    this.recipe,
  });

  final material.IconData icon;
  final String title;
  final String detail;
  final bool disabled;
  final String? recipe;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: disabled ? null : () => unawaited(onPressed()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          material.Icon(icon, size: 18),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const Gap(2),
                Text(detail).small().muted(),
                if (recipe != null) ...[
                  const Gap(4),
                  Text(recipe!).xSmall().muted(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplicaPanel extends StatelessWidget {
  const _ReplicaPanel({required this.controller, required this.slot});

  final DemoController controller;
  final ReplicaSlot slot;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.replica(slot)]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final state = controller.replica(slot);
        final target = slot == ReplicaSlot.a
            ? SeedTarget.replicaA
            : SeedTarget.replicaB;
        final focused = controller.focusedTarget == target;
        final canUseReplica = !controller.busy && !state.busy;
        final canSync =
            controller.online &&
            canUseReplica &&
            !state.streaming &&
            state.session != null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.setFocusedTarget(target),
          child: OutlinedContainer(
            borderColor: focused ? scheme.primary : null,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    material.Icon(
                      slot == ReplicaSlot.a
                          ? material.Icons.computer
                          : material.Icons.laptop,
                      size: 16,
                    ),
                    const Gap(6),
                    Text(slot.label).semiBold(),
                    const Gap(8),
                    _SyncBadge(state: state),
                    if (state.busy) ...[
                      const Gap(6),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(),
                      ),
                    ],
                    const Spacer(),
                    if (focused)
                      const _StatusPill(text: 'seed target', warn: false)
                    else
                      const Text('tap to target').xSmall().muted(),
                  ],
                ),
                const Gap(6),
                Row(
                  children: [
                    Text(
                      '${state.projection.visibleRowCount} visible · '
                      '${state.projection.hiddenRowCount} hidden',
                    ).xSmall().muted(),
                    const Spacer(),
                    PrimaryButton(
                      onPressed: canSync
                          ? () => unawaited(controller.syncReplica(slot))
                          : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          material.Icon(material.Icons.sync, size: 14),
                          Gap(4),
                          Text('Sync'),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Checkbox(
                      state: state.streaming
                          ? CheckboxState.checked
                          : CheckboxState.unchecked,
                      onChanged: (!controller.online || !canUseReplica)
                          ? null
                          : (value) => unawaited(
                              controller.setReplicaStreaming(
                                slot,
                                value == CheckboxState.checked,
                              ),
                            ),
                      trailing: const Text('Stream'),
                    ),
                    const Gap(4),
                    material.Tooltip(
                      message: 'Reset ${slot.label}: wipe local database',
                      child: IconButton.ghost(
                        icon: const material.Icon(
                          material.Icons.delete_outline,
                          size: 16,
                        ),
                        onPressed: canUseReplica
                            ? () => unawaited(controller.resetReplica(slot))
                            : null,
                      ),
                    ),
                  ],
                ),
                if (state.error != null) ...[
                  const Gap(6),
                  Row(
                    children: [
                      material.Icon(
                        material.Icons.error_outline,
                        size: 12,
                        color: scheme.destructive,
                      ),
                      const Gap(4),
                      Expanded(
                        child: material.Text(
                          state.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: material.TextStyle(
                            fontSize: 11,
                            color: scheme.destructive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Gap(8),
                const Divider(),
                const Gap(8),
                Expanded(
                  child: _ProjectionTree(
                    nodes: state.projection.nodes,
                    onTapRow: (ref) => unawaited(
                      showRowDetailSheet(context, controller, ref, slot),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServerPanel extends StatelessWidget {
  const _ServerPanel({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.server]),
      builder: (context, _) {
        final state = controller.server;
        final serverBusy = controller.busy || state.busy || state.loading;

        return OutlinedContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const material.Icon(material.Icons.dns, size: 16),
                  const Gap(6),
                  const Text('Server').semiBold(),
                  const Gap(8),
                  _ServerBadge(controller: controller),
                  if (state.busy) ...[
                    const Gap(6),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ],
              ),
              const Gap(6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.projection.visibleRowCount} rows · merged truth',
                    ).xSmall().muted(),
                  ),
                  material.Tooltip(
                    message: 'Reset server scope: clear all rows',
                    child: IconButton.ghost(
                      icon: const material.Icon(
                        material.Icons.delete_outline,
                        size: 16,
                      ),
                      onPressed: (!controller.online || serverBusy)
                          ? null
                          : () => unawaited(controller.resetServer()),
                    ),
                  ),
                  const Gap(4),
                  material.Tooltip(
                    message: 'Refresh server state',
                    child: IconButton.ghost(
                      icon: const material.Icon(
                        material.Icons.refresh,
                        size: 16,
                      ),
                      onPressed: (!controller.online || serverBusy)
                          ? null
                          : () => unawaited(controller.refreshServer()),
                    ),
                  ),
                ],
              ),
              const Gap(8),
              const Divider(),
              const Gap(8),
              Expanded(
                child: !controller.online
                    ? const Center(
                        child: Text('Offline — connect to view server state.'),
                      )
                    : state.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(state.error!).small().muted(),
                        ),
                      )
                    : _ProjectionTree(nodes: state.projection.nodes),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerBadge extends StatelessWidget {
  const _ServerBadge({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = controller.server;

    String label;
    Color bg;
    Color fg;
    if (!controller.online) {
      label = 'offline';
      bg = scheme.muted;
      fg = scheme.mutedForeground;
    } else if (state.busy || state.loading) {
      label = 'loading';
      bg = scheme.primary;
      fg = scheme.primaryForeground;
    } else if (state.error != null) {
      label = 'error';
      bg = scheme.destructive;
      fg = material.Colors.white;
    } else {
      label = state.lastFetchedLabel ?? 'idle';
      bg = scheme.muted;
      fg = scheme.mutedForeground;
    }

    return material.Tooltip(
      message: state.error ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: material.Text(
          label,
          style: material.TextStyle(color: fg, fontSize: 11),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state});

  final ReplicaState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = state.phase == SyncPhase.failed;
    final active =
        state.busy ||
        state.phase == SyncPhase.syncing ||
        state.phase == SyncPhase.streaming;
    final bg = failed
        ? scheme.destructive
        : active
        ? scheme.primary
        : scheme.muted;
    final fg = failed
        ? material.Colors.white
        : active
        ? scheme.primaryForeground
        : scheme.mutedForeground;
    final label = state.busy && state.phase == SyncPhase.idle
        ? 'Working'
        : state.lastSyncedLabel != null && state.phase == SyncPhase.idle
        ? state.lastSyncedLabel!
        : state.phase.label;
    return material.Tooltip(
      message: state.error ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: material.Text(
          label,
          style: material.TextStyle(color: fg, fontSize: 11),
        ),
      ),
    );
  }
}

class _ProjectionTree extends StatefulWidget {
  const _ProjectionTree({required this.nodes, this.onTapRow});

  final List<TreeNode<DemoTreeItem>> nodes;
  final void Function(DemoRowRef ref)? onTapRow;

  @override
  State<_ProjectionTree> createState() => _ProjectionTreeState();
}

class _ProjectionTreeState extends State<_ProjectionTree> {
  late List<TreeNode<DemoTreeItem>> nodes;

  @override
  void initState() {
    super.initState();
    nodes = widget.nodes;
  }

  @override
  void didUpdateWidget(covariant _ProjectionTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.nodes, widget.nodes)) {
      nodes = widget.nodes;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('No rows yet.'));
    }
    final onTapRow = widget.onTapRow;

    return TreeView<DemoTreeItem>(
      nodes: nodes,
      expandIcon: true,
      branchLine: BranchLine.path,
      builder: (context, node) {
        return _DemoTreeItemView(
          node: node,
          onTapRow: onTapRow,
          onExpand: TreeView.defaultItemExpandHandler(nodes, node, (value) {
            setState(() => nodes = value);
          }),
        );
      },
    );
  }
}

class _DemoTreeItemView extends StatefulWidget {
  const _DemoTreeItemView({
    required this.node,
    required this.onExpand,
    required this.onTapRow,
  });

  final TreeItem<DemoTreeItem> node;
  final ValueChanged<bool> onExpand;
  final void Function(DemoRowRef ref)? onTapRow;

  @override
  State<_DemoTreeItemView> createState() => _DemoTreeItemViewState();
}

class _DemoTreeItemViewState extends State<_DemoTreeItemView> {
  late final FocusNode _focusNode;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handlePressed() {
    final ref = widget.node.data.ref;
    final onTapRow = widget.onTapRow;
    if (ref != null && onTapRow != null) {
      onTapRow(ref);
      return;
    }

    if (widget.node.children.isNotEmpty) {
      widget.onExpand(!widget.node.expanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.node.data;
    final selectable = item.ref != null && widget.onTapRow != null;
    final expandable = widget.node.children.isNotEmpty;
    final interactive = selectable || expandable;
    final foreground = _hovered ? scheme.background : scheme.foreground;
    final mutedForeground = _hovered
        ? scheme.background.withAlpha(180)
        : scheme.mutedForeground;
    final iconColor = _hovered
        ? foreground
        : item.hidden
        ? scheme.mutedForeground
        : null;

    return material.MouseRegion(
      cursor: interactive
          ? material.SystemMouseCursors.click
          : material.SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 0),
        decoration: BoxDecoration(
          color: _hovered ? scheme.foreground : material.Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: TreeItemView(
          focusNode: _focusNode,
          leading: material.Icon(item.icon, size: 14, color: iconColor),
          onExpand: widget.onExpand,
          onPressed: interactive ? _handlePressed : null,
          child: Row(
            children: [
              Flexible(
                child: material.Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: material.TextStyle(
                    fontSize: 13,
                    fontWeight: item.metadata
                        ? material.FontWeight.normal
                        : material.FontWeight.w500,
                    color: item.hidden && !_hovered
                        ? scheme.mutedForeground
                        : foreground,
                    decoration: item.hidden
                        ? material.TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (item.detail != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: material.Text(
                      item.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: material.TextStyle(
                        fontSize: 11,
                        color: mutedForeground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => OutlinedContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            material.Icon(
              controller.online ? material.Icons.wifi : material.Icons.wifi_off,
              size: 18,
            ),
            const Gap(8),
            Expanded(child: Text(controller.status)),
            if (controller.anyBusy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Top-bar action that flips the app between light and dark themes.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({
    super.key,
    required this.isDark,
    required this.onToggle,
  });

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton.ghost(
      icon: material.Icon(
        isDark ? material.Icons.light_mode : material.Icons.dark_mode,
        size: 18,
      ),
      onPressed: onToggle,
    );
  }
}

/// Top-bar avatar that switches between demo users and creates new ones.
class UserAvatarMenu extends StatelessWidget {
  const UserAvatarMenu({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final user = controller.selectedUser;
        return GhostButton(
          onPressed: controller.anyBusy ? null : () => _open(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(initials: user?.initials ?? '?', size: 28),
              const Gap(8),
              Text(user?.username ?? 'no user'),
              const Gap(2),
              const material.Icon(material.Icons.arrow_drop_down, size: 18),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context) {
    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          for (final user in controller.users)
            MenuButton(
              leading: Avatar(initials: user.initials, size: 20),
              onPressed: (_) => unawaited(controller.switchUser(user)),
              child: Text(user.username),
            ),
          MenuButton(
            leading: const material.Icon(material.Icons.person_add, size: 16),
            onPressed: (_) =>
                unawaited(showCreateUserSheet(context, controller)),
            child: const Text('Create user…'),
          ),
        ],
      ),
    );
  }
}

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
  final _textController = material.TextEditingController();

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
    return material.Material(
      color: material.Colors.transparent,
      child: SizedBox(
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
              material.TextField(
                controller: _textController,
                autofocus: true,
                decoration: const material.InputDecoration(
                  labelText: 'Username',
                  isDense: true,
                  border: material.OutlineInputBorder(),
                ),
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
  final _controllers = <String, material.TextEditingController>{};
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
          _controllers[field.key] = material.TextEditingController(
            text: field.value,
          );
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
    return material.Material(
      color: material.Colors.transparent,
      child: SizedBox(
        width: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _detail == null
            ? const Center(child: Text('Row not found on this replica.'))
            : _buildDetail(context, _detail!),
      ),
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
              Text(detail.tableName).large().semiBold(),
              const Gap(8),
              _StatusPill(
                text: detail.visible ? 'visible' : 'hidden',
                warn: !detail.visible,
              ),
              const Spacer(),
              material.Tooltip(
                message: 'Close details',
                child: IconButton.ghost(
                  icon: const material.Icon(material.Icons.close, size: 16),
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
                child: material.TextField(
                  controller: _controllers[field.key],
                  onTap: () => _copyValue(_controllers[field.key]!.text),
                  onChanged: (_) {
                    if (_saveFailed) {
                      setState(() => _saveFailed = false);
                    }
                  },
                  decoration: material.InputDecoration(
                    labelText: field.label,
                    isDense: true,
                    border: const material.OutlineInputBorder(),
                  ),
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
          for (final entry in detail.displayFields.entries)
            _kv(context, entry.key, '${entry.value}'),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return material.MouseRegion(
      cursor: material.SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _copyValue(value),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: Text(label).xSmall().muted()),
              Expanded(
                child: material.Text(
                  value,
                  style: const material.TextStyle(fontSize: 12),
                ),
              ),
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
        if (states.contains(material.WidgetState.disabled)) return value;

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final color = scheme.brightness == material.Brightness.dark
            ? const Color(0xFFDC2626)
            : scheme.destructive;

        return BoxDecoration(
          color: states.contains(material.WidgetState.hovered)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: warn ? scheme.destructive : scheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: material.Text(
        text,
        style: material.TextStyle(
          color: warn ? material.Colors.white : scheme.primaryForeground,
          fontSize: 11,
        ),
      ),
    );
  }
}
