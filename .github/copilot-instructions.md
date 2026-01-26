# Drift Offline First Project Guidelines

- Before starting any task, CONSIDER ALL GUIDELINES from this document.
- If a guideline that is directly related to the task contains a reference,
  fetch the reference to improve the understanding of the task.

## Project Context

- This package is a non-invasive plugin implementation of offline-first
  features for Drift that uses CRDT (conflict-free replicated data types) for
  conflict resolution.
- The package is in early stages and more documentation will be added as it
  evolves. Currently, rely on the code and comments to understand how it works.
  Although extensive docs are not present, the code is well-documented and the
  tests are comprehensive.

## General Guidelines

- Always conform to the coding style of the existing code.
- Remove unnecessary comments from production code.
- Ensure linting passes before considering the task finished.

## Pubspec Dependency Management

- Do not add any new dependencies, unless explicitly asked.
- If a new dependency is needed, ask for permission first.

## Testing Guidelines

- Use the existing test framework and follow the existing patterns or similar
  tests/examples.
- The [utils](../test/utils) folder contains utility functions and classes that
  are used to simplify test setup and teardown.
- Always follow the AAA pattern (Arrange-Act-Assert) on tests.
- Avoid comments like '// Arrange', '// Act', '// Assert'.
- Avoid mocks on tests. Try to use as much real code as possible.
- Check other tests to see how test data is being created.
- Tests should validate expected behavior and results, never implementation
  details.
- Focus tests specially in dynamic behaviors and edge cases.
- Separate into groups to make them more readable.
- Avoid overlapping tests. Tests should validate different aspects of the code.
- If tests are broken, only finish when they are all passing or you need
  guidance.
- NEVER fix a test by reducing its scope.
- NEVER remove tests without a good reason.

### Test Description Pattern

Use the "Given, when, then" pattern for test descriptions to maintain
consistency:

```dart
test(
  'Given [initial state] when [action performed] then [expected outcome].',
  () {
    // Test implementation
  }
);
```

**CRITICAL**: When using `group()` with `test()`, ensure each statement
("Given", "when", "then") appears **only once** in the combined description:

```dart
// CORRECT: "Given" in group, "when/then" in test
group(
  'Given a session with slow method call when logging is enabled',
  () {
    test(
      'when session is logged then time field should be set to start time.',
      () {
        // Test implementation
      }
    );
  }
);

// INCORRECT: "Given" repeated in both group and test
group(
  'Given a session with slow method call',
  () {
    test(
      'Given a slow method when session is logged then time field is correct.',  // ❌ Duplicate "Given"
      () {
        // Test implementation
      }
    );
  }
);
```

### Test Organization

- Place passing/success test cases at the top of test files
- Group related test cases using `group()` where appropriate
- Follow success test cases with error test cases for the same functionality

## Pull Request Guidelines

Before submitting a PR, ensure:

1. **Title follows conventional commits format**: See section below.
2. **Code is formatted**: `dart format .`
3. **Linting passes**: `dart analyze .`
4. **Tests pass**: Always run all tests with `dart test`, since they are fast.
5. **No excessive documentation**: Only add documentation if explicitly asked.

### PR Title Format

```
<type>: <description>
```

**Valid types** (enforced by GitHub Actions):

- **`feat`**: New features
- **`fix`**: Bug fixes
- **`docs`**: Documentation changes
- **`style`**: Code style changes (formatting, missing semi-colons, etc)
- **`refactor`**: Code refactoring without changing functionality
- **`perf`**: Performance improvements
- **`test`**: Adding or updating tests
- **`build`**: Changes to build system or dependencies
- **`ci`**: Changes to CI configuration files and scripts
- **`chore`**: Maintenance tasks, tooling changes
- **`revert`**: Reverting previous commits

**Requirements**:

- Description must start with an uppercase letter
- Be descriptive and concise
- Use imperative mood ("Add feature" not "Added feature")

**Examples**:

```
feat: Add authentication module for OAuth2 integration
fix: Resolve database connection timeout issue
docs: Update installation guide with Docker requirements
refactor: Simplify error handling in client package
test: Add integration tests for chat module
chore: Update dependencies to latest versions
```
