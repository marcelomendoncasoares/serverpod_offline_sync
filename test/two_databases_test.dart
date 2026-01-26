@Skip('Skipping two databases test until migrations are implemented.')
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'utils/databases.dart';

void main() {
  test('Two databases with different schema versions 1-2', () async {
    final executor = NativeDatabase.memory();
    final first = FirstDb(executor);
    final second = SecondDb(executor);

    // Trigger the migration.
    await first.managers.todosTable.create(
      (t) => t.call(content: 'test'),
    );

    expect(first.created, isTrue);
    expect(first.didUpgrade, isFalse);
    expect(first.onBeforeOpen, isTrue);

    // Trigger the migration.
    await second.managers.users.create(
      (t) => t.call(name: 'John Doe', profilePicture: Uint8List(10)),
    );

    expect(second.created, isTrue);
    expect(second.onBeforeOpen, isTrue);
    expect(second.didUpgrade, isTrue);
  });

  test('Two databases with different schema versions 2-1', () async {
    final executor = NativeDatabase.memory();
    final second = SecondDb(executor);
    final first = FirstDb(executor);

    // Trigger the migration.
    final _ = second.users.all();
    expect(second.didUpgrade, isFalse);

    final _ = first.todosTable.all();
    expect(first.didUpgrade, isTrue);
  });
}
