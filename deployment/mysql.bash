#!/bin/bash -x

DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
ROOT_SQL_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
(cat <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_SQL_PASS';
FLUSH PRIVILEGES;
EOF
) | (test -f /root/mysql_pass && mysql -u root --password=$(cat /root/mysql_pass) || mysql -u root)
echo $ROOT_SQL_PASS >/root/mysql_pass
chmod 600 /root/mysql_pass
grep max_connections /etc/mysql/my.cnf || cat >>/etc/mysql/my.cnf <<'EOF'
[mysqld]
max_connections = 10000
EOF
systemctl restart mysql

(cat <<EOF
