# Opening-rate transition

This initial sweep completed all Small and Medium cases, then passed the Large
64, 256 and 1,024-connection screens with eight simultaneous opens. All 17
completed trials are retained, including the earlier capacity failures.

The runner was deliberately interrupted only after the Large 1,024 trial's
client exited and the server was verified clean. No active trial was cut short
by this transition. The original executable, original database configuration,
one Small instance and all 11 protected configuration files were restored and
verified before continuation.

Opening a connection from this client location takes several network round
trips. At eight concurrent opens, testing the larger tiers would spend several
hours mostly establishing and re-establishing sockets. The continued campaign
therefore uses 32 simultaneous opens on Large and 64 on XL/XXL, with the same
server executable and stream protocol. Eight client worker processes, eight
simultaneous resume probes, 64 simultaneous closes, idle durations and exact
per-stream correctness checks remain unchanged.

Small and Medium results come from this directory. The larger-tier results are
recorded in the separate continued-campaign directory, with its new client
build identity. The three successful Large controls here provide observations
at the original slower opening rate; they are not substituted for five-minute
qualifications. The manifest's initial five-tier plan does not mean all five
tiers were completed in this first campaign.
