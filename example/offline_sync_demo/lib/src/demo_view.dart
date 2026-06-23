import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'demo_controller.dart';
import 'models.dart';
import 'relationships.dart';
import 'snapshot.dart';

part 'sheets.dart';

/// The full dashboard: global toolbar, scenario rail, replica panels, server.
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
                  width: 280,
                  child: _ScenarioRail(controller: controller),
                ),
                const Gap(12),
                Expanded(
                  flex: 4,
                  child: _ReplicaPanel(
                    controller: controller,
                    slot: ReplicaSlot.a,
                  ),
                ),
                const Gap(12),
                Expanded(
                  flex: 4,
                  child: _ReplicaPanel(
                    controller: controller,
                    slot: ReplicaSlot.b,
                  ),
                ),
                const Gap(12),
                Expanded(flex: 3, child: _ServerPanel(controller: controller)),
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
            material.Tooltip(
              message: 'Wipe both replicas and the server scope at once',
              child: OutlineButton(
                onPressed: controller.anyBusy
                    ? null
                    : () => unawaited(controller.resetAll()),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    material.Icon(
                      material.Icons.delete_sweep_outlined,
                      size: 16,
                    ),
                    Gap(6),
                    Text('Reset all'),
                  ],
                ),
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

// --- Scenario rail ---------------------------------------------------------

