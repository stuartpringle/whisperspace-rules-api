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

load_env("/hdd/sites/stuartpringle/whisperspace-rules-api/.env");

function respond(int $code, $payload): void {
  http_response_code($code);
  echo json_encode($payload, JSON_UNESCAPED_SLASHES);
  exit;
}

function respond_error(int $code, string $error, array $details = []): void {
  $body = ["error" => $error];
  if ($details) $body["details"] = $details;
  respond($code, $body);
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

function get_provided_api_key(): string {
  $headers = function_exists("getallheaders") ? getallheaders() : [];
  $authHeader = $headers["Authorization"] ?? $headers["authorization"] ?? "";
  if (is_string($authHeader) && stripos($authHeader, "Bearer ") === 0) {
    return trim(substr($authHeader, 7));
  }
  $queryKey = $_GET["api_key"] ?? "";
  if (is_string($queryKey)) return trim($queryKey);
  return "";
}

$masterApiKey = getenv("WS_CHARACTER_API_KEY") ?: "";
$providedApiKey = get_provided_api_key();
$hasValidApiKey = $masterApiKey !== "" && $providedApiKey !== "" && hash_equals($masterApiKey, $providedApiKey);

function db_driver(): string {
  $env = getenv("WS_CHARACTER_DB_DRIVER");
  if (is_string($env) && $env !== "") return strtolower($env);
  $env = getenv("DB_CONNECTION");
  if (is_string($env) && $env !== "") return strtolower($env);
  return "sqlite";
}

function is_mysql_driver(string $driver): bool {
  return $driver === "mysql" || $driver === "mariadb";
}

function db_path(): string {
  $env = getenv("WS_CHARACTER_DB_PATH");
  if (is_string($env) && $env !== "") return $env;
  return "/hdd/sites/stuartpringle/whisperspace-character-builder/db/characters.sqlite";
}

function open_db(): PDO {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $host = getenv("DB_HOST") ?: "127.0.0.1";
    $port = getenv("DB_PORT") ?: "3306";
    $socket = getenv("DB_SOCKET") ?: "";
    $db = getenv("DB_DATABASE") ?: "";
    $user = getenv("DB_USERNAME") ?: "";
    $pass = getenv("DB_PASSWORD") ?: "";
    if ($db === "" || $user === "") {
      respond_error(500, "db_config_missing");
    }
    $dsn = $socket !== ""
      ? "mysql:unix_socket={$socket};dbname={$db};charset=utf8mb4"
      : "mysql:host={$host};port={$port};dbname={$db};charset=utf8mb4";
    $pdo = new PDO($dsn, $user, $pass, [
      PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
      PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
      PDO::ATTR_EMULATE_PREPARES => false,
    ]);
  } else {
    $path = db_path();
    $pdo = new PDO("sqlite:" . $path);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
  }
  create_characters_table($pdo, $driver);
  apply_migrations($pdo);
  return $pdo;
}

function create_characters_table(PDO $pdo, string $driver): void {
  if (is_mysql_driver($driver)) {
    $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS `characters` (
  `id` VARCHAR(36) PRIMARY KEY,
  `name` TEXT,
  `data` LONGTEXT,
  `created_at` TEXT,
  `updated_at` TEXT,
  `owner_user_id` VARCHAR(36),
  `visibility` VARCHAR(16) NOT NULL DEFAULT 'private'
)
SQL
);
    return;
  }
  $pdo->exec("CREATE TABLE IF NOT EXISTS characters (id TEXT PRIMARY KEY, name TEXT, data TEXT, created_at TEXT, updated_at TEXT)");
}

function apply_migrations(PDO $pdo): void {
  ensure_characters_columns($pdo);
  ensure_users_table($pdo);
  ensure_user_sessions_table($pdo);
  ensure_password_resets_table($pdo);
  ensure_oauth_accounts_table($pdo);
}

function column_exists(PDO $pdo, string $table, string $column): bool {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $stmt = $pdo->prepare(<<<'SQL'
SELECT COUNT(*) AS count
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = :table
  AND COLUMN_NAME = :column
SQL
    );
    $stmt->execute([
      ":table" => $table,
      ":column" => $column,
    ]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return (int)($row["count"] ?? 0) > 0;
  }
  $stmt = $pdo->query("PRAGMA table_info('" . str_replace("'", "''", $table) . "')");
  $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
  foreach ($rows as $row) {
    if (($row["name"] ?? "") === $column) return true;
  }
  return false;
}

function index_exists(PDO $pdo, string $table, string $index): bool {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $stmt = $pdo->prepare(<<<'SQL'
SELECT COUNT(*) AS count
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = :table
  AND INDEX_NAME = :index
SQL
    );
    $stmt->execute([
      ":table" => $table,
      ":index" => $index,
    ]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return (int)($row["count"] ?? 0) > 0;
  }
  $stmt = $pdo->query("PRAGMA index_list('" . str_replace("'", "''", $table) . "')");
  $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
  foreach ($rows as $row) {
    if (($row["name"] ?? "") === $index) return true;
  }
  return false;
}

function create_index_if_missing(PDO $pdo, string $table, string $index, string $columns): void {
  if (index_exists($pdo, $table, $index)) return;
  $pdo->exec("CREATE INDEX {$index} ON {$table}({$columns})");
}

