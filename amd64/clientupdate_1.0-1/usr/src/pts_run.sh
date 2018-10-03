#!/bin/bash
# phoronix-test-suite list-installed-suites
# phoronix-test-suite list-installed-tests
# phoronix-test-suite list-available-suites
# phoronix-test-suite list-available-tests

# phoronix-test-suite batch-setup

# phoronix-test-suite install pts/ffmpeg pts/stream pts/unpack-linux
phoronix-test-suite system-info
TEST_RESULTS_NAME="$(dmidecode -t 2 | grep Product | cut -d: -f2 | xargs) $(date +%Y-%m-%d_%H.%M.%S)" TEST_RESULTS_IDENTIFIER="$(dmidecode -t 2 | grep Product | cut -d: -f2 | xargs) $(dmidecode -t 2 | grep Tag | cut -d: -f2 | xargs)" TEST_RESULTS_DESCRIPTION="$(dmidecode -t 4 | grep Socket | cut -d: -f2 | xargs)" PRESET_OPTIONS="stream.run-type=Copy;" phoronix-test-suite benchmark pts/ffmpeg pts/stream pts/unpack-linux
