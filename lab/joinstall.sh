#!/bin/sh
# Scenario: kill corosync on the non-DC node while systemd restarts it
# (Restart=on-failure, RestartSec=1s, Requires=pacemaker.service), so the
# node rejoins while the DC is still fencing it.
#
# Seen on Pacemaker 2.1.9: the DC sits in S_FINALIZE_JOIN after the fence
# succeeds and runs no resource actions until join-finalization-timeout
# (30 min by default) forces an election.  Suspected path, from the source:
#   - the rejoin comes in through do_dc_join_offer_one() for "an unknown
#     node", which, unlike a join request, makes no offer to the DC itself,
#     so max_generation_from is left from when the join round began;
#   - the rejoining node's CIB is newer than that, so it becomes
#     max_generation_from, and do_dc_join_finalize() leaves R_HAVE_CIB clear
#     while it delays for the transition (the fence) in progress;
#   - once the node is fenced there is nothing left to finalize, nothing
#     syncs the CIB, and check_join_state() waits for R_HAVE_CIB for ever.
# The configuration changes before the kill (BUMPS) make the round's
# recorded CIB generation older than the rejoining node's.
#
# PCMK_VERSION: "2.1.9" installs 2.1.9-1.el9 from the AlmaLinux 9.6 vault;
# "latest" keeps what the HighAvailability repository has now.
# JFT: join-finalization-timeout for the run.  STALL: seconds after the
# fence with no takeover that count as reproduced.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
PCMK_VERSION=${PCMK_VERSION:-2.1.9}
JFT=${JFT:-5min}
STALL=${STALL:-120}
BUMPS=${BUMPS:-5}
FENCE_DELAY=${FENCE_DELAY:-40}
mkdir -p "$OUT"

port() { case $1 in ctl-a) echo 2221;; ctl-b) echo 2222;; host) echo 2223;; esac; }
on() {
	v=$1; shift
	ssh -q -i "$LAB/id_ed25519" -p "$(port "$v")" \
	    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	    -o ConnectTimeout=5 ubuntu@127.0.0.1 "$@"
}
put() {
	scp -q -i "$LAB/id_ed25519" -P "$(port "$1")" \
	    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	    "$2" "ubuntu@127.0.0.1:$3"
}
log() { echo "== $(date -u +%T) $*"; }
now() { date +%s; }

for v in ctl-a ctl-b; do
	n=0
	until on "$v" test -f /var/lib/cloud/lab-ready 2>/dev/null; do
		n=$((n + 1)); [ $n -lt 120 ] || { echo "$v never became ready" >&2; exit 1; }
		sleep 10
	done
done
log "ready: $(on ctl-a uname -r)"

cat > "$OUT/corosync.conf" <<'EOF'
totem {
	version: 2
	cluster_name: lab
	transport: knet
	crypto_cipher: none
	crypto_hash: none
}
nodelist {
	node {
		ring0_addr: 10.10.0.11
		name: ctl-a
		nodeid: 1
	}
	node {
		ring0_addr: 10.10.0.12
		name: ctl-b
		nodeid: 2
	}
}
quorum {
	provider: corosync_votequorum
	two_node: 1
}
logging {
	to_syslog: yes
	timestamp: on
}
EOF
# The override from the field, as written there.
cat > "$OUT/corosync-override.conf" <<'EOF'
[Unit]
Before=pacemaker.service
Requires=pacemaker.service

StartLimitBurst=3
StartLimitIntervalSec=10s

[Service]
Restart=on-failure
RestartSec=1s
EOF

for v in ctl-a ctl-b; do
	put "$v" "$OUT/corosync.conf" /tmp/corosync.conf
	put "$v" "$OUT/corosync-override.conf" /tmp/override.conf
	put "$v" "$HERE/fence_lab" /tmp/fence_lab
	put "$v" "$LAB/id_ed25519" /tmp/lab_key
	on "$v" sudo sh -eu > "$OUT/$v-setup.txt" 2>&1 <<EOF || { cat "$OUT/$v-setup.txt"; exit 1; }
