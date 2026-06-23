part of 'demo_controller.dart';

/// One step of a guided scenario, bound to a concrete replica and rows.
class ScenarioStep {
  ScenarioStep(this.label, this.run, {this.replica});

  final String label;
  final ReplicaSlot? replica;
  final Future<void> Function() run;
}

/// A guided, stateful recipe that scripts the free-form primitives. Optional —
/// every step it runs can also be done by hand directly on the tree.
class Scenario {
  Scenario({required this.title, required this.summary, required this.build});

  final String title;
  final String summary;
  final List<ScenarioStep> Function(DemoController controller) build;
}

extension on DemoController {
  List<Scenario> _buildScenarios() {
    Relationship? childRelation(String parent, String child) {
      for (final relation in catalog.childRelationshipsOf(parent)) {
        if (relation.childTable == child) return relation;
      }
      return null;
    }

    return [
      Scenario(
        title: 'Restrict blocks delete',
        summary:
            'A Restrict child added on B blocks the parent delete made on A.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          final relation = childRelation('person', 'restrict_child');
          return [
            ScenarioStep(
              'Seed parent Person on A',
              replica: ReplicaSlot.a,
              () async => ctx['parent'] = await c.createRoot(
                ReplicaSlot.a,
                'person',
                label: 'Restricted parent',
              ),
            ),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Attach Restrict child on B',
              replica: ReplicaSlot.b,
              () async {
                final parent = ctx['parent'];
                if (parent != null && relation != null) {
                  await c.createChildFor(ReplicaSlot.b, parent, relation);
                }
              },
            ),
            ScenarioStep(
              'Delete parent on A',
              replica: ReplicaSlot.a,
              () async {
                final parent = ctx['parent'];
                if (parent != null) await c.deleteRow(parent, ReplicaSlot.a);
              },
            ),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Sync A ← server (converge)',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
          ];
        },
      ),
      Scenario(
        title: 'SetNull projection',
        summary:
            'A Town mayor reference on B is nulled when the mayor is deleted on A.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          final relation = childRelation('person', 'town');
          return [
            ScenarioStep(
              'Seed mayor Person on A',
              replica: ReplicaSlot.a,
              () async => ctx['mayor'] = await c.createRoot(
                ReplicaSlot.a,
                'person',
                label: 'Mayor candidate',
              ),
            ),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Add Town with that mayor on B',
              replica: ReplicaSlot.b,
              () async {
                final mayor = ctx['mayor'];
                if (mayor != null && relation != null) {
                  await c.createChildFor(ReplicaSlot.b, mayor, relation);
                }
              },
            ),
            ScenarioStep('Delete mayor on A', replica: ReplicaSlot.a, () async {
              final mayor = ctx['mayor'];
              if (mayor != null) await c.deleteRow(mayor, ReplicaSlot.a);
            }),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Sync A ← server (converge)',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
          ];
        },
      ),
      Scenario(
        title: 'Cascade hides children',
        summary:
            'Deleting an Organization on A cascade-hides the Person attached on B.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          final relation = childRelation('organization', 'person');
          return [
            ScenarioStep(
              'Seed Organization on A',
              replica: ReplicaSlot.a,
              () async => ctx['org'] = await c.createRoot(
                ReplicaSlot.a,
                'organization',
                label: 'Cascade org',
              ),
            ),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Attach Person to org on B',
              replica: ReplicaSlot.b,
              () async {
                final org = ctx['org'];
                if (org != null && relation != null) {
                  await c.createChildFor(ReplicaSlot.b, org, relation);
                }
              },
            ),
            ScenarioStep('Delete org on A', replica: ReplicaSlot.a, () async {
              final org = ctx['org'];
              if (org != null) await c.deleteRow(org, ReplicaSlot.a);
            }),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Sync A ← server (converge)',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
          ];
        },
      ),
      Scenario(
        title: 'Concurrent unique insert',
        summary:
            'Both replicas insert a Unique row with the same name; one loses on merge.',
        build: (c) {
          final name = 'shared-${c._counter.next('unique')}';
          return [
            ScenarioStep(
              'Insert Unique "$name" on A',
              replica: ReplicaSlot.a,
              () => c.createUnique(ReplicaSlot.a, name),
            ),
            ScenarioStep(
              'Insert Unique "$name" on B',
              replica: ReplicaSlot.b,
              () => c.createUnique(ReplicaSlot.b, name),
            ),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B → server (conflict resolves)',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Sync A ← server (converge)',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
          ];
        },
      ),
    ];
  }
}
