#!/bin/bash
# Run Vera UI tests on a simulator.
# Usage: SIM=<udid> | DEVICE=<udid> TESTS="ClassName ClassName/testName" bash scripts/ui-tests.sh
SIM="${SIM:-4F25945B-2937-4297-8610-7780AC83CE70}"
RESULT=/tmp/claude_vera_uitest.xcresult
LOG=/tmp/claude_vera_uitest.log
cd "$(dirname "$0")/../Vera" || exit 1
rm -rf "$RESULT"
only=()
for t in ${TESTS:-}; do only+=("-only-testing:VeraUITests/$t"); done
[ ${#only[@]} -eq 0 ] && only=("-only-testing:VeraUITests")
if [ -n "${DEVICE:-}" ]; then dest="id=$DEVICE"; else dest="platform=iOS Simulator,id=$SIM"; fi
xcodebuild test -project Vera.xcodeproj -scheme Vera \
  -destination "$dest" "${only[@]}" \
  -resultBundlePath "$RESULT" -allowProvisioningUpdates >"$LOG" 2>&1
rc=$?
grep -E "Test Case .*(passed|failed)|error:|XCTAssert|TEST (SUCCEEDED|FAILED)|BUILD FAILED|Executed [0-9]+ test" "$LOG" | cut -c1-400 | head -40
echo "exit=$rc log=$LOG result=$RESULT"
