### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +60s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:39:55.481 localhost pacemaker-controld  [15650] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281195
Oct 29 13:39:55.482 localhost pacemaker-controld  [15650] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281195-6
Oct 29 13:39:57.874 localhost pacemaker-controld  [15650] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281195
Oct 29 13:39:57.874 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:57.874 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:57.874 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:39:58.094 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:03.271 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:03.271 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:04.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:08.666 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:08.667 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:10.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:14.072 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:14.073 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:16.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:19.458 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:19.458 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:22.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:24.477 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:24.864 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:24.864 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:28.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:30.266 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:30.266 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:34.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:35.679 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:35.680 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:35.680 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:40.095 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.142 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.143 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.143 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.216 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.218 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.218 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:41.218 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.469 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.471 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.471 localhost pacemaker-controld  [15650] (do_dc_join_finalize) 	debug: Finalizing join-1 for 1 node (sync'ing from local CIB)
```
