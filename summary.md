### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +60s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:39:45.377 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:39:45.377 localhost pacemaker-controld  [15656] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:39:47.619 localhost pacemaker-controld  [15656] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281187
Oct 29 13:39:47.621 localhost pacemaker-controld  [15656] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281187-6
Oct 29 13:39:49.917 localhost pacemaker-controld  [15656] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281187
Oct 29 13:39:49.917 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:49.917 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:49.918 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:50.040 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:55.323 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:55.324 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:56.040 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:00.737 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:00.737 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:02.039 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:06.151 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:06.151 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:06.151 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:08.040 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:11.560 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:11.560 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:14.039 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:16.616 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:16.983 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:16.983 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:20.041 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:22.393 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:22.393 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:26.039 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:27.823 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:27.824 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:32.040 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.291 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.291 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.370 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.370 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.371 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.371 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:36.436 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:36.438 localhost pacemaker-controld  [15656] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
```
