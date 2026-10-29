#!/bin/sh
# Exercise the nvmet-* resource agents of ClusterLabs/resource-agents with
# lab/patches/resource-agents-nvmet-ana-cntlid.diff applied, on ctl-a,
# and read the resulting ANA state back from the host.
#
# The agents run from a checkout of the upstream commit the patch was made
# against; ocf-shellfuncs comes from the distribution's resource-agents.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
RA_COMMIT=81e937fdb694d39aafbb9ac8ca415b188bb0751b
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

for v in ctl-a host; do
	n=0
	until on "$v" test -f /var/lib/cloud/lab-ready 2>/dev/null; do
		n=$((n + 1)); [ $n -lt 120 ] || { echo "$v never became ready" >&2; exit 1; }
		sleep 10
	done
done
put ctl-a "$HERE/patches/resource-agents-nvmet-ana-cntlid.diff" /home/ubuntu/ra.diff

on ctl-a sudo sh -eu > "$OUT/agents.txt" 2>&1 <<EOF || { cat "$OUT/agents.txt"; exit 1; }
git clone -q --filter=blob:none https://github.com/ClusterLabs/resource-agents.git /home/ubuntu/ra
cd /home/ubuntu/ra
git checkout -q $RA_COMMIT
git apply /home/ubuntu/ra.diff

export OCF_ROOT=/usr/lib/ocf
export OCF_FUNCTIONS_DIR=/usr/lib/ocf/lib/heartbeat
C=/sys/kernel/config/nvmet
NQN=nqn.2026-10.org.fml.nsrg:ra-test
fail=0
ok()  { echo "ok   \$*"; }
bad() { echo "FAIL \$*"; fail=1; }
# expect <rc> <what> <command...>
expect() {
	want=\$1 what=\$2; shift 2
	rc=0; "\$@" > /dev/null 2>&1 || rc=\$?
	[ \$rc -eq \$want ] && ok "\$what (rc \$rc)" || bad "\$what: rc \$rc, want \$want"
}
# equal <file> <value>
equal() {
	got=\$(cat "\$1" 2>/dev/null || echo '<missing>')
	[ "\$got" = "\$2" ] && ok "\$1 = \$2" || bad "\$1 = \$got, want \$2"
}

for a in nvmet-subsystem nvmet-namespace nvmet-port; do
	sh heartbeat/\$a meta-data > /home/ubuntu/\$a.xml
	xmllint --noout --dtdvalid heartbeat/ra-api-1.dtd /home/ubuntu/\$a.xml && ok "\$a meta-data valid" || bad "\$a meta-data"
done

modprobe nvmet; modprobe nvmet-tcp; modprobe null_blk nr_devices=1

# subsystem: cntlid range
expect 6 "cntlid_min above cntlid_max refused" \
    env OCF_RESKEY_nqn=\$NQN OCF_RESKEY_cntlid_min=2000 OCF_RESKEY_cntlid_max=1000 sh heartbeat/nvmet-subsystem validate-all
expect 6 "cntlid_max above 65519 refused" \
    env OCF_RESKEY_nqn=\$NQN OCF_RESKEY_cntlid_max=65520 sh heartbeat/nvmet-subsystem validate-all
expect 6 "cntlid_min 0 refused" \
    env OCF_RESKEY_nqn=\$NQN OCF_RESKEY_cntlid_min=0 sh heartbeat/nvmet-subsystem validate-all
expect 0 "subsystem start with cntlid 1000..1999" \
    env OCF_RESKEY_nqn=\$NQN OCF_RESKEY_cntlid_min=1000 OCF_RESKEY_cntlid_max=1999 sh heartbeat/nvmet-subsystem start
equal \$C/subsystems/\$NQN/attr_cntlid_min 1000
equal \$C/subsystems/\$NQN/attr_cntlid_max 1999

# namespace: ANA group
expect 6 "ana_grpid 129 refused" \
    env OCF_RESKEY_nqn=\$NQN OCF_RESKEY_namespace_id=1 OCF_RESKEY_backing_path=/dev/nullb0 \
        OCF_RESKEY_uuid=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0099 OCF_RESKEY_ana_grpid=129 sh heartbeat/nvmet-namespace validate-all
