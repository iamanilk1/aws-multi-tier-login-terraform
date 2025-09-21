#!/bin/bash
set -e
yum update -y || true
amazon-linux-extras enable php8.0 || true
yum install -y httpd php php-mysqlnd wget unzip
systemctl enable httpd
systemctl start httpd
# simple health file
mkdir -p /var/www/html
cat > /var/www/html/health <<'HEALTH'
OK
HEALTH
# homepage with centered Register and link to Login page
cat > /var/www/html/index.html <<'IDX'
<html>
	<head>
		<meta charset="utf-8" />
		<title>Simple Login Frontend</title>
		<style>
			body { font-family: Arial, Helvetica, sans-serif; }
			.container { max-width: 420px; margin: 60px auto; text-align: center; }
			input { display:block; width:100%; box-sizing: border-box; margin:8px 0; padding:10px; }
			button { padding:10px 16px; }
			.link { margin-top: 12px; }
		</style>
	</head>
	<body>
		<div class="container">
			<h1>Simple Login Frontend</h1>
			<h2>Register</h2>
			<input id="reg_email" placeholder="Email" />
			<input id="reg_password" type="password" placeholder="Password" />
			<button onclick="register()">Register</button>
			<div id="reg_result"></div>
			<div class="link">Already a user? <a href="/login.html">Login</a></div>
		</div>
		<script>
			async function register() {
				const email = document.getElementById('reg_email').value;
				const password = document.getElementById('reg_password').value;
				const res = await fetch('/api/register.php', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({email, password}) });
				const data = await res.json();
				document.getElementById('reg_result').innerText = JSON.stringify(data);
			}
		</script>
	</body>
</html>
IDX

# dedicated login page
cat > /var/www/html/login.html <<'LOGIN'
<html>
	<head>
		<meta charset="utf-8" />
		<title>Login</title>
		<style>
			body { font-family: Arial, Helvetica, sans-serif; }
			.container { max-width: 420px; margin: 60px auto; text-align: center; }
			input { display:block; width:100%; box-sizing: border-box; margin:8px 0; padding:10px; }
			button { padding:10px 16px; }
			.link { margin-top: 12px; }
		</style>
	</head>
	<body>
		<div class="container">
			<h1>Login</h1>
			<input id="log_email" placeholder="Email" />
			<input id="log_password" type="password" placeholder="Password" />
			<button onclick="login()">Login</button>
			<div id="log_result"></div>
			<div class="link">New here? <a href="/">Register</a></div>
		</div>
		<script>
			async function login() {
				const email = document.getElementById('log_email').value;
				const password = document.getElementById('log_password').value;
				const res = await fetch('/api/login.php', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({email, password}) });
				const data = await res.json();
				document.getElementById('log_result').innerText = JSON.stringify(data);
			}
		</script>
	</body>
</html>
LOGIN