r() { for i in 1 2 3 4 5; do "\$@" && return; sleep 20; done; return 1; }
if [ "$PCMK_VERSION" = 2.1.9 ]; then
	v=2.1.9-1.el9
	# Every installed pacemaker package, to the same version.
	r dnf -y downgrade --setopt=install_weak_deps=False \
	    --repofrompath=v96ha,https://vault.almalinux.org/9.6/HighAvailability/x86_64/os/ \
	    --repofrompath=v96as,https://vault.almalinux.org/9.6/AppStream/x86_64/os/ \
	    --setopt=v96ha.gpgcheck=0 --setopt=v96as.gpgcheck=0 \
	    \$(rpm -qa --qf '%{NAME}\n' 'pacemaker*' | sed "s/\\\$/-\$v/")
fi
rpm -q pacemaker corosync
install -m 0644 /tmp/corosync.conf /etc/corosync/corosync.conf
install -d /etc/systemd/system/corosync.service.d
install -m 0644 /tmp/override.conf /etc/systemd/system/corosync.service.d/override.conf
install -m 0755 /tmp/fence_lab /usr/sbin/fence_lab
install -d -m 0700 /root/.ssh
install -m 0600 /tmp/lab_key /root/.ssh/lab_key
# The controller's debug messages carry the join decisions (journal gets
# notice and above; these go to /var/log/pacemaker/pacemaker.log).
echo 'PCMK_debug=pacemaker-controld' >> /etc/sysconfig/pacemaker
systemctl daemon-reload
EOF
done
PCMK_RPM=$(on ctl-b rpm -q pacemaker)
log "installed: $PCMK_RPM"

# ctl-b first, so that it is the DC and ctl-a the node that gets killed.
log "start ctl-b, then ctl-a"
on ctl-b sudo systemctl start corosync pacemaker
sleep 20
on ctl-a sudo systemctl start corosync pacemaker
n=0
until on ctl-b sudo crm_mon -1 2>/dev/null | grep -q 'Online: \[ ctl-a ctl-b \]'; do
	n=$((n + 1)); [ $n -lt 60 ] || { on ctl-b sudo crm_mon -1 || :; echo "cluster never formed" >&2; exit 1; }
	sleep 5
done
DC=$(on ctl-b sudo crmadmin -q -D 2>&1 | awk '{print $NF}')
log "DC: $DC"

cat > "$OUT/cib-rsc.xml" <<EOF
<resources>
  <primitive id="fence-lab" class="stonith" type="fence_lab">
    <instance_attributes id="fence-lab-ia">
      <nvpair id="fence-lab-list" name="pcmk_host_list" value="ctl-a ctl-b"/>
      <nvpair id="fence-lab-check" name="pcmk_host_check" value="static-list"/>
      <nvpair id="fence-lab-delay" name="delay" value="$FENCE_DELAY"/>
      <nvpair id="fence-lab-timeout" name="pcmk_reboot_timeout" value="120s"/>
    </instance_attributes>
    <operations><op id="fence-lab-mon" name="monitor" interval="60s"/></operations>
  </primitive>
  <primitive id="svc" class="ocf" provider="pacemaker" type="Dummy">
    <operations><op id="svc-mon" name="monitor" interval="10s"/></operations>
  </primitive>
</resources>
EOF
cat > "$OUT/cib-cons.xml" <<'EOF'
<rsc_location id="svc-prefers-a" rsc="svc" node="ctl-a" score="100"/>
EOF
put ctl-b "$OUT/cib-rsc.xml" /tmp/cib-rsc.xml
put ctl-b "$OUT/cib-cons.xml" /tmp/cib-cons.xml
on ctl-b sudo sh -eux <<EOF
crm_attribute --type crm_config --name stonith-enabled --update true
crm_attribute --type crm_config --name no-quorum-policy --update ignore
crm_attribute --type crm_config --name join-finalization-timeout --update $JFT
cibadmin --create --scope resources --xml-file /tmp/cib-rsc.xml
cibadmin --create --scope constraints --xml-file /tmp/cib-cons.xml
EOF
n=0
until on ctl-b sudo crm_mon -1 2>/dev/null | grep -q 'svc.*Started ctl-a'; do
	n=$((n + 1)); [ $n -lt 60 ] || { on ctl-b sudo crm_mon -1 || :; echo "svc never started on ctl-a" >&2; exit 1; }
	sleep 2
done

# Configuration changes after the join round began: each bumps the CIB
# epoch on both nodes, and ctl-a writes the result to its disk.
log "$BUMPS configuration changes"
i=0
while [ $i -lt "$BUMPS" ]; do
	i=$((i + 1))
	on ctl-b sudo crm_attribute --type crm_config --name lab-bump --update $i
	sleep 1
