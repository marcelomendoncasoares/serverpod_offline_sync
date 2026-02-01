# Benchmarks

This folder contains benchmarks to measure the performance impact of using the `drift_offline_sync` package on database operations.

## Accessing Benchmark Results

Benchmark results are automatically stored as git notes on commits when CI runs. To access historical benchmark data:

```bash
# View benchmark results for the latest commit
git log --show-notes=benchmarks -1

# View benchmark results for a specific commit
git log --show-notes=benchmarks <commit-sha> -1

# View all commits with their benchmark results
git log --show-notes=benchmarks

# Fetch benchmark notes from remote (if not already available)
git fetch origin refs/notes/benchmarks:refs/notes/benchmarks
```

The benchmark results include performance metrics for INSERT, UPDATE, and DELETE operations, as well as storage overhead comparisons between baseline and CRDT-enabled databases.

## What is Measured

The benchmarks measure two key metrics:

1. **Insert/Update/Delete Performance**: Time required to insert/update/delete
   a large number of rows with many columns.
2. **Storage Overhead**: Database file size after inserting a large number of
   rows with many columns.

The benchmarks are run in a separate isolate to avoid interference with the main
process. A baseline benchmark is run first to establish a reference point and
then a CRDT-enabled benchmark is run to measure the performance impact of using
the `drift_offline_sync` package.

## Running the Benchmarks

To run the benchmarks:

```bash
dart benchmark/run.dart
```

## Benchmark Details

### Table Structure

The benchmarks use `TableWithEveryColumnType` which includes:
- Boolean (`aBool`)
- DateTime (`aDateTime`)
- Text (`aText`)
- Integer (`anInt`)
- Int64 (`anInt64`)
- Real/Double (`aReal`)
- Blob (`aBlob`)
- Integer Enum (`anIntEnum`)
- Text with Converter (`aTextWithConverter`)
- UUID (`aUuid`)

This comprehensive table structure ensures the benchmarks reflect realistic use
cases with various data types.
