### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +59s, svc started on ctl-b at +59s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:39:22.635 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:39:22.635 localhost pacemaker-controld  [15738] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:39:24.887 localhost pacemaker-controld  [15738] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281164
Oct 29 13:39:24.888 localhost pacemaker-controld  [15738] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281164-6
Oct 29 13:39:27.173 localhost pacemaker-controld  [15738] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281164
Oct 29 13:39:27.173 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:27.173 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:27.174 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:27.276 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:32.584 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:32.584 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:33.276 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:38.001 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:38.001 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:39.276 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:43.406 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:43.407 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:45.276 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:48.819 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:48.820 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:51.277 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:53.886 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:54.222 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:54.222 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:57.277 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:59.632 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:59.632 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:03.277 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:05.064 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:05.064 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:09.278 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.526 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.527 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.616 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.619 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.621 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.621 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:13.703 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:13.705 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:13.705 localhost pacemaker-controld  [15738] (do_dc_join_finalize) 	debug: Finalizing join-1 for 1 node (sync'ing from local CIB)
```
