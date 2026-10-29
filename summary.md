### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +60s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:11:38.366 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:11:38.366 localhost pacemaker-controld  [15929] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:11:40.701 localhost pacemaker-controld  [15929] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793279500
Oct 29 13:11:40.703 localhost pacemaker-controld  [15929] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793279500-6
Oct 29 13:11:42.332 localhost pacemaker-controld  [15929] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793279500
Oct 29 13:11:42.332 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:42.332 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:42.928 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:42.928 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:48.332 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:48.341 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:48.342 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:53.759 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:53.759 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:54.331 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:59.162 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:11:59.162 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:00.331 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:04.579 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:04.580 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:06.331 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:09.707 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:09.993 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:09.993 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:12.332 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:15.403 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:15.403 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:18.335 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:20.830 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:20.830 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:24.332 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:25.309 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:25.310 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:25.310 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:25.311 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:26.333 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:26.334 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:28.438 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:28.440 localhost pacemaker-controld  [15929] (do_dc_join_finalize) 	debug: Finalizing join-1 for 1 node (sync'ing from local CIB)
Oct 29 13:12:28.441 localhost pacemaker-controld  [15929] (check_join_state) 	debug: join-1: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
```