class _ScenarioRail extends StatelessWidget {
  const _ScenarioRail({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final active = controller.activeScenario;
        return OutlinedContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const material.Icon(material.Icons.list_alt, size: 16),
                  const Gap(6),
                  const Text('Scenarios').semiBold(),
                  const Spacer(),
                  if (active != null)
                    IconButton.ghost(
                      icon: const material.Icon(material.Icons.close, size: 16),
                      onPressed: controller.stopScenario,
                    ),
                ],
              ),
              const Gap(4),
              const Text(
                'Optional quick-starts. Everything here is also doable by hand '
                'on the trees.',
              ).xSmall().muted(),
              const Gap(12),
              Expanded(
                child: SingleChildScrollView(
                  child: active == null
                      ? _ScenarioList(controller: controller)
                      : _ScenarioSteps(
                          controller: controller,
                          scenario: active,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScenarioList extends StatelessWidget {
  const _ScenarioList({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final scenario in controller.scenarios)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlineButton(
              onPressed: controller.anyBusy
                  ? null
                  : () => controller.startScenario(scenario),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const material.Icon(
                    material.Icons.play_circle_outline,
                    size: 18,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scenario.title),
                        const Gap(2),
                        Text(scenario.summary).xSmall().muted(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ScenarioSteps extends StatelessWidget {
  const _ScenarioSteps({required this.controller, required this.scenario});

  final DemoController controller;
  final Scenario scenario;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = controller.activeSteps;
    final current = controller.scenarioStepIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(scenario.title).semiBold(),
        const Gap(2),
        Text(scenario.summary).xSmall().muted(),
        const Gap(12),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                material.Icon(
                  i < current
                      ? material.Icons.check_circle
                      : i == current
                      ? material.Icons.radio_button_checked
                      : material.Icons.radio_button_unchecked,
                  size: 16,
                  color: i < current
                      ? scheme.primary
                      : i == current
                      ? scheme.foreground
                      : scheme.mutedForeground,
                ),
                const Gap(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      material.Text(
                        steps[i].label,
                        style: material.TextStyle(
                          fontSize: 13,
                          color: i == current
                              ? scheme.foreground
                              : scheme.mutedForeground,
                          fontWeight: i == current
                              ? material.FontWeight.w500
                              : material.FontWeight.normal,
                        ),
                      ),
                      if (steps[i].replica != null)
                        Text(steps[i].replica!.label).xSmall().muted(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Gap(8),
        if (controller.scenarioComplete)
          PrimaryButton(
            onPressed: controller.stopScenario,
            child: const Text('Done'),
          )
        else
          PrimaryButton(
            onPressed: controller.anyBusy
                ? null
                : () => unawaited(controller.runNextScenarioStep()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const material.Icon(material.Icons.play_arrow, size: 16),
                const Gap(4),
                Text('Run step ${current + 1}'),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Replica panel ---------------------------------------------------------

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
        final canUseReplica = !controller.busy && !state.busy;
        final canSync =
            controller.online &&
            canUseReplica &&
            !state.streaming &&
            state.session != null;
        final actions = _RowActions(controller: controller, slot: slot);

        return OutlinedContainer(
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
                  Text(
                    '${state.projection.visibleRowCount} visible · '
                    '${state.projection.hiddenRowCount} hidden',
                  ).xSmall().muted(),
                ],
              ),
              const Gap(8),
              Row(
                children: [
                  _NewRowButton(
                    controller: controller,
                    slot: slot,
                    enabled: canUseReplica && state.session != null,
                  ),
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
                  const Gap(12),
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
                child: controller.initializing
                    ? const _PanelLoading(message: 'Opening local database…')
                    : _ProjectionTree(
                        key: ValueKey(controller.showHidden),
                        nodes: state.projection.nodes,
                        actions: actions,
                        onTapRow: (ref) => unawaited(
                          showRowDetailSheet(context, controller, ref, slot),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bundles the per-replica context the row action menus need.
class _RowActions {
  _RowActions({required this.controller, required this.slot});

  final DemoController controller;
  final ReplicaSlot slot;
}

class _NewRowButton extends StatelessWidget {
  const _NewRowButton({
    required this.controller,
    required this.slot,
    required this.enabled,
  });

  final DemoController controller;
  final ReplicaSlot slot;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: enabled ? () => _open(context) : null,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          material.Icon(material.Icons.add, size: 14),
          Gap(4),
          Text('Add data'),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            leading: const material.Icon(material.Icons.account_tree, size: 16),
            onPressed: (_) => unawaited(controller.seedBasicGraph(slot)),
            child: const Text('Seed city/person/address/town'),
          ),
          MenuButton(
            leading: const material.Icon(material.Icons.data_object, size: 16),
            onPressed: (_) => unawaited(controller.seedTypedRow(slot)),
            child: const Text('Seed typed row'),
          ),
          MenuButton(
            leading: const material.Icon(material.Icons.hub, size: 16),
            onPressed: (_) => unawaited(controller.seedForeignKeyChain(slot)),
            child: const Text('Seed FK chain'),
          ),
          for (final table in controller.catalog.creatableRootTables)
            MenuButton(
              leading: material.Icon(
                iconForTable(table, hidden: false),
                size: 16,
              ),
              onPressed: (_) => unawaited(controller.createRoot(slot, table)),
              child: Text(tableLabel(table)),
            ),
        ],
      ),
    );
  }
}

// --- Server panel ----------------------------------------------------------

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
                  _ServerSeedButton(
                    controller: controller,
                    enabled: controller.online && !serverBusy,
                  ),
                  const Gap(4),
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
                child: controller.initializing
                    ? const _PanelLoading(message: 'Loading server state…')
                    : !controller.online
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
                    : _ProjectionTree(
                        key: ValueKey(controller.showHidden),
                        nodes: state.projection.nodes,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerSeedButton extends StatelessWidget {
  const _ServerSeedButton({required this.controller, required this.enabled});

  final DemoController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return material.Tooltip(
      message: 'Seed the server scope directly',
      child: IconButton.ghost(
        icon: const material.Icon(material.Icons.add, size: 16),
        onPressed: enabled ? () => _open(context) : null,
      ),
    );
  }

  void _open(BuildContext context) {
    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            leading: const material.Icon(material.Icons.account_tree, size: 16),
            onPressed: (_) => unawaited(controller.seedServer('basicGraph')),
            child: const Text('Seed graph'),
          ),
          MenuButton(
            leading: const material.Icon(material.Icons.data_object, size: 16),
            onPressed: (_) => unawaited(controller.seedServer('typedRow')),
            child: const Text('Seed typed row'),
          ),
          MenuButton(
            leading: const material.Icon(material.Icons.hub, size: 16),
            onPressed: (_) => unawaited(controller.seedServer('fkChain')),
            child: const Text('Seed FK chain'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
    this.tooltip,
    this.compact = false,
  });

  final String text;
  final Color background;
  final Color foreground;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: material.Text(
        text,
        style: material.TextStyle(
          color: foreground,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
    final message = tooltip;
    return message == null
        ? badge
        : material.Tooltip(message: message, child: badge);
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

    return _Badge(
      text: label,
      background: bg,
      foreground: fg,
      tooltip: state.error ?? label,
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
    return _Badge(
      text: label,
      background: bg,
      foreground: fg,
      tooltip: state.error ?? label,
    );
  }
}

/// Centered loading indicator shown in a panel body while the local databases
/// are still opening (during [DemoController.initializing]).
class _PanelLoading extends StatelessWidget {
  const _PanelLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(),
          ),
          const Gap(10),
          Text(message).small().muted(),
        ],
      ),
    );
  }
}

// --- Tree ------------------------------------------------------------------

class _ProjectionTree extends StatefulWidget {
  const _ProjectionTree({
    super.key,
    required this.nodes,
    this.onTapRow,
    this.actions,
  });

  final List<TreeNode<DemoTreeItem>> nodes;
  final void Function(DemoRowRef ref)? onTapRow;
  final _RowActions? actions;

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
          actions: widget.actions,
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
    required this.actions,
  });

  final TreeItem<DemoTreeItem> node;
  final ValueChanged<bool> onExpand;
  final void Function(DemoRowRef ref)? onTapRow;
  final _RowActions? actions;

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
    final ref = item.ref;
    final selectable = ref != null && widget.onTapRow != null;
    final expandable = widget.node.children.isNotEmpty;
    final interactive = selectable || expandable;
    final showActions = widget.actions != null && ref != null && !item.metadata;

    return material.MouseRegion(
      cursor: interactive
          ? material.SystemMouseCursors.click
          : material.SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovered ? scheme.muted : material.Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: TreeItemView(
          focusNode: _focusNode,
          leading: material.Icon(
            item.icon,
            size: 14,
            color: item.hidden ? scheme.mutedForeground : null,
          ),
          onExpand: widget.onExpand,
          onPressed: interactive ? _handlePressed : null,
          trailing: showActions
              ? _RowActionBar(actions: widget.actions!, ref: ref)
              : null,
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
                    color: item.hidden
                        ? scheme.mutedForeground
                        : scheme.foreground,
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
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              if (item.relation != null) ...[
                const Gap(6),
                _FkBadge(relation: item.relation!),
              ],
              if (item.dangling) ...[const Gap(6), _DanglingBadge()],
            ],
          ),
        ),
      ),
    );
  }
}

class _FkBadge extends StatelessWidget {
  const _FkBadge({required this.relation});

  final Relationship relation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = _actionColors(scheme, relation.onDelete);
    return _Badge(
      text: '${relationLabel(relation.fkColumn)} · ${relation.onDelete.label}',
      background: bg,
      foreground: fg,
      compact: true,
      tooltip:
          '${relationLabel(relation.fkColumn)} → ${tableLabel(relation.parentTable)} '
          '· ${relation.onDelete.label} (${relation.onDelete.summary})',
    );
  }
}

class _DanglingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Badge(
      text: 'dangling',
      background: scheme.muted,
      foreground: scheme.mutedForeground,
      compact: true,
      tooltip: 'Foreign key points at a row not present here.',
    );
  }
}

