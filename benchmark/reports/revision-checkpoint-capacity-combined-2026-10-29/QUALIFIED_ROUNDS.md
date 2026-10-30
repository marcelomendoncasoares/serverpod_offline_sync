# Qualified five-minute rounds

These are the selected one-row operating points from the completed qualification. Every selected run kept up, passed exact convergence and complete observation checks, and drained cleanly. Timings are milliseconds from local write through application on every peer. Each user has two participating devices and offers one round every two seconds for 150 rounds. The Small Person row reuses its matching discovery trial; the other fourteen rows come from qualification.

| Tier | Profile | Participating devices | Rounds | Min | Median | Mean | p95 | Max |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Small | Person | 8 | 600 | 688.5 | 1104.9 | 1198.8 | 1990.2 | 2316.7 |
| Small | Linked Town | 4 | 300 | 635.6 | 760.5 | 800.6 | 959.5 | 2345.3 |
| Small | Isolated City | 8 | 600 | 396.6 | 589.2 | 623.5 | 883.2 | 1904.3 |
| Medium | Person | 4 | 300 | 347.6 | 375.9 | 383.5 | 442.7 | 602.3 |
| Medium | Linked Town | 32 | 2400 | 530.6 | 1267.2 | 1295.0 | 1736.3 | 2191.6 |
| Medium | Isolated City | 32 | 2400 | 306.9 | 508.4 | 521.2 | 651.5 | 1238.1 |
| Large | Person | 64 | 4800 | 348.6 | 508.6 | 523.2 | 682.4 | 1221.0 |
| Large | Linked Town | 16 | 1200 | 339.2 | 369.2 | 377.0 | 412.5 | 981.6 |
| Large | Isolated City | 64 | 4800 | 310.7 | 389.4 | 400.8 | 497.3 | 979.5 |
| XL | Person | 64 | 4800 | 326.2 | 370.3 | 379.0 | 449.5 | 922.3 |
| XL | Linked Town | 64 | 4800 | 326.7 | 367.1 | 379.6 | 463.7 | 963.5 |
| XL | Isolated City | 128 | 9600 | 292.9 | 334.3 | 344.9 | 419.6 | 818.8 |
| XXL | Person | 64 | 4800 | 326.3 | 385.7 | 393.1 | 465.6 | 781.0 |
| XXL | Linked Town | 128 | 9600 | 340.6 | 411.4 | 431.4 | 535.4 | 1685.0 |
| XXL | Isolated City | 128 | 9600 | 282.5 | 328.7 | 339.4 | 422.1 | 932.7 |

## Actual overlap and source trials

Participating population is not simultaneous work. Overlap counts devices belonging to unfinished application rounds, including peer delivery; it does not count concurrent PostgreSQL transactions. The spread schedule intentionally staggers users. Round rate is the offered rate, not a guarantee about arbitrary bursts.

| Tier / profile | Offered rounds/s | Mean / peak devices in unfinished rounds | Source trial |
|---|---:|---:|---|
| Small / Person | 2.0 | 4.8 / 8 | `small-full-person-r1-c8-a8-soak` |
| Small / Linked Town | 1.0 | 1.6 / 4 | `small-full-town-linked-r1-c4-a4-qualification-t2` |
| Small / Isolated City | 2.0 | 2.5 / 8 | `small-city-city-r1-c8-a8-qualification-t2` |
| Medium / Person | 1.0 | 0.8 / 2 | `medium-full-person-r1-c4-a4-qualification-t2` |
| Medium / Linked Town | 8.0 | 20.7 / 32 | `medium-full-town-linked-r1-c32-a32-qualification-t2` |
| Medium / Isolated City | 8.0 | 8.3 / 20 | `medium-city-city-r1-c32-a32-qualification-t2` |
| Large / Person | 16.0 | 16.7 / 36 | `large-full-person-r1-c64-a64-qualification-t2` |
| Large / Linked Town | 4.0 | 3.0 / 8 | `large-full-town-linked-r1-c16-a16-qualification-t2` |
| Large / Isolated City | 16.0 | 12.8 / 32 | `large-city-city-r1-c64-a64-qualification-t2` |
| XL / Person | 16.0 | 12.1 / 30 | `xlarge-full-person-r1-c64-a64-qualification-t2` |
| XL / Linked Town | 16.0 | 12.1 / 32 | `xlarge-full-town-linked-r1-c64-a64-qualification-t2` |
| XL / Isolated City | 32.0 | 22.1 / 52 | `xlarge-city-city-r1-c128-a128-qualification-t2` |
| XXL / Person | 16.0 | 12.6 / 26 | `xxlarge-full-person-r1-c64-a64-qualification-t2` |
| XXL / Linked Town | 32.0 | 27.6 / 92 | `xxlarge-full-town-linked-r1-c128-a128-qualification-t2` |
| XXL / Isolated City | 32.0 | 21.7 / 58 | `xxlarge-city-city-r1-c128-a128-qualification-t2` |

All unsuccessful larger trials remain in [the complete measurements](README.md). The [sizing guide](CAPACITY_GUIDE.md) explains why several selections are limited by setup or lifecycle failures rather than demonstrated processing ceilings.
