### Join stall after corosync kill (pacemaker-3.0.1-5.el10_2.1.x86_64)

- verdict: **REPRODUCED**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 1s; partition 8s after the restart; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +356s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 14:38:17.387 localhost pacemaker-controld  [1765] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 14:38:17.387 localhost pacemaker-controld  [1765] (join_make_offer) 	info: Making join-1 offers based on membership event 13
Oct 29 14:38:17.387 localhost pacemaker-controld  [1765] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 14:38:17.387 localhost pacemaker-controld  [1765] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 14:38:22.579 localhost pacemaker-controld  [1765] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 14:38:22.579 localhost pacemaker-controld  [1765] (join_make_offer) 	info: Making join-1 offers based on membership event 18
Oct 29 14:38:22.579 localhost pacemaker-controld  [1765] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 14:38:22.777 localhost pacemaker-controld  [1765] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793284702-
Oct 29 14:38:22.777 localhost pacemaker-controld  [1765] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 14:38:27.026 localhost pacemaker-controld  [1765] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 14:39:05.413 localhost pacemaker-controld  [1765] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 14:39:05.413 localhost pacemaker-controld  [1765] (join_make_offer) 	info: Making join-1 offers based on membership event 22
Oct 29 14:39:05.413 localhost pacemaker-controld  [1765] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 14:39:05.413 localhost pacemaker-controld  [1765] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 14:44:06.034 localhost pacemaker-controld  [1765] (join_make_offer) 	info: Sending join-2 offer to ctl-b
Oct 29 14:44:06.036 localhost pacemaker-controld  [1765] (do_dc_join_filter_offer) 	debug: Accepting join-2 request from ctl-b (with first CIB generation) | ref=join_request-crmd-1793285046-40
Oct 29 14:44:06.036 localhost pacemaker-controld  [1765] (do_dc_join_finalize) 	notice: Finalizing join-2 for 1 node (sync'ing CIB 0.15.14 with schema pacemaker-4.0 and feature set 3.20.1 from ctl-b)
Oct 29 14:44:06.036 localhost pacemaker-controld  [1765] (check_join_state) 	debug: join-2: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 14:44:06.042 localhost pacemaker-controld  [1765] (check_join_state) 	debug: join-2: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
