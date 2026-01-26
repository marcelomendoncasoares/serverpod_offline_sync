# Benchmarks

This folder contains benchmarks to measure the performance impact of using the `drift_offline_first` package on database operations.

## What is Measured

The benchmarks measure two key metrics:

1. **Insert Performance**: Time required to insert 10,000 rows with all column types
2. **Storage Overhead**: Database file size after inserting 10,000 rows

Each benchmark compares:
- **Baseline**: Standard Drift database without CRDT synchronization
- **CRDT-enabled**: Database with offline-first CRDT features enabled

## Running the Benchmarks

To run the benchmarks:

```bash
dart benchmarks/run.dart
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

This comprehensive table structure ensures the benchmarks reflect realistic use cases with various data types.

### Database Configuration

- **Baseline Database**: File-based SQLite3 database without CRDT features
- **CRDT Database**: File-based SQLite3 database with:
  - HLC (Hybrid Logical Clock) timestamps via UDF
  - Triggers for tracking changes
  - Vertical table for storing change history

## Expected Results

The CRDT-enabled database incurs:
- **Performance overhead** due to:
  - UDF calls for HLC timestamp generation
  - Trigger execution on each insert/update/delete
  - Additional writes to the CRDT data table

- **Storage overhead** due to:
  - Vertical table storing all column changes
  - HLC timestamps for each column value
  - Additional metadata for conflict resolution

## Implementation

The benchmarks are implemented using simple async functions rather than the `benchmark_harness` package, as they need to:
1. Perform async database operations
2. Measure both time and storage
3. Use file-based databases (not in-memory)
4. Clean up database files after each run

Files:
- `baseline_database.dart`: Standard Drift database definition
- `crdt_database.dart`: CRDT-enabled database definition
- `insert_benchmark.dart`: Benchmark implementations
- `run.dart`: Main benchmark runner with reporting