expect 0 "namespace start in ANA group 2" \
    env OCF_RESKEY_nqn=\$NQN OCF_RESKEY_namespace_id=1 OCF_RESKEY_backing_path=/dev/nullb0 \
        OCF_RESKEY_uuid=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0099 OCF_RESKEY_ana_grpid=2 sh heartbeat/nvmet-namespace start
equal \$C/subsystems/\$NQN/namespaces/1/ana_grpid 2

# port: ANA state
P="OCF_RESKEY_port_id=5 OCF_RESKEY_addr=10.10.0.11 OCF_RESKEY_svcid=4421 OCF_RESKEY_nqns=\$NQN"
expect 6 "ana_state bogus refused" env \$P OCF_RESKEY_ana_state=bogus sh heartbeat/nvmet-port validate-all
expect 6 "port ana_grpid 0 refused" env \$P OCF_RESKEY_ana_grpid=0 sh heartbeat/nvmet-port validate-all
expect 0 "port start, group 2 inaccessible" \
    env \$P OCF_RESKEY_ana_grpid=2 OCF_RESKEY_ana_state=inaccessible sh heartbeat/nvmet-port start
equal \$C/ports/5/ana_groups/2/ana_state inaccessible
[ -L \$C/ports/5/subsystems/\$NQN ] && ok "subsystem linked" || bad "subsystem not linked"
EOF
cat "$OUT/agents.txt"

