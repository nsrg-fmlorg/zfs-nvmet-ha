### Join stall after corosync kill (pacemaker-2.1.10-3.el9_8.x86_64)

- verdict: **NOT FENCED (scenario did not run as meant)**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 1s; partition 0s after the restart; 5 config changes before the kill
- fence done at +?s, svc started on ctl-b at +nevers after the kill
- DC seen in S_FINALIZE_JOIN: no
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 17:47:49.251 localhost pacemaker-controld  [15662] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 17:47:49.251 localhost pacemaker-controld  [15662] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 17:47:49.424 localhost pacemaker-controld  [15662] (join_make_offer) 	info: Making join-1 offers based on membership event 18
Oct 29 17:47:49.424 localhost pacemaker-controld  [15662] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 17:47:49.424 localhost pacemaker-controld  [15662] (join_make_offer) 	info: Sending join-1 offer to ctl-b
Oct 29 17:47:49.465 localhost pacemaker-controld  [15662] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793296069
Oct 29 17:47:49.465 localhost pacemaker-controld  [15662] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793296069
Oct 29 17:47:49.465 localhost pacemaker-controld  [15662] (do_dc_join_finalize) 	debug: Finalizing join-1 for 2 nodes (sync'ing from local CIB)
Oct 29 17:47:49.465 localhost pacemaker-controld  [15662] (check_join_state) 	debug: join-1: Still waiting on 2 integrated nodes | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 17:47:49.488 localhost pacemaker-controld  [15662] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