function ensure_characters_columns(PDO $pdo): void {
  if (!column_exists($pdo, "characters", "owner_user_id")) {
    $pdo->exec("ALTER TABLE characters ADD COLUMN owner_user_id TEXT");
  }
  if (!column_exists($pdo, "characters", "visibility")) {
    $pdo->exec("ALTER TABLE characters ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private'");
  }
  $pdo->exec("UPDATE characters SET visibility = 'public' WHERE owner_user_id IS NULL");
}

function ensure_users_table(PDO $pdo): void {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(36) PRIMARY KEY,
  `email` VARCHAR(320) UNIQUE NOT NULL,
  `password_hash` VARCHAR(255),
  `is_admin` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TEXT NOT NULL,
  `updated_at` TEXT NOT NULL
)
SQL
);
    return;
  }
  $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  is_admin INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
SQL
);
}

function ensure_user_sessions_table(PDO $pdo): void {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS `user_sessions` (
  `id` VARCHAR(36) PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `token_hash` CHAR(64) NOT NULL,
  `created_at` TEXT NOT NULL,
  `expires_at` TEXT NOT NULL,
  `revoked_at` TEXT,
  `ip` VARCHAR(64),
  `user_agent` TEXT,
  FOREIGN KEY(`user_id`) REFERENCES `users`(`id`)
)
SQL
);
    create_index_if_missing($pdo, "user_sessions", "idx_user_sessions_token", "token_hash");
    return;
  }
  $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS user_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  ip TEXT,
  user_agent TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id)
)
SQL
);
  create_index_if_missing($pdo, "user_sessions", "idx_user_sessions_token", "token_hash");
}

function ensure_password_resets_table(PDO $pdo): void {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS `password_resets` (
  `id` VARCHAR(36) PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `token_hash` CHAR(64) NOT NULL,
  `created_at` TEXT NOT NULL,
  `expires_at` TEXT NOT NULL,
  `used_at` TEXT,
  FOREIGN KEY(`user_id`) REFERENCES `users`(`id`)
)
SQL
);
    create_index_if_missing($pdo, "password_resets", "idx_password_resets_token", "token_hash");
    return;
  }
  $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS password_resets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id)
)
SQL
);
  create_index_if_missing($pdo, "password_resets", "idx_password_resets_token", "token_hash");
}

function ensure_oauth_accounts_table(PDO $pdo): void {
  $driver = db_driver();
  if (is_mysql_driver($driver)) {
    $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS `oauth_accounts` (
  `id` VARCHAR(36) PRIMARY KEY,
  `provider` VARCHAR(64) NOT NULL,
  `provider_user_id` VARCHAR(255) NOT NULL,
  `owner_user_id` VARCHAR(36),
  `created_at` TEXT NOT NULL,
  `updated_at` TEXT NOT NULL,
  UNIQUE(`provider`, `provider_user_id`),
  FOREIGN KEY(`owner_user_id`) REFERENCES `users`(`id`)
)
SQL
);
    return;
  }
  $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS oauth_accounts (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  provider_user_id TEXT NOT NULL,
  owner_user_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(provider, provider_user_id),
  FOREIGN KEY(owner_user_id) REFERENCES users(id)
)
SQL
);
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

function schema_path(): string {
  $env = getenv("WS_CHARACTER_SCHEMA_PATH");
  if (is_string($env) && $env !== "") return $env;
  return "/hdd/sites/stuartpringle/whisperspace-sdk/schema/character-record.v1.json";
}

function load_schema(): array {
  $path = schema_path();
  if (!file_exists($path)) return [];
  $raw = file_get_contents($path);
  $decoded = json_decode($raw ?: "{}", true);
  return is_array($decoded) ? $decoded : [];
}

function validate_value($value, array $schema, string $path, array &$errors): void {
  $type = $schema["type"] ?? null;
  if ($type === "object") {
    if (!is_array($value) || (array_is_list($value) && $value !== [])) {
      $errors[] = ($path === "" ? "value" : $path) . " must be an object";
      return;
    }
    $required = $schema["required"] ?? [];
    if (is_array($required)) {
      foreach ($required as $key) {
        if (!array_key_exists($key, $value)) $errors[] = ($path === "" ? $key : "$path.$key") . " is required";
      }
    }
    $properties = $schema["properties"] ?? [];
    $additional = $schema["additionalProperties"] ?? true;
    foreach ($value as $key => $val) {
      if (is_array($properties) && array_key_exists($key, $properties)) {
        $sub = $properties[$key];
        if (is_array($sub)) {
          validate_value($val, $sub, $path === "" ? $key : "$path.$key", $errors);
        }
      } elseif ($additional === false) {
        $errors[] = ($path === "" ? $key : "$path.$key") . " is not allowed";
      }
    }
    return;
  }

  if ($type === "array") {
    if (!is_array($value) || !array_is_list($value)) {
      $errors[] = ($path === "" ? "value" : $path) . " must be an array";
      return;
    }
    $items = $schema["items"] ?? [];
    if (is_array($items)) {
      foreach ($value as $idx => $item) {
        validate_value($item, $items, ($path === "" ? "items" : "$path[$idx]"), $errors);
      }
    }
    return;
  }

  if ($type === "string" && !is_string($value)) {
    $errors[] = ($path === "" ? "value" : $path) . " must be a string";
    return;
  }

  if ($type === "number" && !is_numeric($value)) {
    $errors[] = ($path === "" ? "value" : $path) . " must be a number";
    return;
  }

  if (isset($schema["enum"]) && is_array($schema["enum"])) {
    if (!in_array($value, $schema["enum"], true)) {
      $errors[] = ($path === "" ? "value" : $path) . " must be one of: " . implode(", ", $schema["enum"]);
    }
  }
}

