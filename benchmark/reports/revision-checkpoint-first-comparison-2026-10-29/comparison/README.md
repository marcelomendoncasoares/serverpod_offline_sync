# Capacity comparison

Positive percentages mean lower latency. Reductions are shown only for matching workloads, resources, configuration, and exact starting domain-table counts where both runs converged with complete observations. Missing or unequal starting counts suppress percentage comparisons. Equal counts do not establish identical physical database state or eliminate run-to-run variation. Failures retain their verdicts; incomplete timings do not establish a speedup.

| Case | Correct before / after | Kept up before / after | Starting counts match | Median reduction | Mean reduction | p95 reduction |
|---|---|---|---|---:|---:|---:|
| medium-full-person-r1-c8-a8-spread-t2 | True / True | True / True | True | -10.1% | -15.4% | -38.1% |
| medium-full-person-r1-c32-a32-spread-t2 | True / True | True / True | True | 16.7% | 16.9% | 15.0% |
| medium-full-person-r1-c64-a64-spread-t2 | True / True | False / False | True | 18.1% | 17.6% | 15.9% |
| medium-full-person-r200-c2-a2-spread-t2 | True / True | True / True | True | 9.0% | 5.0% | 0.1% |
| medium-full-person-r1000-c2-a2-spread-t2 | True / True | False / False | True | 39.4% | 38.5% | 41.6% |
| medium-full-town-linked-r200-c2-a2-spread-t2 | True / True | False / True | True | 56.6% | 53.1% | 67.6% |
| medium-city-city-r200-c2-a2-spread-t2 | True / True | True / True | True | 7.3% | 12.3% | 30.6% |
| medium-city-city-r1000-c2-a2-spread-t2 | True / True | False / False | True | 38.8% | 38.8% | 39.6% |
| small-full-person-r1-c8-a8-spread-t2 | True / True | True / True | False | — | — | — |
| small-full-person-r200-c2-a2-spread-t2 | True / True | False / False | False | — | — | — |
| small-full-town-linked-r200-c2-a2-spread-t2 | True / True | False / False | False | — | — | — |
| small-city-city-r200-c2-a2-spread-t2 | True / True | False / False | True | 17.9% | 17.9% | 7.9% |
| medium-full-town-linked-r1000-c2-a2-spread-t2 | None / True | None / False | None | — | — | — |
