### Join stall after corosync kill (pacemaker-3.0.1-5.lab1.el10.1.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 1s; partition 8s after the restart; 5 config changes before the kill
- fence done at +61s, svc started on ctl-b at +61s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 16:46:33.569 localhost pacemaker-controld  [9850] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 16:46:33.570 localhost pacemaker-controld  [9850] (join_make_offer) 	info: Making join-1 offers based on membership event 13
Oct 29 16:46:33.571 localhost pacemaker-controld  [9850] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 16:46:33.571 localhost pacemaker-controld  [9850] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 16:46:38.225 localhost pacemaker-controld  [9850] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 16:46:38.225 localhost pacemaker-controld  [9850] (join_make_offer) 	info: Making join-1 offers based on membership event 18
Oct 29 16:46:38.225 localhost pacemaker-controld  [9850] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 16:46:38.225 localhost pacemaker-controld  [9850] (join_make_offer) 	info: Sending join-1 offer to ctl-b
Oct 29 16:46:38.327 localhost pacemaker-controld  [9850] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793292398-
Oct 29 16:46:43.630 localhost pacemaker-controld  [9850] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793292398-5
Oct 29 16:46:43.630 localhost pacemaker-controld  [9850] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 16:46:43.630 localhost pacemaker-controld  [9850] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 16:47:21.696 localhost pacemaker-controld  [9850] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 16:47:21.696 localhost pacemaker-controld  [9850] (join_make_offer) 	info: Making join-1 offers based on membership event 22
Oct 29 16:47:24.664 localhost pacemaker-controld  [9850] (do_dc_join_finalize) 	notice: Finalizing join-1 for 1 node (sync'ing CIB 0.15.6 with schema pacemaker-4.0 and feature set 3.20.1 from ctl-b)
Oct 29 16:47:24.665 localhost pacemaker-controld  [9850] (check_join_state) 	debug: join-1: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 16:47:24.679 localhost pacemaker-controld  [9850] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