function validate_record(array $body): array {
  $schema = load_schema();
  if ($schema === []) return ["schema_unavailable"];
  $errors = [];
  validate_value($body, $schema, "", $errors);
  return $errors;
}

function normalize_record(array $record): array {
  if (array_key_exists("skills", $record) && is_array($record["skills"]) && array_is_list($record["skills"]) && $record["skills"] === []) {
    $record["skills"] = (object)[];
  }
  return $record;
}

const SESSION_COOKIE = "ws_session";
const CSRF_COOKIE = "ws_csrf";
const CSRF_HEADER = "X-CSRF-Token";
const SESSION_TTL = 2592000;

function is_secure_request(): bool {
  if (!empty($_SERVER["HTTPS"])) return strtolower($_SERVER["HTTPS"]) !== "off";
  $proto = $_SERVER["HTTP_X_FORWARDED_PROTO"] ?? $_SERVER["HTTP_X_FORWARDED_SSL"] ?? "";
  return strtolower($proto) === "https";
}

function cookie_options(): array {
  $domain = getenv("WS_COOKIE_DOMAIN");
  $opts = [
    "expires" => time() + SESSION_TTL,
    "path" => "/",
    "samesite" => "Lax",
  ];
  if ($domain !== false && $domain !== "") $opts["domain"] = $domain;
  if (is_secure_request()) $opts["secure"] = true;
  return $opts;
}

function set_session_cookies(string $token, string $csrfToken): void {
  $opts = cookie_options();
  $optsHttpOnly = $opts;
  $optsHttpOnly["httponly"] = true;
  setcookie(SESSION_COOKIE, $token, $optsHttpOnly);
  $opts["httponly"] = false;
  setcookie(CSRF_COOKIE, $csrfToken, $opts);
}

function clear_session_cookies(): void {
  $opts = [
    "expires" => time() - 3600,
    "path" => "/",
    "samesite" => "Lax",
  ];
  $domain = getenv("WS_COOKIE_DOMAIN");
  if ($domain !== false && $domain !== "") $opts["domain"] = $domain;
  if (is_secure_request()) $opts["secure"] = true;
  $opts["httponly"] = true;
  setcookie(SESSION_COOKIE, "", $opts);
  $opts["httponly"] = false;
  setcookie(CSRF_COOKIE, "", $opts);
}

function create_token(int $bytes = 32): string {
  return bin2hex(random_bytes($bytes));
}

function hash_token(string $token): string {
  return hash("sha256", $token);
}

function get_csrf_header_value(): string {
  $headers = [];
  foreach ($_SERVER as $key => $value) {
    if (str_starts_with($key, "HTTP_")) {
      $normalized = str_replace("HTTP_", "", $key);
      $headers[strtolower($normalized)] = $value;
    }
  }
  return $headers[strtolower(str_replace("-", "_", CSRF_HEADER))] ?? ($headers[strtolower(CSRF_HEADER)] ?? "");
}

function require_csrf(): void {
  $cookie = $_COOKIE[CSRF_COOKIE] ?? "";
  $header = get_csrf_header_value();
  if ($cookie === "" || $header === "" || !hash_equals($cookie, $header)) {
    respond_error(403, "csrf_mismatch");
  }
}

function current_csrf_token(): string {
  return (string)($_COOKIE[CSRF_COOKIE] ?? "");
}

function current_user(PDO $pdo): ?array {
  static $cached = null;
  if ($cached !== null) return $cached;
  $token = $_COOKIE[SESSION_COOKIE] ?? "";
  if ($token === "") return $cached = null;
  $hash = hash_token($token);
  $stmt = $pdo->prepare(<<<'SQL'
SELECT us.id AS session_id, us.user_id, us.revoked_at, us.expires_at, u.email, u.is_admin
FROM user_sessions us
JOIN users u ON u.id = us.user_id
WHERE us.token_hash = :hash
SQL
  );
  $stmt->execute([":hash" => $hash]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);
  if (!$row) return $cached = null;
  if ($row["revoked_at"] !== null) return $cached = null;
  $expires = strtotime($row["expires_at"] ?? "");
  if ($expires && time() > $expires) return $cached = null;
  $cached = [
    "session_id" => $row["session_id"],
    "id" => $row["user_id"],
    "email" => $row["email"],
    "is_admin" => (bool)$row["is_admin"],
  ];
  return $cached;
}

function require_auth(PDO $pdo): array {
  $user = current_user($pdo);
  if (!$user) {
    respond_error(401, "unauthenticated");
  }
  return $user;
}

