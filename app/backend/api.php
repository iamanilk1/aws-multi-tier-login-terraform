<?php
header('Content-Type: application/json');
$db_host = getenv('DB_HOST');
$db_name = getenv('DB_NAME');
$db_user = getenv('DB_USER');
$db_pass = getenv('DB_PASS');
try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    echo json_encode(["status"=>"ok"]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status"=>"error", "message"=>$e->getMessage()]);
}
