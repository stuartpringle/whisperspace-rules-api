<?php

declare(strict_types=1);

header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
  http_response_code(204);
  exit;
}

function load_env(string $path): void {
  if (!file_exists($path)) return;
  $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
  if ($lines === false) return;
  foreach ($lines as $line) {
    $trim = trim($line);
    if ($trim === "" || str_starts_with($trim, "#")) continue;
    $parts = explode("=", $trim, 2);
    if (count($parts) !== 2) continue;
    $key = trim($parts[0]);
    $val = trim($parts[1]);
    if ($key === "") continue;
    if ((str_starts_with($val, '"') && str_ends_with($val, '"')) || (str_starts_with($val, "'") && str_ends_with($val, "'"))) {
      $val = substr($val, 1, -1);
    }
    putenv("$key=$val");
    $_ENV[$key] = $val;
  }
}

load_env("/hdd/sites/stuartpringle/whisperspace/.env");
load_env("/hdd/sites/stuartpringle/whisperspace/public/.env");
load_env("/hdd/sites/stuartpringle/whisperspace/public/character-api/.env");

function respond(int $code, $payload): void {
  http_response_code($code);
  echo json_encode($payload);
  exit;
}

function client_ip(): string {
  $headers = function_exists("getallheaders") ? getallheaders() : [];
  $ip = $headers["CF-Connecting-IP"] ?? $headers["cf-connecting-ip"] ?? null;
  if (!$ip) {
    $xff = $headers["X-Forwarded-For"] ?? $headers["x-forwarded-for"] ?? "";
    if (is_string($xff) && $xff !== "") {
      $parts = explode(",", $xff);
      $ip = trim($parts[0] ?? "");
    }
  }
  if (!$ip) $ip = $_SERVER["REMOTE_ADDR"] ?? "unknown";
  return (string)$ip;
}

function rate_limit(int $limit, int $windowSeconds): void {
  $dir = sys_get_temp_dir() . "/whisperspace_character_rate";
  if (!is_dir($dir)) {
    @mkdir($dir, 0755, true);
  }
  $ip = client_ip();
  $key = preg_replace("/[^a-zA-Z0-9_.-]/", "_", $ip);
  $file = $dir . "/" . $key . ".json";
  $now = time();
  $data = ["windowStart" => $now, "count" => 0];

  $fh = @fopen($file, "c+");
  if ($fh) {
    flock($fh, LOCK_EX);
    $raw = stream_get_contents($fh);
    if ($raw !== false && $raw !== "") {
      $decoded = json_decode($raw, true);
      if (is_array($decoded) && isset($decoded["windowStart"], $decoded["count"])) {
        $data = $decoded;
      }
    }
    if (($now - (int)$data["windowStart"]) >= $windowSeconds) {
      $data = ["windowStart" => $now, "count" => 0];
    }
    $data["count"] = (int)$data["count"] + 1;

    ftruncate($fh, 0);
    rewind($fh);
    fwrite($fh, json_encode($data));
    fflush($fh);
    flock($fh, LOCK_UN);
    fclose($fh);
  }

  $reset = (int)$data["windowStart"] + $windowSeconds;
  $remaining = max(0, $limit - (int)$data["count"]);
  header("X-RateLimit-Limit: {$limit}");
  header("X-RateLimit-Remaining: {$remaining}");
  header("X-RateLimit-Reset: {$reset}");

  if ((int)$data["count"] > $limit) {
    http_response_code(429);
    header("Retry-After: " . max(1, $reset - $now));
    echo json_encode(["error" => "rate_limited"]);
    exit;
  }
}

rate_limit(120, 60);

$expectedKey = getenv("WS_CHARACTER_API_KEY") ?: "";
if ($expectedKey !== "") {
  $headers = function_exists("getallheaders") ? getallheaders() : [];
  $authHeader = $headers["Authorization"] ?? $headers["authorization"] ?? "";
  $queryKey = $_GET["api_key"] ?? "";
  $token = "";
  if (is_string($authHeader) && stripos($authHeader, "Bearer ") === 0) {
    $token = trim(substr($authHeader, 7));
  } elseif (is_string($queryKey)) {
    $token = $queryKey;
  }
  if ($token !== $expectedKey) {
    respond(401, ["error" => "unauthorized"]);
  }
}

$uri = $_SERVER["REQUEST_URI"] ?? "/";
$path = parse_url($uri, PHP_URL_PATH);
$segments = array_values(array_filter(explode("/", trim($path, "/"))));
$idx = array_search("character-api", $segments, true);
$tail = $idx === false ? [] : array_slice($segments, $idx + 1);

function db_path(): string {
  $env = getenv("WS_CHARACTER_DB_PATH");
  if (is_string($env) && $env !== "") return $env;
  return __DIR__ . "/characters.sqlite";
}

function open_db(): PDO {
  $path = db_path();
  $pdo = new PDO("sqlite:" . $path);
  $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
  $pdo->exec("CREATE TABLE IF NOT EXISTS characters (id TEXT PRIMARY KEY, name TEXT, data TEXT, created_at TEXT, updated_at TEXT)");
  return $pdo;
}

