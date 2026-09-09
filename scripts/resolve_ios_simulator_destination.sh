#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${IOS_SIMULATOR_DESTINATION:-}" ]]; then
  echo "$IOS_SIMULATOR_DESTINATION"
  exit 0
fi

PREFERRED_NAME="${IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_UDID="$(
  xcrun simctl list devices available -j | ruby -rjson -e '
    preferred_name = ARGV.fetch(0)
    data = JSON.parse(STDIN.read)
    devices = data.fetch("devices", {}).values.flatten.select do |device|
      device["isAvailable"] && device.fetch("deviceTypeIdentifier", "").include?("iPhone")
    end
    preferred = devices.select { |device| device["name"] == preferred_name }
    candidate = preferred.select { |device| device["state"] == "Booted" }
                         .sort_by { |device| device.fetch("udid", "") }
                         .first
    candidate ||= preferred.sort_by { |device| device.fetch("udid", "") }.first
    candidate ||= devices.select { |device| device["state"] == "Booted" }
                        .sort_by { |device| device.fetch("udid", "") }
                        .first
    candidate ||= devices.sort_by { |device| device.fetch("udid", "") }.first
    puts candidate.fetch("udid", "") if candidate
  ' "$PREFERRED_NAME"
)"

if [[ -z "$SIMULATOR_UDID" ]]; then
  echo "No available iPhone simulator found. Set IOS_SIMULATOR_DESTINATION explicitly." >&2
  exit 1
fi

echo "platform=iOS Simulator,id=$SIMULATOR_UDID"
