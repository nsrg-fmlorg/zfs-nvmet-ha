# Pacemaker with the join finalization fix

[日本語は下にあります](#日本語)

AlmaLinux's current pacemaker, rebuilt with one fix to the controller
(`pacemaker-controld`).  Without it, the DC can stop scheduling anything
for `join-finalization-timeout` (30 minutes by default) after it fences a
node that rejoined while the fence was in progress.

| directory | rebuilt from | packages |
|---|---|---|
| `el9/` | pacemaker-2.1.10-3.el9 | `pacemaker-2.1.10-3.lab1.el9` |
| `el10/` | pacemaker-3.0.1-5 (el10 source) | `pacemaker-3.0.1-5.lab1.el10.1` |

Each directory is a dnf repository (`repodata/`); the source RPM is in
`SRPMS/`.  The patches are in `lab/patches/pacemaker-*-join-offer-self.patch`
on the `joinstall-repro` branch (also for 2.1.9 and upstream main).

## Symptom

On a two-node cluster, corosync on the non-DC node dies and systemd
restarts it at once (`Restart=on-failure`, `RestartSec=1s`, with
`Requires=pacemaker.service` so pacemaker comes back too).  The DC starts
fencing the node; the node rejoins before the fence completes; the fence
then succeeds.  After that the DC stays in `S_FINALIZE_JOIN`, runs no
resource actions (in the field: no DRBD promote, no NFS, no VIP) and logs
nothing until the Finalization Timer pops and forces an election:

    Delaying join-3 finalization while transition in progress   (repeated)
    Peer ... was terminated (reboot) ...: OK
    Transition 38602 (...): Stopped
    ... nothing for 30 minutes ...
    State transition S_ELECTION -> S_INTEGRATION

## Cause

In `daemons/controld/controld_join_dc.c`:

1. The DC records, for the current join round, which node has the newest
   CIB (`max_generation_from`); the finalization syncs the CIB from that
   node, and only then sets `R_HAVE_CIB`.
2. When a join request arrives, `do_dc_join_offer_one()` also makes the
   local node (the DC) an offer, "to ensure the correct value for
   max_generation_from".  When it makes offers because an unknown node
   joined (a membership change), it does not.
3. So a node rejoining a long-running join round is compared against the
   generation recorded when the round began.  Its CIB is newer than that,
   and it becomes `max_generation_from`.
4. `do_dc_join_finalize()` clears `R_HAVE_CIB`, sets it again only when
   `max_generation_from` is the DC, and then waits for the transition
   (the fence) in progress.
5. The fence removes the node.  There is now nothing to finalize, so no
   sync is ever requested, `R_HAVE_CIB` is never set, and
   `check_join_state()` waits for it ("Delaying finalization until we have
   CIB", a debug message) until `join-finalization-timeout`.

Whether the DC is rescued depends on timing: if the rejoining node's
controller is slow enough to answer the DC's offer only after sending its
join announce, the announce comes in as a join request, the DC offers
itself, and `max_generation_from` goes back to the DC.  When the node's
pacemaker starts before the DC can see it (as on the hardware in the
field), the announce is lost and nothing puts it back.  A DC that was
itself the node killed is not affected: the survivor wins an election and
starts a fresh join round.

The code is the same in 2.1.9, 2.1.10, 3.0.1 and upstream main.

## Fix

In the "unknown node joined" path, make the local node an offer too when
any offer went out, as the join request path already does:

```diff
         g_hash_table_foreach(pcmk__peer_cache, join_make_offer, &member);
+
+        if (crmd_join_phase_count(controld_join_welcomed) > 0) {
+            member = controld_get_local_node_status();
+            if (controld_get_join_phase(member) != controld_join_welcomed) {
+                join_make_offer(NULL, member, NULL);
+            }
+        }
         check_join_state(cur_state, __func__);
         return;
```

The DC answers its own offer with its current CIB, which is never older
than a rejoining node's, so `max_generation_from` is the DC again and the
finalization goes ahead once the fence is done.

## Verification

`lab/joinstall.sh` on the `joinstall-repro` branch, run by GitHub Actions
in two AlmaLinux VMs: kill corosync on the non-DC node with the override
above, with corosync traffic dropped from the kill until 8 s after the
restart (so the node's pacemaker starts before the DC can see it, as in
the field), a fence agent that resets the node after 40 s, and
`join-finalization-timeout` shortened to 5 min.

| package | result |
|---|---|
| 2.1.9-1.el9 | stalled 3/3 (resources started ~5 min after the fence) |
| 2.1.9-1.lab1.el9 (fixed) | no stall 3/3 (started as soon as the fence completed) |
| 2.1.10-3.el9_8 | stalled 5/5 |
| 2.1.10-3.lab1.el9 (fixed) | no stall 2/2 |
| 3.0.1-5.el10_2.1 | stalled 1/2 (the other run was rescued by the join announce) |
| 3.0.1-5.lab1.el10.1 (fixed) | no stall 2/2 |

## Installing

On every node, over the distribution's packages (the names already
installed), then restart the cluster one node at a time.  For example on
EL9, in `el9/`:

    sudo dnf install $(rpm -qa --qf '%{NAME}\n' 'pacemaker*' | sed 's/$/-2.1.10-3.lab1.el9.*.rpm/')

## The configuration that sets it off

The packaged `corosync.service` says to use `Restart=on-failure` only with
the watchdog, with `RestartSec` longer than the watchdog's timeout
(`RestartSec=70`), so that the watchdog resets the node before corosync
comes back.  `RestartSec=1s` brings the node back within the fence, which
is what reaches this bug; and `Requires=watchdog.service` stops and
restarts the watchdog daemon along with corosync, so the watchdog never
acts.  A `RestartSec` longer than the watchdog timeout and the fence (or no
`Restart=`) avoids the race even without the fix.

---

## 日本語

AlmaLinux の現行の pacemaker に、コントローラ(`pacemaker-controld`)の修正を
1つ当てて再ビルドしたものです。この修正がないと、フェンス中にクラスタへ戻ってきた
ノードを DC がフェンスしたあと、DC が `join-finalization-timeout`(既定 30 分)の間、
何もスケジュールしなくなることがあります。

| ディレクトリ | 元のパッケージ | 修正版 |
|---|---|---|
| `el9/` | pacemaker-2.1.10-3.el9 | `pacemaker-2.1.10-3.lab1.el9` |
| `el10/` | pacemaker-3.0.1-5(el10 のソース) | `pacemaker-3.0.1-5.lab1.el10.1` |

各ディレクトリは dnf のリポジトリ(`repodata/`)になっていて、SRPM は `SRPMS/` に
あります。パッチは `joinstall-repro` ブランチの
`lab/patches/pacemaker-*-join-offer-self.patch` です(2.1.9 用と upstream main 用もあります)。

### 症状

2ノード構成で、DC でない側の corosync が落ち、systemd がすぐに再起動します
(`Restart=on-failure`、`RestartSec=1s`。`Requires=pacemaker.service` で pacemaker も
一緒に戻る)。DC はそのノードのフェンスを始めますが、フェンスが終わる前にノードが
クラスタへ戻り、そのあとフェンスが成功します。

その後 DC は `S_FINALIZE_JOIN` のまま止まります。リソース操作を一切行わず
(現場では DRBD の昇格も NFS も VIP も起動せず)、ログにも何も出さないまま、
Finalization Timer が切れて再選出されるまで待ち続けます。

    Delaying join-3 finalization while transition in progress   (繰り返し)
    Peer ... was terminated (reboot) ...: OK
    Transition 38602 (...): Stopped
    ... 30 分間なにも出ない ...
    State transition S_ELECTION -> S_INTEGRATION

### 原因

`daemons/controld/controld_join_dc.c` の処理の流れです。

1. DC は join ラウンドごとに、いちばん新しい CIB を持つノード(`max_generation_from`)を
   記録します。JOIN 最終化ではそのノードから CIB を同期し、同期が終わってはじめて
   `R_HAVE_CIB` を立てます。
2. `do_dc_join_offer_one()` は、join request を受けたときには
   「max_generation_from を正しく保つため」に DC 自身にも offer を出し直します。
   ところが membership の変化で「unknown node joined」として offer を出すときには、
   これをしていません。
3. そのため、長く続いている join ラウンドに途中から戻ってきたノードは、ラウンド開始時の
   古い記録と比べられます。戻ってきたノードの CIB の方が新しいので、
   そのノードが `max_generation_from` になります。
4. `do_dc_join_finalize()` は `R_HAVE_CIB` をいったん落とし、`max_generation_from` が
   DC 自身のときだけ立て直します。今回は立て直されないまま、実行中の Transition
   (フェンス)の完了を待ちます。
5. フェンスでそのノードがいなくなると、最終化する相手がいないので CIB 同期が一度も
   要求されません。`R_HAVE_CIB` は立たないままで、`check_join_state()` が
   `join-finalization-timeout` までそれを待ち続けます。このとき出るのは
   「Delaying finalization until we have CIB」という debug メッセージだけです。

救われるかどうかはタイミング次第です。戻ってきたノードのコントローラが遅く、
DC の offer に答えるより先に join announce を送った場合は、その announce が
join request として処理され、DC が自分にも offer し直すので、`max_generation_from` が
DC に戻ります。現場の実機のように、ノードの pacemaker が DC から見える前に起動した
場合は announce が空振りし、元に戻すきっかけがありません。
なお、kill されたのが DC 自身だった場合は影響を受けません。残ったノードが選出されて、
新しい join ラウンドが始まるためです。

該当箇所のコードは 2.1.9、2.1.10、3.0.1、upstream main のいずれも同じです。

### 修正

「unknown node joined」の経路でも、offer を1つでも出したときは DC 自身にも offer を
出します。join request の経路がすでにしているのと同じ処理です(差分は上の英語の節を参照)。

DC は自分の現在の CIB で応答します。これは戻ってきたノードの CIB より古くなることが
ないので、`max_generation_from` が DC に戻り、フェンスが終われば最終化が進みます。

### 検証

`joinstall-repro` ブランチの `lab/joinstall.sh` を、GitHub Actions 上の AlmaLinux VM
2台で実行しました。条件は次のとおりです。

- DC でない側の corosync を、上記の override のまま kill する
- kill から再起動後 8 秒まで corosync の通信を遮断する(現場と同じく、ノードの
  pacemaker が DC から見える前に起動するようにするため)
- フェンスエージェントは 40 秒後にノードをリセットする
- `join-finalization-timeout` は 5 分に短縮する

| パッケージ | 結果 |
|---|---|
| 2.1.9-1.el9 | 3/3 で停止(フェンスの約 5 分後にリソース起動) |
| 2.1.9-1.lab1.el9(修正版) | 3/3 で停止せず(フェンス完了と同時に起動) |
| 2.1.10-3.el9_8 | 5/5 で停止 |
| 2.1.10-3.lab1.el9(修正版) | 2/2 で停止せず |
| 3.0.1-5.el10_2.1 | 1/2 で停止(もう1回は join announce で救われた) |
| 3.0.1-5.lab1.el10.1(修正版) | 2/2 で停止せず |

### 入れ方

全ノードで、インストール済みの pacemaker 系パッケージを置き換えてから、
クラスタを1ノードずつ再起動してください。EL9 なら `el9/` で次のように実行します。

    sudo dnf install $(rpm -qa --qf '%{NAME}\n' 'pacemaker*' | sed 's/$/-2.1.10-3.lab1.el9.*.rpm/')

### 引き金になった設定

パッケージに入っている `corosync.service` のコメントでは、`Restart=on-failure` は
watchdog と組み合わせて使い、`RestartSec` は watchdog のタイムアウトより長く
(`RestartSec=70`)するように書かれています。corosync が戻る前に、watchdog に
ノードをリセットさせるためです。

`RestartSec=1s` だとフェンスの最中にノードが戻ってきてしまい、これが今回の不具合を
踏む直接の原因になります。また `Requires=watchdog.service` があると、corosync と
一緒に watchdog デーモンも止まって起動し直すため、watchdog が働きません。

`RestartSec` を watchdog のタイムアウトとフェンスの所要時間より長くする
(または `Restart=` を使わない)と、修正版でなくてもこの競合は起きません。
