#!/bin/bash
set -e
yum update -y || true
amazon-linux-extras enable php8.0 || true
yum install -y httpd php php-mysqlnd wget unzip jq
systemctl enable httpd
systemctl start httpd

DB_HOST="${db_endpoint}"
DB_NAME="${db_name}"
DB_USER="appuser"
DB_PASS='${db_password}'

# Create schema and users table if not exists
cat > /tmp/bootstrap.sql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE TABLE IF NOT EXISTS \`$DB_NAME\`.users (
	id INT AUTO_INCREMENT PRIMARY KEY,
	email VARCHAR(255) UNIQUE NOT NULL,
	password_hash VARCHAR(255) NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
SQL

mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" < /tmp/bootstrap.sql || true

# Health endpoint
cat > /var/www/html/api.php <<'API'
<?php
header('Content-Type: application/json');
try {
	$pdo = new PDO('mysql:host=${db_endpoint};dbname=${db_name}', 'appuser', '${db_password}', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
	echo json_encode(["status"=>"ok"]);
} catch (Exception $e) {
	http_response_code(500);
	echo json_encode(["status"=>"error", "message"=>$e->getMessage()]);
}
API

# Register endpoint
cat > /var/www/html/register.php <<'REG'
<?php
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); echo json_encode(["error"=>"Method not allowed"]); exit; }
$input = json_decode(file_get_contents('php://input'), true);
$email = isset($input['email']) ? trim($input['email']) : '';
$password = isset($input['password']) ? $input['password'] : '';
if (!$email || !$password) { http_response_code(400); echo json_encode(["error"=>"Email and password required"]); exit; }
try {
	$pdo = new PDO('mysql:host=${db_endpoint};dbname=${db_name}', 'appuser', '${db_password}', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
	$stmt = $pdo->prepare('INSERT INTO users (email, password_hash) VALUES (?, ?)');
	$hash = password_hash($password, PASSWORD_BCRYPT);
	$stmt->execute([$email, $hash]);
	echo json_encode(["status"=>"registered"]);
} catch (PDOException $e) {
	if ($e->getCode() == 23000) { http_response_code(409); echo json_encode(["error"=>"Email already exists"]); }
	else { http_response_code(500); echo json_encode(["error"=>"DB error"]); }
}
REG

# Login endpoint
cat > /var/www/html/login.php <<'LOGIN'
<?php
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); echo json_encode(["error"=>"Method not allowed"]); exit; }
$input = json_decode(file_get_contents('php://input'), true);
$email = isset($input['email']) ? trim($input['email']) : '';
$password = isset($input['password']) ? $input['password'] : '';
if (!$email || !$password) { http_response_code(400); echo json_encode(["error"=>"Email and password required"]); exit; }
try {
	$pdo = new PDO('mysql:host=${db_endpoint};dbname=${db_name}', 'appuser', '${db_password}', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
	$stmt = $pdo->prepare('SELECT password_hash FROM users WHERE email = ? LIMIT 1');
	$stmt->execute([$email]);
	$row = $stmt->fetch(PDO::FETCH_ASSOC);
	if ($row && password_verify($password, $row['password_hash'])) {
		echo json_encode(["status"=>"ok"]);
	} else {
		http_response_code(401);
		echo json_encode(["error"=>"Invalid credentials"]);
	}
} catch (Exception $e) {
	http_response_code(500);
	echo json_encode(["error"=>"Server error"]);
}
LOGIN
