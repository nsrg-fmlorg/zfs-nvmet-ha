### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +60s, svc started on ctl-b at +60s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:40:28.802 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:40:28.802 localhost pacemaker-controld  [16165] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:40:31.176 localhost pacemaker-controld  [16165] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793281231
Oct 29 13:40:31.177 localhost pacemaker-controld  [16165] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793281231-6
Oct 29 13:40:33.234 localhost pacemaker-controld  [16165] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793281231
Oct 29 13:40:33.235 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.235 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.540 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:33.540 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:38.999 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:38.999 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:39.234 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.459 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:44.460 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:45.233 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:49.920 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:49.921 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:51.234 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:55.371 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:55.372 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:40:57.234 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:00.179 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:00.811 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:00.812 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:00.812 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:03.234 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:06.266 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:06.267 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:09.234 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:11.735 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:11.735 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:15.236 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:16.913 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:16.914 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:16.914 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:16.914 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:17.232 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:17.233 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:19.896 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:41:19.897 localhost pacemaker-controld  [16165] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
```
