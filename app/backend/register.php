<?php
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); echo json_encode(["error"=>"Method not allowed"]); exit; }
$input = json_decode(file_get_contents('php://input'), true);
$email = isset($input['email']) ? trim($input['email']) : '';
$password = isset($input['password']) ? $input['password'] : '';
if (!$email || !$password) { http_response_code(400); echo json_encode(["error"=>"Email and password required"]); exit; }
$db_host = getenv('DB_HOST');
$db_name = getenv('DB_NAME');
$db_user = getenv('DB_USER');
$db_pass = getenv('DB_PASS');
try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, email VARCHAR(255) UNIQUE NOT NULL, password_hash VARCHAR(255) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB");
    $stmt = $pdo->prepare('INSERT INTO users (email, password_hash) VALUES (?, ?)');
    $hash = password_hash($password, PASSWORD_BCRYPT);
    $stmt->execute([$email, $hash]);
    echo json_encode(["status"=>"registered"]);
} catch (PDOException $e) {
    if ($e->getCode() == 23000) { http_response_code(409); echo json_encode(["error"=>"Email already exists"]); }
    else { http_response_code(500); echo json_encode(["error"=>"DB error"]); }
}
