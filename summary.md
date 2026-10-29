### Join stall after corosync kill (pacemaker-2.1.10-3.lab1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 1s; partition 8s after the restart; 5 config changes before the kill
- fence done at +61s, svc started on ctl-b at +61s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 14:39:36.358 localhost pacemaker-controld  [16724] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 14:39:36.358 localhost pacemaker-controld  [16724] (join_make_offer) 	info: Making join-1 offers based on membership event 13
Oct 29 14:39:36.358 localhost pacemaker-controld  [16724] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 14:39:36.358 localhost pacemaker-controld  [16724] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 14:39:41.644 localhost pacemaker-controld  [16724] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 14:39:41.644 localhost pacemaker-controld  [16724] (join_make_offer) 	info: Making join-1 offers based on membership event 18
Oct 29 14:39:41.644 localhost pacemaker-controld  [16724] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 14:39:41.644 localhost pacemaker-controld  [16724] (join_make_offer) 	info: Sending join-1 offer to ctl-b
Oct 29 14:39:41.848 localhost pacemaker-controld  [16724] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793284781
Oct 29 14:39:46.328 localhost pacemaker-controld  [16724] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793284781-5
Oct 29 14:39:46.328 localhost pacemaker-controld  [16724] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 14:39:46.328 localhost pacemaker-controld  [16724] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 14:40:22.870 localhost pacemaker-controld  [16724] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 14:40:22.871 localhost pacemaker-controld  [16724] (join_make_offer) 	info: Making join-1 offers based on membership event 22
Oct 29 14:40:26.450 localhost pacemaker-controld  [16724] (do_dc_join_finalize) 	debug: Finalizing join-1 for 1 node (sync'ing from local CIB)
Oct 29 14:40:26.451 localhost pacemaker-controld  [16724] (check_join_state) 	debug: join-1: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 14:40:26.458 localhost pacemaker-controld  [16724] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
