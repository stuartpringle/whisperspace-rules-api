#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${WS_CHARACTER_TEST_PORT:-}"
BASE_URL=""
TMP_DB="$(mktemp /tmp/ws-character-api-test-XXXXXX.sqlite)"
SERVER_LOG="$(mktemp /tmp/ws-character-api-server-XXXXXX.log)"
JAR_ONE="$(mktemp /tmp/ws-character-api-jar1-XXXXXX.txt)"
JAR_TWO="$(mktemp /tmp/ws-character-api-jar2-XXXXXX.txt)"

SERVER_PID=""
cleanup() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
  rm -f "${TMP_DB}" "${SERVER_LOG}" "${JAR_ONE}" "${JAR_TWO}"
}
trap cleanup EXIT

start_server() {
  local tries=0
  while (( tries < 20 )); do
    if [[ -z "${PORT}" ]]; then
      PORT="$(( (RANDOM % 20000) + 20000 ))"
    fi
    BASE_URL="http://127.0.0.1:${PORT}/character-api"
    : >"${SERVER_LOG}"
    (
      cd "${ROOT_DIR}"
      WS_CHARACTER_DB_DRIVER=sqlite \
        WS_CHARACTER_DB_PATH="${TMP_DB}" \
        php -S "127.0.0.1:${PORT}" -t public
    ) >"${SERVER_LOG}" 2>&1 &
    SERVER_PID="$!"
    sleep 0.15
    if kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
      if ! grep -q "Failed to listen" "${SERVER_LOG}"; then
        return
      fi
    fi
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
    SERVER_PID=""
    if [[ -n "${WS_CHARACTER_TEST_PORT:-}" ]]; then
      echo "Configured port ${PORT} is unavailable. Log:" >&2
      cat "${SERVER_LOG}" >&2
      exit 1
    fi
    PORT=""
    tries=$((tries + 1))
  done
  echo "Unable to find an available local port for test server." >&2
  exit 1
}

wait_for_server() {
  local attempts=0
  until curl -sS "${BASE_URL}/health" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if (( attempts > 50 )); then
      echo "Server failed to start. Log:" >&2
      cat "${SERVER_LOG}" >&2
      exit 1
    fi
    sleep 0.1
  done
}

json_get() {
  local path="$1"
  php -r '$p=$argv[1]; $j=json_decode(stream_get_contents(STDIN), true); if(!is_array($j)){fwrite(STDERR, "invalid_json\n"); exit(1);} $cur=$j; foreach(explode(".", $p) as $k){ if(!is_array($cur) || !array_key_exists($k, $cur)){fwrite(STDERR, "missing_json_path\n"); exit(1);} $cur=$cur[$k]; } if(is_array($cur)){echo json_encode($cur);} else {echo $cur;}' "${path}"
}

json_count() {
  php -r '$j=json_decode(stream_get_contents(STDIN), true); if(!is_array($j)){fwrite(STDERR, "invalid_json_array\n"); exit(1);} echo count($j);'
}

json_has_name() {
  local expected="$1"
  php -r '$needle=$argv[1]; $j=json_decode(stream_get_contents(STDIN), true); if(!is_array($j)){fwrite(STDERR, "invalid_json_array\n"); exit(1);} foreach($j as $row){ if(is_array($row) && ($row["name"] ?? "") === $needle){ echo "1"; exit(0);} } echo "0";' "${expected}"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Assertion failed: ${message} (expected=${expected}, actual=${actual})" >&2
    exit 1
  fi
}

start_server
wait_for_server

signup_one="$(curl -sS -X POST "${BASE_URL}/auth/signup" -H "Content-Type: application/json" -c "${JAR_ONE}" -b "${JAR_ONE}" --data '{"email":"owner@example.com","password":"Passw0rd!123"}')"
owner_id="$(printf '%s' "${signup_one}" | json_get "user.id")"

signup_two="$(curl -sS -X POST "${BASE_URL}/auth/signup" -H "Content-Type: application/json" -c "${JAR_TWO}" -b "${JAR_TWO}" --data '{"email":"other@example.com","password":"Passw0rd!123"}')"
other_id="$(printf '%s' "${signup_two}" | json_get "user.id")"

php -r '
$db = new PDO("sqlite:" . $argv[1]);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$stmt = $db->prepare("INSERT INTO characters (id, name, data, created_at, updated_at, owner_user_id, visibility) VALUES (:id, :name, :data, :created, :updated, :owner, :visibility)");
$now = gmdate("c");
$stmt->execute([
  ":id" => "char-owner-private",
  ":name" => "Owner Private Character",
  ":data" => json_encode(["id" => "char-owner-private", "name" => "Owner Private Character"], JSON_UNESCAPED_SLASHES),
  ":created" => $now,
  ":updated" => $now,
  ":owner" => $argv[2],
  ":visibility" => "private",
]);
$stmt->execute([
  ":id" => "char-owner-public",
  ":name" => "Owner Public Character",
  ":data" => json_encode(["id" => "char-owner-public", "name" => "Owner Public Character"], JSON_UNESCAPED_SLASHES),
  ":created" => $now,
  ":updated" => $now,
  ":owner" => $argv[2],
  ":visibility" => "public",
]);
$stmt->execute([
  ":id" => "char-other-private",
  ":name" => "Other Private Character",
  ":data" => json_encode(["id" => "char-other-private", "name" => "Other Private Character"], JSON_UNESCAPED_SLASHES),
  ":created" => $now,
  ":updated" => $now,
  ":owner" => $argv[3],
  ":visibility" => "private",
]);
' "${TMP_DB}" "${owner_id}" "${other_id}"

owner_list="$(curl -sS "${BASE_URL}/characters" -c "${JAR_ONE}" -b "${JAR_ONE}")"
other_list="$(curl -sS "${BASE_URL}/characters" -c "${JAR_TWO}" -b "${JAR_TWO}")"
anon_status="$(curl -sS -o /tmp/ws-character-api-anon-body.json -w "%{http_code}" "${BASE_URL}/characters")"
anon_body="$(cat /tmp/ws-character-api-anon-body.json)"
rm -f /tmp/ws-character-api-anon-body.json

assert_eq "$(printf '%s' "${owner_list}" | json_count)" "2" "owner should see only own characters"
assert_eq "$(printf '%s' "${owner_list}" | json_has_name "Owner Private Character")" "1" "owner private character should be listed"
assert_eq "$(printf '%s' "${owner_list}" | json_has_name "Owner Public Character")" "1" "owner public character should be listed"
assert_eq "$(printf '%s' "${owner_list}" | json_has_name "Other Private Character")" "0" "owner should not see other user's private character"

assert_eq "$(printf '%s' "${other_list}" | json_count)" "1" "other user should see only their own characters"
assert_eq "$(printf '%s' "${other_list}" | json_has_name "Other Private Character")" "1" "other private character should be listed for owner"
assert_eq "$(printf '%s' "${other_list}" | json_has_name "Owner Private Character")" "0" "other user should never see owner private character"
assert_eq "$(printf '%s' "${other_list}" | json_has_name "Owner Public Character")" "0" "other user should not see owner public character in /characters"

assert_eq "${anon_status}" "401" "anonymous list call should be rejected"
assert_eq "$(printf '%s' "${anon_body}" | json_get "error")" "unauthenticated" "anonymous list error code"

echo "character ownership regression test passed"
