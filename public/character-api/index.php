<?php
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(204);
    exit;
}

$uri = $_SERVER["REQUEST_URI"] ?? "/";
$path = parse_url($uri, PHP_URL_PATH);
$segments = array_values(array_filter(explode("/", trim($path, "/"))));
$idx = array_search("character-api", $segments, true);
$tail = $idx === false ? [] : array_slice($segments, $idx + 1);

function respond($code, $payload) {
    http_response_code($code);
    echo json_encode($payload);
    exit;
}

if (count($tail) === 0) {
    respond(200, [
        "status" => "draft",
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
    respond(200, ["ok" => true, "status" => "draft"]);
}

respond(501, [
    "error" => "not_implemented",
    "message" => "Character API is draft-only; storage not implemented yet.",
]);