function require_admin(PDO $pdo, bool $hasValidApiKey): array {
  $user = current_user($pdo);
  if ($hasValidApiKey) return $user ?: ["is_admin" => true];
  if ($user && $user["is_admin"]) return $user;
  respond_error(403, "admin_required");
}

function issue_session(PDO $pdo, string $userId): void {
  $token = create_token(32);
  $csrfToken = create_token(24);
  $hash = hash_token($token);
  $now = gmdate("c");
  $expiresAt = gmdate("c", time() + SESSION_TTL);
  $stmt = $pdo->prepare(<<<'SQL'
INSERT INTO user_sessions (id, user_id, token_hash, created_at, expires_at, ip, user_agent)
VALUES (:id, :user_id, :token_hash, :created_at, :expires_at, :ip, :user_agent)
SQL
  );
  $stmt->execute([
    ":id" => uuid4(),
    ":user_id" => $userId,
    ":token_hash" => $hash,
    ":created_at" => $now,
    ":expires_at" => $expiresAt,
    ":ip" => client_ip(),
    ":user_agent" => $_SERVER["HTTP_USER_AGENT"] ?? "",
  ]);
  set_session_cookies($token, $csrfToken);
}

function revoke_session(PDO $pdo, string $sessionId): void {
  $stmt = $pdo->prepare("UPDATE user_sessions SET revoked_at = :revoked WHERE id = :id");
  $stmt->execute([
    ":revoked" => gmdate("c"),
    ":id" => $sessionId,
  ]);
}

function revoke_all_user_sessions(PDO $pdo, string $userId): void {
  $stmt = $pdo->prepare("UPDATE user_sessions SET revoked_at = :revoked WHERE user_id = :user_id");
  $stmt->execute([
    ":revoked" => gmdate("c"),
    ":user_id" => $userId,
  ]);
}

function find_user_by_email(PDO $pdo, string $email): ?array {
  $stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email LIMIT 1");
  $stmt->execute([":email" => strtolower($email)]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);
  return $row ?: null;
}

function create_user(PDO $pdo, string $email, string $passwordHash): array {
  $now = gmdate("c");
  $id = uuid4();
  $stmt = $pdo->prepare(<<<'SQL'
INSERT INTO users (id, email, password_hash, is_admin, created_at, updated_at)
VALUES (:id, :email, :password_hash, 0, :created_at, :updated_at)
SQL
  );
  $stmt->execute([
    ":id" => $id,
    ":email" => strtolower($email),
    ":password_hash" => $passwordHash,
    ":created_at" => $now,
    ":updated_at" => $now,
  ]);
  return ["id" => $id, "email" => strtolower($email)];
}

function send_postmark_email(array $payload): bool {
  $token = getenv("POSTMARK_SERVER_TOKEN");
  if (!$token) return false;
  if (function_exists("curl_init")) {
    $ch = curl_init("https://api.postmarkapp.com/email");
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
      "Accept: application/json",
      "Content-Type: application/json",
      "X-Postmark-Server-Token: $token",
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    $response = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_errno($ch);
    curl_close($ch);
    return $err === 0 && $code >= 200 && $code < 300;
  }
  $context = stream_context_create([
    "http" => [
      "method" => "POST",
      "header" => "Accept: application/json\r\nContent-Type: application/json\r\nX-Postmark-Server-Token: $token\r\n",
      "content" => json_encode($payload),
      "timeout" => 5,
    ],
  ]);
  $response = @file_get_contents("https://api.postmarkapp.com/email", false, $context);
  if ($response === false) return false;
  if (isset($http_response_header)) {
    foreach ($http_response_header as $header) {
      if (str_starts_with(strtolower($header), "http/")) {
        $parts = explode(" ", $header, 3);
        $code = (int)($parts[1] ?? 0);
        return $code >= 200 && $code < 300;
      }
    }
  }
  return false;
}

function send_password_reset_email(string $email, string $token): bool {
  $from = getenv("MAIL_FROM");
  $app = getenv("MAIL_APP_NAME") ?: "Whisperspace";
  $reply = getenv("MAIL_REPLY_TO");
  $builderUrl = rtrim(getenv("WS_BUILDER_URL") ?: "https://builder.whisperspace.com", "/");
  if (!$from) return false;
  $resetUrl = $builderUrl . "/reset?token=" . urlencode($token);
  $payload = [
    "From" => $from,
    "To" => $email,
    "Subject" => "$app password reset",
    "HtmlBody" => "<p>We received a request to reset your $app password. <a href=\"$resetUrl\">Click here</a> to reset it.</p>",
    "TextBody" => "Reset your password: $resetUrl",
  ];
  if ($reply) $payload["ReplyTo"] = $reply;
  return send_postmark_email($payload);
}

function create_password_reset(PDO $pdo, string $userId, string $token): void {
  $stmt = $pdo->prepare(<<<'SQL'
INSERT INTO password_resets (id, user_id, token_hash, created_at, expires_at)
VALUES (:id, :user_id, :token_hash, :created_at, :expires_at)
SQL
  );
  $now = gmdate("c");
  $expiresAt = gmdate("c", time() + 3600);
  $stmt->execute([
    ":id" => uuid4(),
    ":user_id" => $userId,
    ":token_hash" => hash_token($token),
    ":created_at" => $now,
    ":expires_at" => $expiresAt,
  ]);
}