done
sleep 10
on ctl-b sudo cibadmin -Q -l 2>/dev/null | head -c 300 > "$OUT/cib-version-b.txt" || :
on ctl-a sudo cibadmin -Q -l 2>/dev/null | head -c 300 > "$OUT/cib-version-a.txt" || :
on ctl-b sudo crm_mon -1 | tee "$OUT/crm-before.txt"

log "kill corosync on ctl-a"
on ctl-b sudo logger -t lab "=== kill corosync on ctl-a ==="
t_kill=$(now)
on ctl-a sudo pkill -KILL -x corosync || :

# Poll the DC: its controller state, where svc runs, the fence history.
: > "$OUT/timeline.txt"
t_fenced= t_up= saw_finalize= limit=$(( $(echo "$JFT" | sed 's/min$//') * 60 + 180 ))
while :; do
	t=$(( $(now) - t_kill ))
	st=$(on ctl-b sudo crmadmin -S ctl-b 2>&1 | grep -o 'S_[A-Z_]*' | head -n 1)
	where=$(on ctl-b sudo crm_resource --locate -r svc 2>&1 | grep -o 'running on: ctl-[ab]' | sed 's/running on: /Started /')
	echo "$t $st $where" >> "$OUT/timeline.txt"
	[ "$st" != S_FINALIZE_JOIN ] || saw_finalize=yes
	if [ -z "$t_fenced" ] && on ctl-b sudo stonith_admin --history ctl-a 2>/dev/null | grep -q 'was able to reboot\|reboot of ctl-a successful'; then
		t_fenced=$t
		log "fenced at +${t}s"
	fi
	case $where in "Started ctl-b") t_up=$t; break;; esac
	[ $t -lt $limit ] || break
	sleep 5
done
log "svc on ctl-b at +${t_up:-never}s"

on ctl-b sudo stonith_admin --history ctl-a > "$OUT/fence-history.txt" 2>&1 || :
on ctl-b sudo journalctl -o short-precise --since "@$t_kill" -u corosync -u pacemaker -t fence_lab -t lab \
    > "$OUT/ctl-b-journal.txt" 2>&1 || :
on ctl-b sudo cat /var/log/pacemaker/pacemaker.log > "$OUT/ctl-b-pacemaker.log" 2>&1 || :
grep -E 'Accepting join-[0-9]+ request|Delaying (join-[0-9]+ )?finalization|Finalization not needed|Finalizing join|join-[0-9]+: (Complete|Still waiting)|State transition|Finalization Timer|I_ELECTION' \
    "$OUT/ctl-b-pacemaker.log" | awk -v since="$(date -d "@$t_kill" '+%b %d %T')" '$0 >= since' \
    > "$OUT/join-trace.txt" || :

# Verdict.
if [ -n "$t_fenced" ] && { [ -z "$t_up" ] || [ $((t_up - t_fenced)) -ge "$STALL" ]; }; then
	verdict=REPRODUCED
elif [ -z "$t_fenced" ]; then
	verdict="NOT FENCED (scenario did not run as meant)"
else
	verdict="not reproduced"
fi
{
	echo "### Join stall after corosync kill ($PCMK_RPM)"
	echo
	echo "- verdict: **$verdict**"
	echo "- DC: $DC; join-finalization-timeout $JFT; fence delay ${FENCE_DELAY}s; $BUMPS config changes before the kill"
	echo "- fence done at +${t_fenced:-?}s, svc started on ctl-b at +${t_up:-never}s after the kill"
	echo "- DC seen in S_FINALIZE_JOIN: ${saw_finalize:-no}"
	echo "- CIB before the kill: b \`$(grep -o 'epoch="[0-9]*"\|num_updates="[0-9]*"' "$OUT/cib-version-b.txt" | tr '\n' ' ')\`, a \`$(grep -o 'epoch="[0-9]*"\|num_updates="[0-9]*"' "$OUT/cib-version-a.txt" | tr '\n' ' ')\`"
	echo
	echo "Join decisions on the DC (debug log):"
	echo
	echo '```'
	grep -E 'Accepting join|Delaying|not needed|Finalizing join|join-[0-9]+: ' "$OUT/join-trace.txt" | cut -c1-220 | head -n 40
	echo '```'
} | tee "$OUT/summary.md"
