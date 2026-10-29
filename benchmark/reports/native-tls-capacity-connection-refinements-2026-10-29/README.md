# Connected-device refinements

All four follow-up cases below passed exact verification, complete observations, and clean teardown on the cached/HLC native-TLS baseline. Pipelining is disabled. The remaining sustained active-load checks and the revision-checkpoint comparison are still in progress.

Each case holds established streams idle for 45 seconds, then delivers one fresh row per user. Probe concurrency is bounded to eight users. Latencies below measure resumed delivery to the user's peers; they are not connection-establishment times or thousands of simultaneous writers.

## Completed follow-ups

| Size | Connected devices | Verified users / probes | Min ms | Median ms | Mean ms | p95 ms | Max ms | Peak charged MiB | Idle CPU, cores |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| large | 256 | 128 | 390.8 | 509.8 | 528.1 | 634.3 | 736.6 | 163.5 | 0.019 |
| large | 1024 | 512 | 422.9 | 692.9 | 698.8 | 919.0 | 1220.7 | 399.0 | 0.096 |
| xlarge | 2048 | 1024 | 350.4 | 501.7 | 531.0 | 742.4 | 1639.5 | 739.8 | 0.153 |
| xxlarge | 2048 | 1024 | 347.2 | 471.3 | 489.5 | 621.0 | 1568.3 | 740.5 | 0.140 |

Idle CPU is an approximation from process ticks sampled during the hold. Peak charged memory spans the whole case. These quantities have different measurement windows.

The [CPU accounting discrepancy](../native-tls-capacity-baseline-progress-2026-10-29/RESOURCE_ACCOUNTING.md) found in sustained Small runs also limits how confidently these process-counter estimates can be interpreted. They do not establish an effective CPU limit or available headroom.

## Largest fully verified idle trial by size

This combines the completed [discovery baseline](../native-tls-capacity-baseline-progress-2026-10-29/README.md) with these refinements. It reports tested operating points, not guaranteed ceilings. Build identities for the earlier Small/Medium observations remain in the baseline manifest.

| Size | Connected devices | Probe min ms | Median ms | Mean ms | p95 ms | Max ms | Peak charged MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| small | 256 | 2102.3 | 3318.2 | 3321.2 | 3909.5 | 4485.1 | 223.2 |
| medium | 256 | 684.9 | 1004.6 | 1012.0 | 1205.9 | 1225.0 | 190.0 |
| large | 1024 | 422.9 | 692.9 | 698.8 | 919.0 | 1220.7 | 399.0 |
| xlarge | 2048 | 350.4 | 501.7 | 531.0 | 742.4 | 1639.5 | 739.8 |
| xxlarge | 2048 | 347.2 | 471.3 | 489.5 | 621.0 | 1568.3 | 740.5 |

The earlier Large 256-device warmup failure is retained in the baseline. A later 256-device idle trial and the 1,024-device trial passed on the same executable, so that earlier failure does not establish a steady-state ceiling. XL and XXL each passed 2,048 here after their 4,096-device attempts failed during warmup. The cause of those startup failures has not been isolated.

Setup was bounded to four warmup workers for these follow-ups. Neither the idle hold nor the probes validate a simultaneous reconnect burst. Use the separate [active-device tables](../native-tls-capacity-baseline-progress-2026-10-29/SIZING.md) when sizing continuous write traffic; do not combine the largest idle and active counts into an unmeasured workload.

The adjacent JSON files retain all four completed assessments, their frozen replay parameters, build identities, and raw round records. Source cases for the combined table:

- `small-full-idle-c256`
- `medium-full-idle-c256-w4-t2`
- `large-full-idle-c1024-w4-followup-t2`
- `xlarge-full-idle-c2048-w4-followup-t2`
- `xxlarge-full-idle-c2048-w4-followup-t2`