(Color, Color) _actionColors(ColorScheme scheme, FkAction action) {
  return switch (action) {
    FkAction.restrict => (scheme.destructive, material.Colors.white),
    FkAction.cascade => (const Color(0xFFB45309), material.Colors.white),
    FkAction.setNull ||
    FkAction.setDefault => (scheme.primary, scheme.primaryForeground),
    FkAction.noAction => (scheme.muted, scheme.mutedForeground),
  };
}

class _RowActionBar extends StatelessWidget {
  const _RowActionBar({required this.actions, required this.ref});

  final _RowActions actions;
  final DemoRowRef ref;

  @override
  Widget build(BuildContext context) {
    final controller = actions.controller;
    final children = controller.catalog.childRelationshipsOf(ref.tableName);
    final parents = controller.catalog.parentRelationshipsOf(ref.tableName);
    final busy = controller.replicaBusy(actions.slot);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (children.isNotEmpty)
          _ActionIcon(
            icon: material.Icons.add,
            tooltip: 'Attach a child',
            onTap: busy ? null : () => _openAddChild(context, children),
          ),
        if (parents.isNotEmpty)
          _ActionIcon(
            icon: material.Icons.drive_file_move_outline,
            tooltip: 'Re-parent or detach',
            onTap: busy ? null : () => _openMove(context, parents),
          ),
      ],
    );
  }

  void _openAddChild(BuildContext context, List<Relationship> children) {
    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          for (final relation in children)
            MenuButton(
              leading: material.Icon(
                iconForTable(relation.childTable, hidden: false),
                size: 16,
              ),
              trailing: _MiniActionTag(action: relation.onDelete),
              onPressed: (_) => unawaited(
                actions.controller.createChildFor(actions.slot, ref, relation),
              ),
              child: Text(
                '${tableLabel(relation.childTable)} · '
                '${relationLabel(relation.fkColumn)}',
              ),
            ),
        ],
      ),
    );
  }

  void _openMove(BuildContext context, List<Relationship> parents) {
    if (parents.length == 1) {
      _openParentPicker(context, parents.single);
      return;
    }
    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          for (final relation in parents)
            MenuButton(
              trailing: _MiniActionTag(action: relation.onDelete),
              onPressed: (_) => _openParentPicker(context, relation),
              child: Text(
                '${relationLabel(relation.fkColumn)} → '
                '${tableLabel(relation.parentTable)}',
              ),
            ),
        ],
      ),
    );
  }

  void _openParentPicker(BuildContext context, Relationship relation) {
    final controller = actions.controller;
    final options = controller
        .parentOptions(actions.slot, relation.parentTable)
        .where((option) => option.ref.id.uuid != ref.id.uuid)
        .toList();

    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            leading: const material.Icon(material.Icons.link_off, size: 16),
            onPressed: (_) => unawaited(
              controller.reParent(actions.slot, ref, relation.fkColumn, null),
            ),
            child: const Text('Detach (null)'),
          ),
          for (final option in options)
            MenuButton(
              leading: material.Icon(
                iconForTable(relation.parentTable, hidden: !option.visible),
                size: 16,
              ),
              onPressed: (_) => unawaited(
                controller.reParent(
                  actions.slot,
                  ref,
                  relation.fkColumn,
                  option.ref.id,
                ),
              ),
              child: Text(option.label),
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final material.IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? scheme.mutedForeground.withAlpha(110)
        : scheme.mutedForeground;
    return material.Tooltip(
      message: tooltip,
      child: material.MouseRegion(
        cursor: onTap == null
            ? material.SystemMouseCursors.basic
            : material.SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: material.Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

class _MiniActionTag extends StatelessWidget {
  const _MiniActionTag({required this.action});

  final FkAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = _actionColors(scheme, action);
    return _Badge(
      text: action.label,
      background: bg,
      foreground: fg,
      compact: true,
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