function uuid4(): string {
  $data = random_bytes(16);
  $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
  $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
  return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function parse_body(): array {
  $raw = file_get_contents("php://input");
  $body = json_decode($raw ?: "{}", true);
  return is_array($body) ? $body : [];
}

function get_if_unmodified_since(): ?string {
  $headers = function_exists("getallheaders") ? getallheaders() : [];
  $val = $headers["If-Unmodified-Since"] ?? $headers["if-unmodified-since"] ?? null;
  if (!is_string($val) || $val === "") return null;
  return $val;
}

if (count($tail) === 0) {
  respond(200, [
    "status" => "ok",
    "endpoints" => [
      "GET /character-api/health",
      "GET /character-api/characters",
      "POST /character-api/characters",
      "GET /character-api/characters/:id",
      "PUT /character-api/characters/:id",
      "DELETE /character-api/characters/:id",
    ],
  ]);
}

if ($tail[0] === "health") {
  respond(200, ["ok" => true]);
}

if ($tail[0] === "admin") {
  if (!isset($tail[1]) || $tail[1] !== "characters") {
    respond(404, ["error" => "not_found"]);
  }

  $pdo = open_db();

  if ($_SERVER["REQUEST_METHOD"] === "GET") {
    $stmt = $pdo->query("SELECT id, name, created_at, updated_at FROM characters ORDER BY updated_at DESC");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respond(200, ["count" => count($rows), "items" => $rows ?: []]);
  }

  if ($_SERVER["REQUEST_METHOD"] === "DELETE") {
    $confirm = $_GET["confirm"] ?? "";
    if ($confirm !== "1" && $confirm !== "true") {
      respond(400, ["error" => "confirm_required", "message" => "Add ?confirm=1 to delete all characters."]);
    }
    $stmt = $pdo->query("SELECT COUNT(*) AS count FROM characters");
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $count = (int)($row["count"] ?? 0);
    $pdo->exec("DELETE FROM characters");
    respond(200, ["ok" => true, "deleted" => $count]);
  }

  respond(405, ["error" => "method_not_allowed"]);
}

if ($tail[0] !== "characters") {
  respond(404, ["error" => "not_found"]);
}

$pdo = open_db();

if (count($tail) === 1) {
  if ($_SERVER["REQUEST_METHOD"] === "GET") {
    $stmt = $pdo->query("SELECT id, name, updated_at FROM characters ORDER BY updated_at DESC");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respond(200, $rows ?: []);
  }

  if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $body = parse_body();
    $id = $body["id"] ?? uuid4();
    $name = $body["name"] ?? "";
    $now = gmdate("c");
    $body["id"] = $id;
    $body["createdAt"] = $body["createdAt"] ?? $now;
    $body["updatedAt"] = $body["updatedAt"] ?? $now;

    $stmt = $pdo->prepare("SELECT id FROM characters WHERE id = :id");
    $stmt->execute([":id" => $id]);
    if ($stmt->fetch()) {
      respond(409, ["error" => "conflict", "message" => "Character already exists" ]);
    }

    $stmt = $pdo->prepare("INSERT INTO characters (id, name, data, created_at, updated_at) VALUES (:id, :name, :data, :created_at, :updated_at)");
    $stmt->execute([
      ":id" => $id,
      ":name" => $name,
      ":data" => json_encode($body),
      ":created_at" => $body["createdAt"],
      ":updated_at" => $body["updatedAt"],
    ]);
    respond(201, $body);
  }

  respond(405, ["error" => "method_not_allowed"]);
}

$id = $tail[1] ?? "";
if ($id === "") {
  respond(400, ["error" => "missing_id"]);
}

if ($_SERVER["REQUEST_METHOD"] === "GET") {
  $stmt = $pdo->prepare("SELECT data FROM characters WHERE id = :id");
  $stmt->execute([":id" => $id]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);
  if (!$row) respond(404, ["error" => "not_found"]);
  respond(200, json_decode($row["data"], true));
}

if ($_SERVER["REQUEST_METHOD"] === "DELETE") {
  $stmt = $pdo->prepare("DELETE FROM characters WHERE id = :id");
  $stmt->execute([":id" => $id]);
  respond(200, ["ok" => true]);
}

if ($_SERVER["REQUEST_METHOD"] === "PUT") {
  $body = parse_body();
  if (($body["id"] ?? $id) !== $id) {
    respond(400, ["error" => "id_mismatch"]);
  }

  $stmt = $pdo->prepare("SELECT data, updated_at FROM characters WHERE id = :id");
  $stmt->execute([":id" => $id]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);

  $ifUnmod = get_if_unmodified_since();
  if ($row && $ifUnmod) {
    $remoteUpdated = strtotime($row["updated_at"]);
    $clientUpdated = strtotime($ifUnmod);
    if ($remoteUpdated && $clientUpdated && $remoteUpdated > $clientUpdated && !isset($_GET["force"])) {
      respond(409, [
        "error" => "conflict",
        "message" => "Remote has a newer version",
        "current" => json_decode($row["data"], true),
      ]);
    }
  }

  $now = gmdate("c");
  if (!$row) {
    $body["createdAt"] = $body["createdAt"] ?? $now;
  }
  $body["updatedAt"] = $now;
  $name = $body["name"] ?? "";

  if ($row) {
    $stmt = $pdo->prepare("UPDATE characters SET name = :name, data = :data, updated_at = :updated_at WHERE id = :id");
  } else {
    $stmt = $pdo->prepare("INSERT INTO characters (id, name, data, created_at, updated_at) VALUES (:id, :name, :data, :created_at, :updated_at)");
  }

  $stmt->execute([
    ":id" => $id,
    ":name" => $name,
    ":data" => json_encode($body),
    ":created_at" => $body["createdAt"] ?? $now,
    ":updated_at" => $body["updatedAt"],
  ]);

  respond(200, $body);
}

respond(405, ["error" => "method_not_allowed"]);
