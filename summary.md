### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +61s, svc started on ctl-b at +61s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:40:13.251 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:40:13.251 localhost pacemaker-controld  [15701] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:40:15.806 localhost pacemaker-controld  [15701] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281215
Oct 29 13:40:15.807 localhost pacemaker-controld  [15701] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281215-6
Oct 29 13:40:17.007 localhost pacemaker-controld  [15701] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281215
Oct 29 13:40:17.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:17.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:18.256 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:18.257 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:23.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:23.770 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:23.771 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:29.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:29.284 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:29.284 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:29.284 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:34.810 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:34.811 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:35.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:40.322 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:40.322 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:40.323 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.805 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:45.831 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:45.832 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:47.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:51.351 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:51.352 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:53.007 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:56.888 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:56.889 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.008 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.862 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.862 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.863 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.865 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:02.464 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:02.464 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:03.345 localhost pacemaker-controld  [15701] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
```
