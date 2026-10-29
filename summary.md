### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +61s, svc started on ctl-b at +61s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:40:13.078 localhost pacemaker-controld  [15700] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281213
Oct 29 13:40:13.079 localhost pacemaker-controld  [15700] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281213-6
Oct 29 13:40:14.089 localhost pacemaker-controld  [15700] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281213
Oct 29 13:40:14.089 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:14.089 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.674 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.675 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:20.089 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:21.207 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:21.208 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:26.088 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:26.730 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:26.730 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:32.088 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:32.258 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:32.259 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:37.794 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:37.795 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:38.089 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:42.077 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:43.341 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:43.341 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.088 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:48.855 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:48.855 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:50.089 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:54.398 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:54.399 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:54.399 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:56.089 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:58.257 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:58.263 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:58.267 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:58.267 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.987 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:59.987 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:01.677 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:01.681 localhost pacemaker-controld  [15700] (do_dc_join_finalize) 	debug: Finalizing join-1 for 1 node (sync'ing from local CIB)
Oct 29 13:41:01.683 localhost pacemaker-controld  [15700] (check_join_state) 	debug: join-1: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 13:41:01.698 localhost pacemaker-controld  [15700] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
