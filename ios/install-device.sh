#!/bin/bash
# Builds the Release app (talks to https://api.portermills.net) and installs it on a
# connected iPhone, signed with a free Apple ID's personal team. Free signing expires
# after 7 days, so run this again each week.
#
#   ios/install-device.sh [DEVICE-NAME-OR-UDID]
#
# The team ID comes from DEVELOPMENT_TEAM or ~/.portermills/ios-team. With no device
# given, it uses the only paired physical iPhone that's connected.
set -euo pipefail
cd "$(dirname "$0")"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

team=${DEVELOPMENT_TEAM:-$(cat ~/.portermills/ios-team 2>/dev/null || true)}
if [ -z "$team" ]; then
  echo "Set DEVELOPMENT_TEAM or put your team ID in ~/.portermills/ios-team" >&2
  exit 1
fi

devices_json=$(mktemp)
trap 'rm -f "$devices_json"' EXIT
xcrun devicectl list devices --quiet --json-output "$devices_json" >/dev/null

# Prints "UDID<TAB>name" for each paired, physical iOS device matching $1 (or all).
udid=$(python3 -I - "$devices_json" "${1:-}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
want = sys.argv[2]
found = []
for d in data.get("result", {}).get("devices", []):
    hw, conn, props = d.get("hardwareProperties", {}), d.get("connectionProperties", {}), d.get("deviceProperties", {})
    if hw.get("platform") != "iOS" or hw.get("reality") != "physical" or conn.get("pairingState") != "paired":
        continue
    udid, name = hw.get("udid", ""), props.get("name", "")
    if not want or want in (udid, name, d.get("identifier")):
        found.append((udid, name))
if len(found) != 1:
    what = "matching %r" % want if want else "connected"
    print("Expected one paired iPhone %s, found %d: %s" % (what, len(found), ", ".join(n for _, n in found) or "none"), file=sys.stderr)
    sys.exit(1)
print(found[0][0])
PY
)

echo "Building for $udid"
xcodegen -q
xcodebuild -project Portermills.xcodeproj -scheme Portermills -configuration Release \
  -destination "id=$udid" -derivedDataPath build/device \
  DEVELOPMENT_TEAM="$team" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -quiet build

app=build/device/Build/Products/Release-iphoneos/Portermills.app
xcrun devicectl device install app --device "$udid" "$app"
xcrun devicectl device process launch --device "$udid" app.portermills || \
  echo "Installed. If it won't open, turn on Developer Mode (Settings → Privacy & Security) and trust the developer (Settings → General → VPN & Device Management)."
