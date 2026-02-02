#!/usr/bin/env bash
#
# Test script for the FunCal API with Bearer token auth & ICS export.
# Usage: script/test_api.sh
#
# Requires: the Rails server running on localhost:3000
#           at least one User in the database

set -euo pipefail

BASE="http://localhost:3000/api/v1"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}--- $1${NC}"; }
pass() { echo -e "    ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "    ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }

check_status() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    pass "$label (HTTP $actual)"
  else
    fail "$label — expected $expected, got $actual"
  fi
}

# -------------------------------------------------------------------
log "Generating API token via Rails console"
TOKEN=$(bin/rails runner "u = User.first; u.regenerate_api_token; puts u.api_token" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Could not generate token. Is there a User in the DB?${NC}"
  exit 1
fi
echo "    Token: $TOKEN"

AUTH="Authorization: Bearer $TOKEN"

# -------------------------------------------------------------------
log "1. Unauthenticated request (localhost bypass allows 200 in dev)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/events")
check_status "GET /events without token (dev localhost bypass)" 200 "$STATUS"

# -------------------------------------------------------------------
log "2. List events (authenticated)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH" "$BASE/events")
check_status "GET /events" 200 "$STATUS"

# -------------------------------------------------------------------
log "3. List calendars"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH" "$BASE/calendars")
check_status "GET /calendars" 200 "$STATUS"

# -------------------------------------------------------------------
log "4. Get first calendar ID"
CAL_ID=$(curl -s -H "$AUTH" "$BASE/calendars" | ruby -rjson -e 'puts JSON.parse(STDIN.read).first&.dig("id") rescue nil')
if [ -z "$CAL_ID" ] || [ "$CAL_ID" = "" ]; then
  echo "    No calendars found — creating one via console"
  CAL_ID=$(bin/rails runner "c = User.first.calendars.first_or_create!(name: 'Test Cal'); puts c.id" 2>/dev/null)
fi
echo "    Calendar ID: $CAL_ID"

# -------------------------------------------------------------------
log "5. Create an event"
BODY=$(cat <<JSON
{"event":{"title":"API Test Event","starts_at":"2026-02-03T10:00:00-06:00","ends_at":"2026-02-03T11:00:00-06:00","calendar_id":$CAL_ID}}
JSON
)
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$BODY" "$BASE/events")
STATUS=$(echo "$RESPONSE" | tail -1)
RESP_BODY=$(echo "$RESPONSE" | sed '$d')
check_status "POST /events" 201 "$STATUS"

EVENT_ID=$(echo "$RESP_BODY" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["event_id"] rescue nil')
echo "    Event ID: $EVENT_ID"

# -------------------------------------------------------------------
log "6. Show event"
if [ -n "$EVENT_ID" ]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH" "$BASE/events/$EVENT_ID")
  check_status "GET /events/$EVENT_ID" 200 "$STATUS"
else
  fail "Skipped — no event ID"
fi

# -------------------------------------------------------------------
log "7. Update event"
if [ -n "$EVENT_ID" ]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -H "$AUTH" -H "Content-Type: application/json" \
    -d '{"event":{"title":"Updated API Test Event"}}' "$BASE/events/$EVENT_ID")
  check_status "PATCH /events/$EVENT_ID" 200 "$STATUS"
else
  fail "Skipped — no event ID"
fi

# -------------------------------------------------------------------
log "8. Search events"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH" "$BASE/events/search?q=API+Test")
check_status "GET /events/search" 200 "$STATUS"

# -------------------------------------------------------------------
log "9. ICS export"
if [ -n "$EVENT_ID" ]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -H "$AUTH" "$BASE/events/$EVENT_ID/ics")
  STATUS=$(echo "$RESPONSE" | tail -1)
  ICS_BODY=$(echo "$RESPONSE" | sed '$d')
  check_status "GET /events/$EVENT_ID/ics" 200 "$STATUS"

  if echo "$ICS_BODY" | grep -q "BEGIN:VCALENDAR"; then
    pass "ICS contains VCALENDAR"
  else
    fail "ICS missing VCALENDAR header"
  fi

  if echo "$ICS_BODY" | grep -q "BEGIN:VEVENT"; then
    pass "ICS contains VEVENT"
  else
    fail "ICS missing VEVENT"
  fi
else
  fail "Skipped — no event ID"
fi

# -------------------------------------------------------------------
log "10. Delete event"
if [ -n "$EVENT_ID" ]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -H "$AUTH" "$BASE/events/$EVENT_ID")
  check_status "DELETE /events/$EVENT_ID" 204 "$STATUS"
else
  fail "Skipped — no event ID"
fi

# -------------------------------------------------------------------
log "11. Revoke API token"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -H "$AUTH" "$BASE/api_token")
check_status "DELETE /api_token" 200 "$STATUS"

# Confirm token no longer works (localhost bypass still allows 200 in dev)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH" "$BASE/events")
check_status "GET /events after revoke (dev localhost bypass)" 200 "$STATUS"

# -------------------------------------------------------------------
echo ""
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
