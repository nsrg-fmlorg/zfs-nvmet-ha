### Join stall after corosync kill (pacemaker-2.1.10-3.el9_8.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +65s, svc started on ctl-b at +65s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:11:46.906 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:11:46.906 localhost pacemaker-controld  [15503] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:11:49.050 localhost pacemaker-controld  [15503] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793279509
Oct 29 13:11:49.051 localhost pacemaker-controld  [15503] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793279509-6
Oct 29 13:11:50.621 localhost pacemaker-controld  [15503] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793279509
Oct 29 13:11:50.621 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:50.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:51.552 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:51.552 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:51.552 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:56.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:56.988 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:56.989 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:02.435 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:02.436 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:02.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:07.880 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:07.880 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:08.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:13.321 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:13.321 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:14.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:18.047 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:18.762 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:18.762 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:20.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:24.187 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:24.188 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:26.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:29.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:29.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:29.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:32.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:35.079 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:35.079 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:35.080 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:38.622 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:40.398 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:40.398 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:40.398 localhost pacemaker-controld  [15503] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
```
