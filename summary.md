### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **not reproduced**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; RestartSec 6s; 5 config changes before the kill
- fence done at +61s, svc started on ctl-b at +61s after the kill
- DC seen in S_FINALIZE_JOIN: yes
- CIB before the kill: b ` epoch="15"  num_updates="0"  admin_epoch="0" `, a ` epoch="15"  num_updates="0"  admin_epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 13:12:26.296 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	debug: Finalization not needed for join-1 at the current time
Oct 29 13:12:26.296 localhost pacemaker-controld  [15752] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=do_dc_join_finalize
Oct 29 13:12:28.759 localhost pacemaker-controld  [15752] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793279548
Oct 29 13:12:28.760 localhost pacemaker-controld  [15752] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793279548-6
Oct 29 13:12:29.923 localhost pacemaker-controld  [15752] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b (with better CIB generation than current best from ctl-a) | ref=join_request-crmd-1793279548
Oct 29 13:12:29.923 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:29.923 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:31.176 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:31.177 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:35.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:36.656 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:36.656 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:41.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:42.138 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:42.138 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.612 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.612 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.612 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:47.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:53.114 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:53.115 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:53.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:57.755 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:58.598 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:58.599 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:12:59.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:04.083 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:04.084 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:05.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:09.613 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:09.614 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:09.614 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:11.922 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:13.372 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:13.376 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:13.377 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:13.378 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:15.172 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:15.172 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
Oct 29 13:13:16.386 localhost pacemaker-controld  [15752] (do_dc_join_finalize) 	warning: Delaying join-1 finalization while transition in progress
```
