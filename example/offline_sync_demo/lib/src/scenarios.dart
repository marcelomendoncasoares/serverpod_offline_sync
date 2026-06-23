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
      Scenario(
        title: 'Concurrent field edits',
        summary:
            'A and B edit different Person columns offline; both values survive merge.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          return [
            ScenarioStep(
              'Seed Person on A',
              replica: ReplicaSlot.a,
              () async => ctx['person'] = await c.createRoot(
                ReplicaSlot.a,
                'person',
                label: 'Conflict person',
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
            ScenarioStep('Edit name on A', replica: ReplicaSlot.a, () async {
              final person = ctx['person'];
              if (person != null) {
                await c.updateRowFields(person, ReplicaSlot.a, {
                  'name': 'Name from A',
                });
              }
            }),
            ScenarioStep('Edit surname on B', replica: ReplicaSlot.b, () async {
              final person = ctx['person'];
              if (person != null) {
                await c.updateRowFields(person, ReplicaSlot.b, {
                  'surname': 'Surname from B',
                });
              }
            }),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B → server',
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
        title: 'Unique update conflict',
        summary:
            'Two Unique rows are renamed to the same value; the older claim keeps it.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          final shared = 'shared-${c._counter.next('unique-update')}';
          return [
            ScenarioStep(
              'Insert Unique "first" on A',
              replica: ReplicaSlot.a,
              () async => ctx['first'] = await c.createUnique(
                ReplicaSlot.a,
                'first-$shared',
              ),
            ),
            ScenarioStep(
              'Insert Unique "second" on A',
              replica: ReplicaSlot.a,
              () async => ctx['second'] = await c.createUnique(
                ReplicaSlot.a,
                'second-$shared',
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
              'Rename "first" to "$shared" on A',
              replica: ReplicaSlot.a,
              () async {
                final first = ctx['first'];
                if (first != null) {
                  await c.updateRowFields(first, ReplicaSlot.a, {
                    'name': shared,
                  });
                }
              },
            ),
            ScenarioStep(
              'Rename "second" to "$shared" on B',
              replica: ReplicaSlot.b,
              () async {
                final second = ctx['second'];
                if (second != null) {
                  await c.updateRowFields(second, ReplicaSlot.b, {
                    'name': shared,
                  });
                }
              },
            ),
            ScenarioStep(
              'Sync B → server (newer update first)',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Sync A → server (older update loses)',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server (converge)',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
          ];
        },
      ),
      Scenario(
        title: 'Delete and restore',
        summary:
            'A deletes a Person; B reinserts it with a newer restore that wins on merge.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          return [
            ScenarioStep(
              'Seed Person on A',
              replica: ReplicaSlot.a,
              () async => ctx['person'] = await c.createRoot(
                ReplicaSlot.a,
                'person',
                label: 'Restorable person',
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
              'Delete Person on A',
              replica: ReplicaSlot.a,
              () async {
                final person = ctx['person'];
                if (person != null) await c.deleteRow(person, ReplicaSlot.a);
              },
            ),
            ScenarioStep(
              'Sync A → server',
              () => c.syncReplica(ReplicaSlot.a),
              replica: ReplicaSlot.a,
            ),
            ScenarioStep(
              'Sync B ← server (tombstone arrives)',
              () => c.syncReplica(ReplicaSlot.b),
              replica: ReplicaSlot.b,
            ),
            ScenarioStep(
              'Reinsert Person on B',
              replica: ReplicaSlot.b,
              () async {
                final person = ctx['person'];
                if (person != null) await c.reinsertRow(person, ReplicaSlot.b);
              },
            ),
            ScenarioStep(
              'Sync B → server',
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
        title: 'SetDefault projection',
        summary:
            'Deleting a Town on A resets a Company on B to the schema default town.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          const defaultTownId = protocol.UuidValue.raw(
            '550e8400-e29b-41d4-a716-446655440000',
          );
          final townRelation = childRelation('town', 'company');
          return [
            ScenarioStep(
              'Seed default Town on A',
              replica: ReplicaSlot.a,
              () async => ctx['defaultTown'] = await c.createTown(
                ReplicaSlot.a,
                id: defaultTownId,
                label: 'Default town',
              ),
            ),
            ScenarioStep(
              'Seed linked Town on A',
              replica: ReplicaSlot.a,
              () async => ctx['linkedTown'] = await c.createTown(
                ReplicaSlot.a,
                label: 'Linked town',
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
              'Attach Company to linked Town on B',
              replica: ReplicaSlot.b,
              () async {
                final town = ctx['linkedTown'];
                if (town != null && townRelation != null) {
                  ctx['company'] = await c.createChildFor(
                    ReplicaSlot.b,
                    town,
                    townRelation,
                  );
                } else if (town != null) {
                  ctx['company'] = await c.createCompanyForTown(
                    ReplicaSlot.b,
                    town,
                  );
                }
              },
            ),
            ScenarioStep(
              'Delete linked Town on A',
              replica: ReplicaSlot.a,
              () async {
                final town = ctx['linkedTown'];
                if (town != null) await c.deleteRow(town, ReplicaSlot.a);
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
        title: 'FK chain cascade',
        summary:
            'Deleting the chain root on A cascade-hides grandchildren built on B.',
        build: (c) {
          final ctx = <String, DemoRowRef?>{};
          final middleRelation = childRelation(
            'fk_chain_root',
            'fk_chain_cascade_middle',
          );
          final blockerRelation = childRelation(
            'fk_chain_cascade_middle',
            'fk_chain_restrict_blocker',
          );
          final cascadeChildRelation = childRelation(
            'fk_chain_restrict_blocker',
            'fk_chain_middle_cascade_child',
          );
          return [
            ScenarioStep(
              'Seed FK chain root on A',
              replica: ReplicaSlot.a,
              () async => ctx['root'] = await c.createRoot(
                ReplicaSlot.a,
                'fk_chain_root',
                label: 'Chain root',
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
              'Attach cascade middle on B',
              replica: ReplicaSlot.b,
              () async {
                final root = ctx['root'];
                if (root != null && middleRelation != null) {
                  ctx['middle'] = await c.createChildFor(
                    ReplicaSlot.b,
                    root,
                    middleRelation,
                  );
                }
              },
            ),
            ScenarioStep(
              'Attach restrict blocker on B',
              replica: ReplicaSlot.b,
              () async {
                final middle = ctx['middle'];
                if (middle != null && blockerRelation != null) {
                  ctx['blocker'] = await c.createChildFor(
                    ReplicaSlot.b,
                    middle,
                    blockerRelation,
                  );
                }
              },
            ),
            ScenarioStep(
              'Attach cascade grandchild on B',
              replica: ReplicaSlot.b,
              () async {
                final blocker = ctx['blocker'];
                if (blocker != null && cascadeChildRelation != null) {
                  await c.createChildFor(
                    ReplicaSlot.b,
                    blocker,
                    cascadeChildRelation,
                  );
                }
              },
            ),
            ScenarioStep(
              'Delete chain root on A',
              replica: ReplicaSlot.a,
              () async {
                final root = ctx['root'];
                if (root != null) await c.deleteRow(root, ReplicaSlot.a);
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
    ];
  }
}
