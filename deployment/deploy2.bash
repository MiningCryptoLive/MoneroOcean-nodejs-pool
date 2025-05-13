curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
source /home/pool/.nvm/nvm.sh
nvm install $NODEJS_VERSION
nvm alias default $NODEJS_VERSION
test -f /usr/bin/node || sudo ln -s \$(which node) /usr/bin/node
set -x
git clone https://github.com/MoneroOcean/nodejs-pool.git
cd /home/pool/nodejs-pool
JOBS=$(nproc) npm install
# install lmdb tools
( cd /home/pool
  rm -rf node-lmdb
  git clone https://github.com/Venemo/node-lmdb.git
  cd node-lmdb
  git checkout c3135a3809da1d64ce1f0956b37b618711e33519
  cd dependencies/lmdb/libraries/liblmdb
  make -j $(nproc)
  mkdir /home/pool/.bin
  echo >>/home/user/.bashrc
  echo 'export PATH=/home/pool/.bin:$PATH' >>/home/pool/.bashrc
  for i in mdb_copy mdb_dump mdb_load mdb_stat; do cp \$i /home/pool/.bin/; done
)
npm install -g pm2
pm2 install pm2-logrotate
openssl req -subj "/C=IT/ST=Pool/L=Daemon/O=Mining Pool/CN=mining.pool" -newkey rsa:2048 -nodes -keyout cert.key -x509 -out cert.pem -days 36500
mkdir /home/pool/pool_db
sed -r 's#("db_storage_path": ).*#\1"/home/pool/pool_db/",#' config_example.json >config.json
mysql -u root --password=$ROOT_SQL_PASS <deployment/base.sql
mysql -u root --password=$ROOT_SQL_PASS -e "INSERT INTO pool.config (module, item, item_value, item_type, Item_desc) VALUES ('api', 'authKey', '`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`', 'string', 'Auth key sent with all Websocket frames for validation.')"
mysql -u root --password=$ROOT_SQL_PASS -e "INSERT INTO pool.config (module, item, item_value, item_type, Item_desc) VALUES ('api', 'secKey', '`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`', 'string', 'HMAC key for Passwords.  JWT Secret Key.  Changing this will invalidate all current logins.')"
mysql -u root --password=$ROOT_SQL_PASS -e "UPDATE pool.config SET item_value = '$(cat /home/pool/wallets/wallet.address.txt)' WHERE module = 'pool' and item = 'address';"
mysql -u root --password=$ROOT_SQL_PASS -e "UPDATE pool.config SET item_value = '$(cat /home/pool/wallets/wallet_fee.address.txt)' WHERE module = 'payout' and item = 'feeAddress';"
pm2 start init.js --name=api --log-date-format="YYYY-MM-DD HH:mm Z" -- --module=api
pm2 start /usr/local/bin/monero/build/Linux/v0.18.3/release/bin/monero-wallet-rpc -- --rpc-bind-port 18082 --password-file /home/pool/wallets/wallet_pass --wallet-file /home/pool/wallets/wallet --trusted-daemon --disable-rpc-login
sleep 30
pm2 start init.js --name=blockManager --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z"  -- --module=blockManager
pm2 start init.js --name=worker --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z" --node-args="--max_old_space_size=8192" -- --module=worker
pm2 start init.js --name=payments --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z" --no-autorestart -- --module=payments
pm2 start init.js --name=remoteShare --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z" -- --module=remoteShare
pm2 start init.js --name=longRunner --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z" -- --module=longRunner
#pm2 start init.js --name=pool --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z" -- --module=pool
sleep 20
pm2 start init.js --name=pool_stats --kill-timeout 10000 --log-date-format="YYYY-MM-DD HH:mm:ss:SSS Z" -- --module=pool_stats
pm2 save
sudo env PATH=$PATH:/home/pool/.nvm/versions/node/$NODEJS_VERSION/bin /home/pool/.nvm/versions/node/$NODEJS_VERSION/lib/node_modules/pm2/bin/pm2 startup systemd -u user --hp /home/pool
cd /home/pool
git clone https://github.com/MoneroOcean/moneroocean-gui.git
cd moneroocean-gui
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser
sudo snap install chromium
npm install -g uglifycss uglify-js html-minifier
npm install -D critical@latest
EOF
) | su user -l

echo 'Now logout server, loging again under "user" account and run ~/moneroocean-gui/build.sh to build web site'