function consume_password_reset(PDO $pdo, string $token): ?array {
  $hash = hash_token($token);
  $stmt = $pdo->prepare("SELECT * FROM password_resets WHERE token_hash = :hash LIMIT 1");
  $stmt->execute([
    ":hash" => $hash,
  ]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);
  if (!$row) return null;
  if ($row["used_at"] !== null) return null;
  $expires = strtotime($row["expires_at"] ?? "");
  if ($expires && $expires < time()) return null;
  $stmt = $pdo->prepare("UPDATE password_resets SET used_at = :used WHERE id = :id");
  $stmt->execute([
    ":used" => gmdate("c"),
    ":id" => $row["id"],
  ]);
  return $row;
}

function google_oauth_discovery_url(string $state): string {
  $clientId = getenv("WS_OAUTH_GOOGLE_CLIENT_ID");
  $redirect = getenv("WS_OAUTH_GOOGLE_REDIRECT_URI");
  if (!$clientId || !$redirect) return "";
  $params = [
    "client_id" => $clientId,
    "redirect_uri" => $redirect,
    "response_type" => "code",
    "scope" => "openid email",
    "access_type" => "offline",
    "include_granted_scopes" => "true",
  ];
  if ($state !== "") $params["state"] = $state;
  return "https://accounts.google.com/o/oauth2/v2/auth?" . http_build_query($params);
}

function fetch_google_tokens(string $code): ?array {
  $clientId = getenv("WS_OAUTH_GOOGLE_CLIENT_ID");
  $clientSecret = getenv("WS_OAUTH_GOOGLE_CLIENT_SECRET");
  $redirect = getenv("WS_OAUTH_GOOGLE_REDIRECT_URI");
  if (!$clientId || !$clientSecret || !$redirect) return null;
  $payload = [
    "code" => $code,
    "client_id" => $clientId,
    "client_secret" => $clientSecret,
    "redirect_uri" => $redirect,
    "grant_type" => "authorization_code",
  ];
  $context = stream_context_create([
    "http" => [
      "method" => "POST",
      "header" => "Content-Type: application/x-www-form-urlencoded\r\n",
      "content" => http_build_query($payload),
      "timeout" => 5,
    ],
  ]);
  $response = @file_get_contents("https://oauth2.googleapis.com/token", false, $context);
  if ($response === false) return null;
  $decoded = json_decode($response, true);
  return is_array($decoded) ? $decoded : null;
}

function fetch_google_profile(string $accessToken): ?array {
  $context = stream_context_create([
    "http" => [
      "method" => "GET",
      "header" => "Authorization: Bearer $accessToken\r\n",
      "timeout" => 5,
    ],
  ]);
  $response = @file_get_contents("https://openidconnect.googleapis.com/v1/userinfo", false, $context);
  if ($response === false) return null;
  $decoded = json_decode($response, true);
  return is_array($decoded) ? $decoded : null;
}

function normalize_return_url(string $value): string {
  $fallback = rtrim(getenv("WS_BUILDER_URL") ?: "https://builder.whisperspace.com", "/");
  if ($value === "") return $fallback;
  $parsed = parse_url($value);
  if (!$parsed) return $fallback;
  $host = $parsed["host"] ?? "";
  $builderHost = parse_url($fallback, PHP_URL_HOST);
  if ($host === $builderHost) return $value;
  return $fallback;
}

