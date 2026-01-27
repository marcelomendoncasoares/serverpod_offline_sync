# Benchmarks

This folder contains benchmarks to measure the performance impact of using the `drift_offline_sync` package on database operations.

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