# The host reads the state through the ANA log page, before and after a
# reload changes it.
ana_log() {
	on host sudo sh -eu <<'EOF'
modprobe nvme-tcp
nvme connect -t tcp -a 10.10.0.11 -s 4421 -n nqn.2026-10.org.fml.nsrg:ra-test > /dev/null 2>&1 || :
sleep 2
c=
for d in /sys/class/nvme/nvme*; do
	[ "$(cat $d/subsysnqn)" = nqn.2026-10.org.fml.nsrg:ra-test ] && c=${d##*/}
done
[ -n "$c" ] || { echo "no controller"; exit 0; }
# The raw page goes to stderr, into the log, so a parse that finds
# nothing can be told apart from a read that failed.
nvme version >&2
nvme ana-log /dev/$c >&2 || echo "ana-log on $c failed: $?" >&2
# Key names in nvme-cli's JSON differ between versions; match loosely.
nvme ana-log /dev/$c -o json | tee /dev/stderr | python3 -c '
import json,sys
def walk(o):
    if isinstance(o, dict):
        g = [v for k, v in o.items() if "grpid" in k.lower() or "group" in k.lower()]
        s = [v for k, v in o.items() if "state" in k.lower()]
        if g and s:
            print("grpid %s state %s" % (g[0], s[0]))
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(json.load(sys.stdin))'
EOF
}
echo "host before reload: $(ana_log 2>>"$OUT/ana-raw.txt" | tr '\n' ' ')" | tee -a "$OUT/agents.txt"

on ctl-a sudo sh -eu >> "$OUT/agents.txt" 2>&1 <<EOF || { cat "$OUT/agents.txt"; exit 1; }
cd /home/ubuntu/ra
export OCF_ROOT=/usr/lib/ocf OCF_FUNCTIONS_DIR=/usr/lib/ocf/lib/heartbeat
C=/sys/kernel/config/nvmet
NQN=nqn.2026-10.org.fml.nsrg:ra-test
P="OCF_RESKEY_port_id=5 OCF_RESKEY_addr=10.10.0.11 OCF_RESKEY_svcid=4421 OCF_RESKEY_nqns=\$NQN OCF_RESKEY_ana_grpid=2"
env \$P OCF_RESKEY_ana_state=optimized sh heartbeat/nvmet-port reload && echo "ok   reload rc 0" || echo "FAIL reload"
s=\$(cat \$C/ports/5/ana_groups/2/ana_state)
[ "\$s" = optimized ] && echo "ok   reload set optimized" || echo "FAIL reload left \$s"
EOF
sleep 2
echo "host after reload: $(ana_log 2>>"$OUT/ana-raw.txt" | tr '\n' ' ')" | tee -a "$OUT/agents.txt"

on host sudo nvme disconnect -n nqn.2026-10.org.fml.nsrg:ra-test > /dev/null 2>&1 || :
on ctl-a sudo sh -eu >> "$OUT/agents.txt" 2>&1 <<EOF || :
cd /home/ubuntu/ra
export OCF_ROOT=/usr/lib/ocf OCF_FUNCTIONS_DIR=/usr/lib/ocf/lib/heartbeat
C=/sys/kernel/config/nvmet
NQN=nqn.2026-10.org.fml.nsrg:ra-test
env OCF_RESKEY_port_id=5 OCF_RESKEY_addr=10.10.0.11 OCF_RESKEY_svcid=4421 OCF_RESKEY_nqns=\$NQN OCF_RESKEY_ana_grpid=2 \
    sh heartbeat/nvmet-port stop && echo "ok   port stop rc 0" || echo "FAIL port stop"
[ -d \$C/ports/5 ] && echo "FAIL port 5 still there" || echo "ok   port 5 removed with its ANA group"
EOF

# Started again with another state: what a cluster does when ana_state
# changes, since the agent does not advertise reload to Pacemaker.
on ctl-a sudo sh -eu >> "$OUT/agents.txt" 2>&1 <<EOF || :
cd /home/ubuntu/ra
export OCF_ROOT=/usr/lib/ocf OCF_FUNCTIONS_DIR=/usr/lib/ocf/lib/heartbeat
C=/sys/kernel/config/nvmet
NQN=nqn.2026-10.org.fml.nsrg:ra-test
env OCF_RESKEY_port_id=5 OCF_RESKEY_addr=10.10.0.11 OCF_RESKEY_svcid=4421 OCF_RESKEY_nqns=\$NQN OCF_RESKEY_ana_grpid=2 \
    OCF_RESKEY_ana_state=non-optimized sh heartbeat/nvmet-port start && echo "ok   port start again rc 0" || echo "FAIL port start again"
s=\$(cat \$C/ports/5/ana_groups/2/ana_state)
[ "\$s" = non-optimized ] && echo "ok   started again as non-optimized" || echo "FAIL started again as \$s"
EOF
echo "host after restart: $(ana_log 2>>"$OUT/ana-raw.txt" | tr '\n' ' ')" | tee -a "$OUT/agents.txt"
on host sudo nvme disconnect -n nqn.2026-10.org.fml.nsrg:ra-test > /dev/null 2>&1 || :
on ctl-a sudo sh -eu >> "$OUT/agents.txt" 2>&1 <<EOF || :
cd /home/ubuntu/ra
export OCF_ROOT=/usr/lib/ocf OCF_FUNCTIONS_DIR=/usr/lib/ocf/lib/heartbeat
env OCF_RESKEY_port_id=5 OCF_RESKEY_addr=10.10.0.11 OCF_RESKEY_svcid=4421 OCF_RESKEY_nqns=nqn.2026-10.org.fml.nsrg:ra-test OCF_RESKEY_ana_grpid=2 \
    sh heartbeat/nvmet-port stop && echo "ok   final port stop rc 0" || echo "FAIL final port stop"
EOF
tail -n 6 "$OUT/agents.txt"
echo "--- raw ANA log as the host read it"; cat "$OUT/ana-raw.txt" 2>/dev/null || :

{
	echo "### resource agents (ClusterLabs/resource-agents $(echo $RA_COMMIT | cut -c1-8) + patch)"
	echo
	grep -E '^(ok|FAIL)|^host ' "$OUT/agents.txt" | sed 's/^/- /'
} | tee -a "$OUT/summary.md"

! grep -q '^FAIL' "$OUT/agents.txt"
grep -q 'host before reload:.*grpid 2 state inaccessible' "$OUT/agents.txt"
grep -q 'host after reload:.*grpid 2 state optimized' "$OUT/agents.txt"
grep -q 'host after restart:.*grpid 2 state non-optimized' "$OUT/agents.txt"