function find_or_create_user_for_google(PDO $pdo, array $profile): ?array {
  $driver = db_driver();
  $provider = "google";
  $providerId = $profile["sub"] ?? $profile["id"] ?? null;
  $email = $profile["email"] ?? null;
  if (!$providerId || !$email) return null;
  $stmt = $pdo->prepare("SELECT owner_user_id FROM oauth_accounts WHERE provider = :provider AND provider_user_id = :pid LIMIT 1");
  $stmt->execute([
    ":provider" => $provider,
    ":pid" => $providerId,
  ]);
  $link = $stmt->fetch(PDO::FETCH_ASSOC);
  if ($link && $link["owner_user_id"]) {
    $stmt = $pdo->prepare("SELECT id, email, is_admin FROM users WHERE id = :id LIMIT 1");
    $stmt->execute([
      ":id" => $link["owner_user_id"],
    ]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($user) return $user;
  }
  $user = find_user_by_email($pdo, $email);
  if (!$user) {
    $now = gmdate("c");
    $id = uuid4();
    $stmt = $pdo->prepare("INSERT INTO users (id, email, created_at, updated_at) VALUES (:id, :email, :created_at, :updated_at)");
    $stmt->execute([
      ":id" => $id,
      ":email" => strtolower($email),
      ":created_at" => $now,
      ":updated_at" => $now,
    ]);
    $user = ["id" => $id, "email" => strtolower($email), "is_admin" => 0];
  }
  $now = gmdate("c");
  if (is_mysql_driver($driver)) {
    $stmt = $pdo->prepare(<<<'SQL'
INSERT INTO oauth_accounts (id, provider, provider_user_id, owner_user_id, created_at, updated_at)
VALUES (:id, :provider, :pid, :owner, :created, :updated)
ON DUPLICATE KEY UPDATE
  owner_user_id = VALUES(owner_user_id),
  updated_at = VALUES(updated_at)
SQL
    );
  } else {
    $stmt = $pdo->prepare("INSERT OR REPLACE INTO oauth_accounts (id, provider, provider_user_id, owner_user_id, created_at, updated_at) VALUES (:id, :provider, :pid, :owner, :created, :updated)");
  }
  $stmt->execute([
    ":id" => uuid4(),
    ":provider" => $provider,
    ":pid" => $providerId,
    ":owner" => $user["id"],
    ":created" => $now,
    ":updated" => $now,
  ]);
  return $user;
}

function get_visibility_param(): ?string {
  $value = $_GET["visibility"] ?? null;
  if (!is_string($value)) return null;
  $normalized = strtolower(trim($value));
  if ($normalized === "public" || $normalized === "private") return $normalized;
  return null;
}

function handle_auth_routes(PDO $pdo, array $tail): void {
  $method = $_SERVER["REQUEST_METHOD"];
  if (!isset($tail[1])) {
    respond_error(404, "not_found");
  }
  switch ($tail[1]) {
    case "signup":
      if ($method !== "POST") respond_error(405, "method_not_allowed");
      $body = parse_body();
      $email = trim($body["email"] ?? "");
      $password = $body["password"] ?? "";
      if (!filter_var($email, FILTER_VALIDATE_EMAIL) || $password === "") {
        respond_error(400, "invalid_credentials");
      }
      $existing = find_user_by_email($pdo, $email);
      if ($existing) respond_error(409, "user_exists");
      $hash = password_hash($password, PASSWORD_BCRYPT);
      $user = create_user($pdo, $email, $hash);
      issue_session($pdo, $user["id"]);
      respond(201, ["user" => ["id" => $user["id"], "email" => $user["email"]]]);
      break;

    case "login":
      if ($method !== "POST") respond_error(405, "method_not_allowed");
      $body = parse_body();
      $email = trim($body["email"] ?? "");
      $password = $body["password"] ?? "";
      if (!filter_var($email, FILTER_VALIDATE_EMAIL) || $password === "") {
        respond_error(400, "invalid_credentials");
      }
      $user = find_user_by_email($pdo, $email);
      if (!$user || empty($user["password_hash"]) || !password_verify($password, $user["password_hash"])) {
        respond_error(401, "invalid_credentials");
      }
      issue_session($pdo, $user["id"]);
      respond(200, ["user" => ["id" => $user["id"], "email" => $user["email"]]]);
      break;

    case "logout":
      if ($method !== "POST") respond_error(405, "method_not_allowed");
      require_csrf();
      $user = current_user($pdo);
      if ($user) {
        revoke_session($pdo, $user["session_id"]);
      }
      clear_session_cookies();
      respond(200, ["ok" => true]);
      break;

    case "session":
      if ($method !== "GET") respond_error(405, "method_not_allowed");
      $user = current_user($pdo);
      $csrf = current_csrf_token();
      if (!$user) {
        respond(200, ["user" => null, "csrfToken" => $csrf]);
      }
      respond(200, ["user" => ["id" => $user["id"], "email" => $user["email"]], "csrfToken" => $csrf]);
      break;

    case "csrf":
      if ($method !== "GET") respond_error(405, "method_not_allowed");
      $user = current_user($pdo);
      respond(200, [
        "csrfToken" => current_csrf_token(),
        "authenticated" => (bool)$user,
      ]);
      break;

    case "password":
      if (!isset($tail[2])) respond_error(404, "not_found");
      if ($tail[2] === "request") {
        if ($method !== "POST") respond_error(405, "method_not_allowed");
        $body = parse_body();
        $email = trim($body["email"] ?? "");
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
          respond_error(400, "invalid_email");
        }
        $user = find_user_by_email($pdo, $email);
        if ($user) {
          $token = create_token(32);
          create_password_reset($pdo, $user["id"], $token);
          if (!send_password_reset_email($email, $token)) {
            respond_error(500, "email_failure");
          }
        }
        respond(200, ["ok" => true]);
      }
      if ($tail[2] === "reset") {
        if ($method !== "POST") respond_error(405, "method_not_allowed");
        $body = parse_body();
        $token = $body["token"] ?? "";
        $newPassword = $body["newPassword"] ?? "";
        if ($token === "" || $newPassword === "") {
          respond_error(400, "missing_fields");
        }
        $reset = consume_password_reset($pdo, $token);
        if (!$reset) {
          respond_error(400, "invalid_token");
        }
        $hash = password_hash($newPassword, PASSWORD_BCRYPT);
        $stmt = $pdo->prepare("UPDATE users SET password_hash = :hash, updated_at = :updated WHERE id = :id");
        $stmt->execute([
          ":hash" => $hash,
          ":updated" => gmdate("c"),
          ":id" => $reset["user_id"],
        ]);
        revoke_all_user_sessions($pdo, $reset["user_id"]);
        respond(200, ["ok" => true]);
      }
      respond_error(404, "not_found");
      break;

    case "oauth":
      if (!isset($tail[2]) || $tail[2] !== "google") {
        respond_error(404, "not_found");
      }
      if ($method !== "GET") respond_error(405, "method_not_allowed");
      $code = $_GET["code"] ?? "";
      $state = $_GET["state"] ?? "";
      if ($code === "") {
        $redirect = google_oauth_discovery_url($state);
        if (!$redirect) respond_error(500, "oauth_unconfigured");
        header("Location: $redirect");
        exit;
      }
      $tokens = fetch_google_tokens($code);
      if (!$tokens || empty($tokens["access_token"])) {
        respond_error(500, "oauth_token_failure");
      }
      $profile = fetch_google_profile($tokens["access_token"]);
      if (!$profile) {
        respond_error(500, "oauth_profile_failure");
      }
      $user = find_or_create_user_for_google($pdo, $profile);
      if (!$user) {
        respond_error(500, "oauth_user_failure");
      }
      issue_session($pdo, $user["id"]);
      $return = normalize_return_url($state);
      header("Location: $return");
      exit;
      break;

    default:
      respond_error(404, "not_found");
  }
}

