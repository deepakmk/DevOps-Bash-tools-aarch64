#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2021-04-16 17:44:30 +0100 (Fri, 16 Apr 2021)
#
#  https://github.com/HariSekhon/bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(dirname "${BASH_SOURCE[0]}")"

# shellcheck disable=SC1090
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Drains all Kubernetes nodes from a given GKE cluster's nodepool

- finds instance groups in a node pool
- finds nodes in each instance group
- cordons all nodes (to prevent pod migrations to other nodes in the same pool)
- drains pods from each node in sequence

Requires GCloud SDK to be installed and configured

If CLOUDSDK_CONTAINER_CLUSTER is set then you don't have to specify the cluster name

This is so that you can shut down the pool
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<cluster_name>] <node_pool_name>"

help_usage "$@"

min_args 1 "$@"

if [ $# -eq 2 ]; then
    export GCLOUD_CONTAINER_CLUSTER="$1"
    node_pool="$2"
elif [ $# -eq 1 ]; then
    node_pool="$1"
else
    usage
fi

timestamp "finding instance groups in node pool '$node_pool'"
instance_groups="$(
    gcloud container node-pools describe "$node_pool" --format=json |
    jq -r '.instanceGroupUrls[] | sub("^.*/"; "")'
)"

nodes="$(
    for instance_group in $instance_groups; do
        #timestamp "finding zone of instance group '$instance_group'"
        timestamp "finding nodes in instance group '$instance_group'"
        zone="$(gcloud compute instance-groups list --filter="name=$instance_group" --format='get(zone)' | sed 's|^.*/||')"
        gcloud compute instance-groups list-instances "$instance_group" --zone "$zone" --format='value(NAME)'  # doesn't find it without zone, and NAME must be capitalized too
    done
)"

for node in $nodes; do
    echo kubectl cordon "$node"
done

for node in $nodes; do
    echo kubectl drain "$node"
done
