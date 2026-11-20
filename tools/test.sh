#!/bin/sh
# Headless checks: parse every script, then run the gameplay test suite.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/tools/dev-run.sh" --headless res://tests/check_scripts.tscn
# A hung run (an error that stops the suite before it quits) fails after
# VIBIVAL_TEST_TIMEOUT seconds instead of waiting forever.
timeout "${VIBIVAL_TEST_TIMEOUT:-1800}" "$ROOT/tools/dev-run.sh" --headless res://tests/run_tests.tscn
