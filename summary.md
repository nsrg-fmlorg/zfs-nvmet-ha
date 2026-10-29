### Join stall after corosync kill (pacemaker-2.1.9-1.el9.x86_64)

- verdict: **NOT FENCED (scenario did not run as meant)**
- DC: ctl-b; join-finalization-timeout 5min; fence delay 40s; 5 config changes before the kill
- fence done at +?s, svc started on ctl-b at +nevers after the kill
- DC seen in S_FINALIZE_JOIN: no
- CIB before the kill: b `epoch="15" num_updates="0" epoch="0" `, a `epoch="15" num_updates="0" epoch="0" `

Join decisions on the DC (debug log):

```
Oct 29 12:58:59.836 localhost pacemaker-controld  [15909] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a (with better CIB generation than current best from ctl-b) | ref=join_request-crmd-1793278739
Oct 29 12:58:59.839 localhost pacemaker-controld  [15909] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b | ref=join_request-crmd-1793278739-39
Oct 29 12:58:59.839 localhost pacemaker-controld  [15909] (do_dc_join_finalize) 	notice: Finalizing join-1 for 2 nodes (sync'ing CIB from ctl-a)
Oct 29 12:58:59.842 localhost pacemaker-controld  [15909] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-b | ref=join_request-crmd-1793278739-42
Oct 29 12:58:59.843 localhost pacemaker-controld  [15909] (do_dc_join_filter_offer) 	debug: Accepting join-1 request from ctl-a | ref=join_request-crmd-1793278739-7
Oct 29 12:58:59.843 localhost pacemaker-controld  [15909] (do_dc_join_finalize) 	notice: Finalizing join-1 for 2 nodes (sync'ing CIB from ctl-a)
Oct 29 12:58:59.845 localhost pacemaker-controld  [15909] (check_join_state) 	debug: join-1: Still waiting on 2 integrated nodes | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 12:58:59.850 localhost pacemaker-controld  [15909] (check_join_state) 	debug: join-1: Still waiting on 1 finalized node | state=S_FINALIZE_JOIN for=finalize_sync_callback
Oct 29 12:58:59.854 localhost pacemaker-controld  [15909] (check_join_state) 	debug: join-1: Complete | state=S_FINALIZE_JOIN for=join_node_state_commit_callback
```
