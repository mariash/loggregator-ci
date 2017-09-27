#!/bin/bash

set -ex

function report_to_datadog {
    ruby -rdogapi -e "$(cat <<RUBY
ENV["DATADOG_API_KEY"].split(' ').each do |k|
  client = Dogapi::Client.new(k)

  metadata = {
    host: ENV["CF_API"],
    tags: [
      ENV["APP_NAME"],
    ],
  }

  client.emit_point("smoke_test.loggregator.msg_count", ENV["MSG_COUNT"], metadata)
  client.emit_point("smoke_test.loggregator.cycles", ENV["CYCLES"].to_i, metadata)

  delay_unit = ENV["DELAY_UNIT"]
  metadata[:tags] << "delay_unit:#{delay_unit}"
  client.emit_point("smoke_test.loggregator.delay", ENV["DELAY"].to_i, metadata)
end
RUBY
)"
}

export MSG_COUNT=0

trap report_to_datadog EXIT

# target api
cf login \
    -a "$CF_API" \
    -u "$USERNAME" \
    -p "$PASSWORD" \
    -s "$SPACE" \
    -o "$ORG" \
    --skip-ssl-validation # TODO: pass this in as a param

# cf logs to a file
rm -f output.txt
echo "Collecting logs for $APP_NAME"
cf logs "$APP_NAME" > output.txt 2>&1 &
sleep 30 # wait 30 seconds to establish connection

# curl my logspinner
echo "Triggering $APP_NAME"
curl "$APP_DOMAIN?cycles=$CYCLES&delay=$DELAY$DELAY_UNIT&text=$MESSAGE"

sleep "$WAIT" # wait for a bit to collect logs

MSG_COUNT=$(grep APP output.txt | grep -c "$MESSAGE")

# Trap will send metrics to datadog
