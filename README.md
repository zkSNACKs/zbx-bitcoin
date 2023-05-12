# zbx-bitcoin

Template and script for Zabbix to monitor Bitcoin Core or Knots node.

## Dependencies

* bc
* bitcoin-cli
* jq
* zabbix_sender

## Setup

* Import zbx_export_templates.yaml into Zabbix;
* Make zbx-bitcoin-status.sh run on a machine continuously, either using SystemD or cron job (it has a locking mechanism, you can just launch it each minute from cron).

## Items

* Cumulative sizes of mempool transactions per various fee rate groups (Bitcoin Knots only)
* Current number of headers validated
* Estimated size of the block and undo files on disk
* Estimate of blockchain verification progress
* Fee estimations for various block targets
* Height of the most-work fully-validated chain
* Maximum memory usage for the mempool
* Mempool size
* Minimum relay fee for transactions
* Node connection count
* Node incoming connection count
* Node outgoing connection count
* Number of active RPC commands
* Protocol version
* Server subversion string
* Server version
* Total memory usage for the mempool
* TX count in mempool

## Triggers

* Protocol version has changed
* Server subversion string has changed
* Server version has changed
* Validated blockchain tip hasn't changed for 3 hours

## Dashboard

![image](https://user-images.githubusercontent.com/4500994/229270913-573e89da-7624-4aba-914d-f505beb3b758.png)
