### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +60s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:39:29.546 localhost pacemaker-controld  [16151] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281169
Oct 29 13:39:29.547 localhost pacemaker-controld  [16151] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281169-6
Oct 29 13:39:31.425 localhost pacemaker-controld  [16151] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281169
Oct 29 13:39:31.425 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:31.426 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:31.818 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:31.818 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:37.223 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:37.223 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:37.425 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:42.648 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:42.648 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:43.424 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:48.053 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:48.053 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:49.424 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:53.471 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:53.471 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:55.425 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:58.552 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:58.892 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:58.893 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:01.424 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:04.320 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:04.321 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:07.425 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:09.753 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:09.754 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:13.425 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.233 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.233 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.277 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.277 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.277 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:15.277 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:18.410 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:18.414 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:18.414 localhost pacemaker-controld  [16151] (do_dc_join_finalize) 	debug: Finalizing join-1 for 1 node (sync'ing from local CIB)
Oct 29 13:40:18.416 localhost pacemaker-controld  [16151] (check_join_state) 	debug: join-1: Still waiting on 1 integrated node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 13:40:18.426 localhost pacemaker-controld  [16151] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
