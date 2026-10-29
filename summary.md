### Join stall after corosync kill (pacemaker-3.0.1-5.el10_2.1.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 1s; partition 8s after the restart; 5 config changes before the kill
- fence done at +61s, svc started on ctl-b at +61s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 15:05:12.403 localhost pacemaker-controld  [1776] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 15:05:12.403 localhost pacemaker-controld  [1776] (join_make_offer) 	info: Making join-1 offers based on membership event 13
Oct 29 15:05:12.403 localhost pacemaker-controld  [1776] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 15:05:12.403 localhost pacemaker-controld  [1776] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 15:05:42.371 localhost pacemaker-controld  [1776] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 15:05:42.371 localhost pacemaker-controld  [1776] (join_make_offer) 	info: Making join-1 offers based on membership event 18
Oct 29 15:05:42.371 localhost pacemaker-controld  [1776] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 15:05:42.523 localhost pacemaker-controld  [1776] (join_make_offer) 	info: Sending join-1 offer to ctl-a
Oct 29 15:05:42.523 localhost pacemaker-controld  [1776] (join_make_offer) 	info: Sending join-1 offer to ctl-b
Oct 29 15:05:42.524 localhost pacemaker-controld  [1776] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793286342-
Oct 29 15:05:42.527 localhost pacemaker-controld  [1776] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793286342-6
Oct 29 15:05:44.633 localhost pacemaker-controld  [1776] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793286342-
Oct 29 15:05:44.634 localhost pacemaker-controld  [1776] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 15:05:44.634 localhost pacemaker-controld  [1776] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 15:06:00.280 localhost pacemaker-controld  [1776] (do_dc_join_offer_one) 	info: Making join-1 offers to any unconfirmed nodes because an unknown node joined
Oct 29 15:06:00.280 localhost pacemaker-controld  [1776] (join_make_offer) 	info: Making join-1 offers based on membership event 22
Oct 29 15:06:03.501 localhost pacemaker-controld  [1776] (do_dc_join_finalize) 	notice: Finalizing join-1 for 1 node (sync'ing CIB 0.15.8 with schema pacemaker-4.0 and feature set 3.20.1 from ctl-b)
Oct 29 15:06:03.502 localhost pacemaker-controld  [1776] (check_join_state) 	debug: join-1: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 15:06:03.516 localhost pacemaker-controld  [1776] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