function list_characters_for_user(PDO $pdo, array $user): array {
  if ($user["is_admin"]) {
    $stmt = $pdo->query("SELECT id, name, data, updated_at, owner_user_id, visibility FROM characters ORDER BY updated_at DESC");
    return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
  }
  $stmt = $pdo->prepare("SELECT id, name, data, updated_at, owner_user_id, visibility FROM characters WHERE owner_user_id = :uid ORDER BY updated_at DESC");
  $stmt->execute([":uid" => $user["id"]]);
  return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
}

function handle_characters(PDO $pdo, array $tail): void {
  $method = $_SERVER["REQUEST_METHOD"];
  if (count($tail) === 1) {
    if ($method === "GET") {
      $user = require_auth($pdo);
      $rows = list_characters_for_user($pdo, $user);
      $list = [];
      foreach ($rows as $row) {
        // Defense-in-depth: list endpoint must never emit non-owner rows for non-admin users.
        if (!$user["is_admin"] && ($row["owner_user_id"] ?? null) !== $user["id"]) {
          continue;
        }
        $list[] = [
          "id" => $row["id"],
          "name" => $row["name"],
          "updatedAt" => $row["updated_at"],
          "visibility" => $row["visibility"],
        ];
      }
      respond(200, $list);
    }
    if ($method === "POST") {
      require_csrf();
      $user = require_auth($pdo);
      $body = parse_body();
      $visibility = get_visibility_param() ?? $body["visibility"] ?? "private";
      unset($body["visibility"]);
      $visibility = $visibility === "public" ? "public" : "private";
      $errors = validate_record($body);
      if ($errors) {
        respond_error(400, "validation_failed", $errors);
      }
      $id = $body["id"] ?? uuid4();
      $name = $body["name"] ?? "";
      $now = gmdate("c");
      $body["id"] = $id;
      $body["createdAt"] = $body["createdAt"] ?? $now;
      $body["updatedAt"] = $body["updatedAt"] ?? $now;
      $stmt = $pdo->prepare("SELECT id FROM characters WHERE id = :id");
      $stmt->execute([":id" => $id]);
      if ($stmt->fetch()) {
        respond_error(409, "conflict", ["message" => "Character already exists"]);
      }
      $stmt = $pdo->prepare("INSERT INTO characters (id, name, data, created_at, updated_at, owner_user_id, visibility) VALUES (:id, :name, :data, :created_at, :updated_at, :owner, :visibility)");
      $stmt->execute([
        ":id" => $id,
        ":name" => $name,
        ":data" => json_encode($body, JSON_UNESCAPED_SLASHES),
        ":created_at" => $body["createdAt"],
        ":updated_at" => $body["updatedAt"],
        ":owner" => $user["id"],
        ":visibility" => $visibility,
      ]);
      respond(201, $body);
    }
    respond_error(405, "method_not_allowed");
  }
  $id = $tail[1] ?? "";
  if ($id === "") {
    respond_error(400, "missing_id");
  }
  if ($method === "GET") {
    $stmt = $pdo->prepare("SELECT data, visibility, owner_user_id FROM characters WHERE id = :id");
    $stmt->execute([":id" => $id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) respond_error(404, "not_found");
    if ($row["visibility"] !== "public") {
      $user = current_user($pdo);
      if (!$user || ($row["owner_user_id"] !== $user["id"] && !$user["is_admin"])) {
        respond_error(403, "forbidden");
      }
    }
    header("X-Character-Visibility: " . $row["visibility"]);
    $decoded = json_decode($row["data"], true);
    $record = is_array($decoded) ? normalize_record($decoded) : [];
    respond(200, $record);
  }
  if (!in_array($method, ["PUT", "DELETE"], true)) {
    respond_error(405, "method_not_allowed");
  }
  require_csrf();
  $user = require_auth($pdo);
  $stmt = $pdo->prepare("SELECT owner_user_id, visibility, data, updated_at FROM characters WHERE id = :id");
  $stmt->execute([":id" => $id]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);
  if (!$row) respond_error(404, "not_found");
  if ($row["owner_user_id"] !== $user["id"] && !$user["is_admin"]) {
    respond_error(403, "forbidden");
  }
  if ($method === "DELETE") {
    $stmt = $pdo->prepare("DELETE FROM characters WHERE id = :id");
    $stmt->execute([":id" => $id]);
    respond(200, ["ok" => true]);
  }
  $body = parse_body();
  if (($body["id"] ?? $id) !== $id) {
    respond_error(400, "id_mismatch");
  }
  $visibility = get_visibility_param() ?? $body["visibility"] ?? $row["visibility"];
  unset($body["visibility"]);
  $visibility = $visibility === "public" ? "public" : "private";
  $ifUnmod = get_if_unmodified_since();
  $remoteUpdated = strtotime($row["updated_at"] ?? "");
  if ($ifUnmod) {
    $clientUpdated = strtotime($ifUnmod);
    if ($remoteUpdated && $clientUpdated && $remoteUpdated > $clientUpdated && !isset($_GET["force"])) {
      $decoded = json_decode($row["data"], true);
      $current = is_array($decoded) ? normalize_record($decoded) : [];
      respond_error(409, "conflict", ["current" => $current]);
    }
  }
  $now = gmdate("c");
  $record = json_decode($row["data"], true) ?? [];
  $body["createdAt"] = $body["createdAt"] ?? ($record["createdAt"] ?? $now);
  $body["updatedAt"] = $now;
  $body["id"] = $id;
  $errors = validate_record($body);
  if ($errors) {
    respond_error(400, "validation_failed", $errors);
  }
  $stmt = $pdo->prepare("UPDATE characters SET name = :name, data = :data, updated_at = :updated, visibility = :visibility WHERE id = :id");
  $stmt->execute([
    ":id" => $id,
    ":name" => $body["name"] ?? "",
    ":data" => json_encode($body, JSON_UNESCAPED_SLASHES),
    ":updated" => $body["updatedAt"],
    ":visibility" => $visibility,
  ]);
  respond(200, $body);
}

function handle_admin_routes(PDO $pdo, array $tail, bool $hasValidApiKey): void {
  if (!isset($tail[1]) || $tail[1] !== "characters") {
    respond_error(404, "not_found");
  }
  $user = require_admin($pdo, $hasValidApiKey);
  $method = $_SERVER["REQUEST_METHOD"];
  if ($method === "GET") {
    $stmt = $pdo->query("SELECT id, name, created_at, updated_at FROM characters ORDER BY updated_at DESC");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respond(200, ["count" => count($rows), "items" => $rows ?: []]);
  }
  if ($method === "DELETE") {
    $confirm = $_GET["confirm"] ?? "";
    if ($confirm !== "1" && $confirm !== "true") {
      respond_error(400, "confirm_required", ["message" => "Add ?confirm=1 to delete all characters."]);
    }
    $stmt = $pdo->query("SELECT COUNT(*) AS count FROM characters");
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $count = (int)($row["count"] ?? 0);
    $pdo->exec("DELETE FROM characters");
    respond(200, ["ok" => true, "deleted" => $count]);
  }
  respond_error(405, "method_not_allowed");
}

function get_if_unmodified_since(): ?string {
  $headers = function_exists("getallheaders") ? getallheaders() : [];
  $val = $headers["If-Unmodified-Since"] ?? $headers["if-unmodified-since"] ?? null;
  if (!is_string($val) || $val === "") return null;
  return $val;
}

$uri = $_SERVER["REQUEST_URI"] ?? "/";
$path = parse_url($uri, PHP_URL_PATH);
$segments = array_values(array_filter(explode("/", trim($path, "/"))));
$idx = array_search("character-api", $segments, true);
$tail = $idx === false ? [] : array_slice($segments, $idx + 1);

if (count($tail) === 0) {
  respond(200, [
    "status" => "ok",
    "endpoints" => [
      "GET /character-api/health",
      "GET /character-api/schema.json",
      "POST /character-api/auth/signup",
      "POST /character-api/auth/login",
      "POST /character-api/auth/logout",
      "GET /character-api/auth/session",
      "GET /character-api/auth/csrf",
      "POST /character-api/auth/password/request",
      "POST /character-api/auth/password/reset",
      "GET /character-api/auth/oauth/google",
      "GET /character-api/characters",
      "POST /character-api/characters",
      "GET /character-api/characters/:id",
      "PUT /character-api/characters/:id",
      "DELETE /character-api/characters/:id",
      "GET /character-api/admin/characters",
      "DELETE /character-api/admin/characters?confirm=1",
    ],
  ]);
}

$pdo = open_db();

if ($tail[0] === "health") {
  respond(200, ["ok" => true]);
}

if ($tail[0] === "schema.json") {
  $schema = load_schema();
  if ($schema === []) {
    respond_error(500, "schema_unavailable");
  }
  respond(200, $schema);
}

if ($tail[0] === "auth") {
  handle_auth_routes($pdo, $tail);
}

if ($tail[0] === "admin") {
  handle_admin_routes($pdo, $tail, $hasValidApiKey);
}

if ($tail[0] === "characters") {
  handle_characters($pdo, $tail);
}

respond_error(404, "not_found");
