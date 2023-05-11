#!/usr/bin/env bash

bitcoin_cli="bitcoin-cli"
bitcoin_cli_options=""
zabbix_sender="zabbix_sender -c /etc/zabbix/zabbix_agentd.conf"
measurement_rate="60s"

estimatesmartfee_targets=(
    1       # 10 minutes
    2       # 20 minutes
    3       # 30 minutes
    4       # 40 minutes
    6       # 1 hour
    12      # 2 hours
    24      # 4 hours
    48      # 8 hours
    72      # 12 hours
    108     # 18 hours
    144     # 1 day
    504     # 3 days
    1008    # 1 week
)

lockdir="/tmp/$(basename "$0").lock"
if mkdir "$lockdir" 2> /dev/null; then
    trap 'rm -rf "$lockdir"' 0
    trap "exit 2" 1 2 3 15
else
    exit 1
fi
echo "$$" > "$lockdir"/pid 2> /dev/null || exit 2

# assume all first parameters beginning with dash are bitcoin-cli options
while (( ${#} > 0 )) && [[ ${1:0:1} == "-" ]]; do
    bitcoin_cli_options="$bitcoin_cli_options $1"
    shift
done
bitcoin_cli="$bitcoin_cli$bitcoin_cli_options"

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $bitcoin_cli"

while :; do

    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Requesting bitcoind status"

    blockchain_info="$($bitcoin_cli getblockchaininfo)"
    if [[ -z "$blockchain_info" ]]; then
        # empty response here means bitcoind is not responding, retry after 1 sec.
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ... empty response"
        sleep 1s
        continue
    fi

    blockchain_tip_blocks="$(jq ".blocks" <<< "$blockchain_info")"
    blockchain_tip_headers="$(jq ".headers" <<< "$blockchain_info")"
    blockchain_verificationprogress="$(jq ".verificationprogress" <<< "$blockchain_info")"
    blockchain_size_on_disk="$(jq ".size_on_disk" <<< "$blockchain_info")"

    network_info="$($bitcoin_cli getnetworkinfo)"
    bitcoind_version="$(jq ".version" <<< "$network_info")"
    bitcoind_subversion="$(jq ".subversion" <<< "$network_info")"
    bitcoind_protocolversion="$(jq ".protocolversion" <<< "$network_info")"
    bitcoind_connections="$(jq ".connections" <<< "$network_info")"
    bitcoind_connections_in="$(jq ".connections_in" <<< "$network_info")"
    bitcoind_connections_out="$(jq ".connections_out" <<< "$network_info")"

    mempool_info="$($bitcoin_cli getmempoolinfo)"
    mempool_tx_count="$(jq ".size" <<< "$mempool_info")"
    mempool_size_vbytes="$(jq ".bytes" <<< "$mempool_info")"
    mempool_usage_bytes="$(jq ".usage" <<< "$mempool_info")"

    rpc_active_commands="$($bitcoin_cli getrpcinfo | jq ".active_commands | length")"
    # -1, to not count us
    rpc_active_commands=$(( rpc_active_commands - 1 ))

    set -x

    $zabbix_sender -k bitcoin.blockchain.tip.blocks -o "$blockchain_tip_blocks"
    $zabbix_sender -k bitcoin.blockchain.tip.headers -o "$blockchain_tip_headers"
    $zabbix_sender -k bitcoin.blockchain.verificationprogress -o "$blockchain_verificationprogress"
    $zabbix_sender -k bitcoin.blockchain.size_on_disk -o "$blockchain_size_on_disk"
    $zabbix_sender -k bitcoin.version -o "$bitcoind_version"
    $zabbix_sender -k bitcoin.subversion -o "$bitcoind_subversion"
    $zabbix_sender -k bitcoin.protocolversion -o "$bitcoind_protocolversion"
    $zabbix_sender -k bitcoin.connections.num -o "$bitcoind_connections"
    $zabbix_sender -k bitcoin.connections_in.num -o "$bitcoind_connections_in"
    $zabbix_sender -k bitcoin.connections_out.num -o "$bitcoind_connections_out"
    $zabbix_sender -k bitcoin.mempool.tx_count -o "$mempool_tx_count"
    $zabbix_sender -k bitcoin.mempool.size_vbytes -o "$mempool_size_vbytes"
    $zabbix_sender -k bitcoin.mempool.usage_bytes -o "$mempool_usage_bytes"
    $zabbix_sender -k bitcoin.rpc.active_commands.num -o "$rpc_active_commands"

    for i in $(seq 0 $(( ${#estimatesmartfee_targets[@]} - 1 )) ); do
        # Can't use jq here as it converts some numbers to scientific notation
        # which bc does not like. So use grep instead.
        $zabbix_sender \
            -k bitcoin.estimatesmartfee["${estimatesmartfee_targets[$i]}"] \
            -o "$(bc <<< "$($bitcoin_cli estimatesmartfee "${estimatesmartfee_targets[$i]}" | grep ".feerate" | grep -Eo "[0-9]+\.[0-9]+") * 100000")"
    done

    set +x

    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Sleeping for $measurement_rate"
    sleep "$measurement_rate"
done
