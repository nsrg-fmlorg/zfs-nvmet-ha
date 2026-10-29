### Join stall after corosync kill (pacemaker-2.1.10-3.el9_8.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +60s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:11:59.914 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:11:59.914 localhost pacemaker-controld  [15260] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:12:02.088 localhost pacemaker-controld  [15260] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793279522
Oct 29 13:12:02.089 localhost pacemaker-controld  [15260] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793279522-6
Oct 29 13:12:04.192 localhost pacemaker-controld  [15260] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793279522
Oct 29 13:12:04.193 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:04.193 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:04.625 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:04.626 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:10.094 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:10.094 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:10.192 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:15.547 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:15.548 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:16.191 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:21.007 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:21.008 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:22.192 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:26.463 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:26.464 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:28.192 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:31.084 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:31.914 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:31.914 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:34.191 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:37.365 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:37.365 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:37.366 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:40.192 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:42.848 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:42.848 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:42.849 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:46.192 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.843 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.843 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.844 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.844 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:48.379 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:48.379 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:48.379 localhost pacemaker-controld  [15260] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
```
