#!/usr/bin/env bash
#  SPDX-License-Identifier: BSD-3-Clause
#  Copyright (C) 2024 Intel Corporation
#  All rights reserved.
#

testdir=$(readlink -f "$(dirname "$0")")
rootdir=$(readlink -f "$testdir/../../")

source "$rootdir/test/common/autotest_common.sh"
source "$testdir/common.sh"

rpc=rpc_cmd

function scheduler_opts() {
	"${SPDK_APP[@]}" -m "$spdk_cpumask" &
	spdk_pid=$!
	trap 'killprocess $spdk_pid; exit 1' SIGINT SIGTERM EXIT
	waitforlisten $spdk_pid

	# It is possible to change settings generic scheduler opts for schedulers in event framework
	$rpc framework_set_scheduler static -p 424242
	[[ "$($rpc framework_get_scheduler | jq -r '. | select(.scheduler_name == "static") | .scheduler_period')" -eq 424242 ]]

	# Verify that the scheduler is changed and the non-default value is set
	$rpc framework_set_scheduler dynamic --core-limit 42
	[[ "$($rpc framework_get_scheduler | jq -r '. | select(.scheduler_name == "dynamic") | .core_limit')" -eq 42 ]]

	# Switch scheduler back and forth and verify values are kept (scheduler implementation specific)
	$rpc framework_set_scheduler gscheduler
	[[ "$($rpc framework_get_scheduler | jq -r '.scheduler_name')" == "gscheduler" ]]
	$rpc framework_set_scheduler dynamic
	[[ "$($rpc framework_get_scheduler | jq -r '. | select(.scheduler_name == "dynamic") | .core_limit')" -eq 42 ]]

	trap - SIGINT SIGTERM EXIT
	killprocess $spdk_pid
}

run_test "scheduler_opts" scheduler_opts
