#!/bin/bash
# 字体颜色
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}


#检查域名解析

check_domain(){
    green "======================="
    blue "请输入绑定到本VPS的域名"
    green "======================="
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        green "=========================================="
        green "域名解析正常，开始安装Trojan-Panel"
        green "请耐心等待……"
        green "=========================================="
    sleep 1s
        install_1
        install_2
        install_3
        install_4
        install_5
        install_6
    green "======================================================================"
    green "Trojan-Panel已安装完成，请仔细阅读下面选项"
    green "请在浏览器中输入 https://$your_domain/config ，访问Trojan-Panel面板"
    green "第一次注册的用户为系统管理员"
    green "Quota 选项为流量管控选项。Quota 设置为 -1 ，即为无限流量"
    green "若是需要设置流量为 10GB，那么 Quota 设置为 10240000000。Quota 的单位是 字节"
    green "======================================================================"
    red "Trojan客户端配置参数"
    green "地址：$your_domain"
    green "密码：用户名:密码"
    green "端口：443"
    red " 密码里面的:为英文字符"
    green "Trojan windows最屌客户端已经集成在你的VPS里面"
    green "具体路径如下，请自行下载"
    green "VPS里面找到：/usr/local/etc/trojanwin ，里面有一个trojanwin.zip"
    green "自行解压文件，然后运行V2rayN，填入Trojan客户端配置参数"
    green "======================================================================"
    else
        red "================================"
        red "域名解析地址与本VPS IP地址不一致"
        red "本次安装失败，请确保域名解析正常"
        red "================================"
    fi
}

install_1(){
	echo
    green "===================="
    green " 开始配置系统并更新"
    green "===================="
    echo
    #开始配置及更新系统
    apt -y install software-properties-common apt-transport-https lsb-release ca-certificates
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://mirror.xtom.com.hk/sury/php/apt.gpg
    sh -c 'echo "deb https://mirror.xtom.com.hk/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'   
    apt-get update
    #安装环境
    apt install -y  tcl expect nginx curl socat sudo git unzip wget zip tar mariadb-server php7.2-fpm php7.2-mysql php7.2-cli php7.2-xml php7.2-json php7.2-mbstring php7.2-tokenizer php7.2-bcmath

    #安装Trojan官方版本
    sudo bash -c "$(wget -O- https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"

    #解析域名并第一次配置Nginx
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF
systemctl restart nginx
}

#申请证书
install_2(){
	echo
    green "===================="
    green " 开始申请证书"
    green "===================="
    echo
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d $your_domain --nginx
~/.acme.sh/acme.sh --installcert -d $your_domain --key-file /usr/local/etc/trojan/private.key --fullchain-file /usr/local/etc/trojan/certificate.crt
~/.acme.sh/acme.sh --upgrade --auto-upgrade
chmod -R 755 /usr/local/etc/trojan
}

#配置数据库

install_3(){
	echo
    green "===================="
    green " 开始配置数据库"
    green "===================="
    echo
mysqlpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
/usr/bin/expect << EOF
spawn mysql_secure_installation
expect "password for root" {send "$mysqlpasswd\r"}
expect "root password" {send "n\r"}
expect "anonymous users" {send "y\r"}
expect "root login remotely" {send "y\r"}
expect "test database and access to it" {send "y\r"}
expect "privilege tables now" {send "y\r"}
spawn mysql -u root -p
expect "Enter password" {send "$mysqlpasswd\r"}
expect "MariaDB" {send "CREATE DATABASE trojan;\r"}
expect "MariaDB" {send "GRANT ALL PRIVILEGES ON trojan.* to trojan@'%' IDENTIFIED BY '$mysqlpasswd';\r"}
expect "MariaDB" {send "quit\r"}
EOF

}


install_4(){
	echo
    green "=========================="
    green " 开始安装并配置Trojan-Panel"
    green "=========================="
    echo
#安装 PHP 软件包管理系统
cd /var/www
curl -sS https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir=/usr/local/bin --filename=composer

#安装 NodeJS 和 npm
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
apt install -y nodejs

#安装 Trojan-Panel
git clone https://github.com/trojan-gfw/trojan-panel.git
cd trojan-panel
composer install
npm install
npm audit fix --force
npm install
cp .env.example .env
php artisan key:generate
cat > /var/www/trojan-panel/.env <<-EOF
APP_NAME=Trojan-Panel
APP_ENV=production
APP_KEY=base64:nBtKl6j2QxHCPHvUUBnIUGYgPdWy1EYgBqePhUkpA0I=
APP_DEBUG=false
APP_URL=https://$your_domain

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=trojan
DB_USERNAME=trojan
DB_PASSWORD=$mysqlpasswd

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_DRIVER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

MIX_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
MIX_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
EOF
sleep 2s
php artisan migrate
cd /
chown -R www-data:www-data /var/www/trojan-panel

#第二次配置 Nginx 
cat > /etc/nginx/nginx.conf <<-EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {

    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_disable "msie6";

    # gzip_vary on;
    # gzip_proxied any;
    # gzip_comp_level 6;
    # gzip_buffers 16 8k;
    # gzip_http_version 1.1;
    # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}


#mail {
#   # See sample authentication script at:
#   # http://wiki.nginx.org/ImapAuthenticateWithApachePhpScript
# 
#   # auth_http localhost/auth.php;
#   # pop3_capabilities "TOP" "USER";
#   # imap_capabilities "IMAP4rev1" "UIDPLUS";
# 
#   server {
#       listen     localhost:110;
#       protocol   pop3;
#       proxy      on;
#   }
# 
#   server {
#       listen     localhost:143;
#       protocol   imap;
#       proxy      on;
#   }
#}
EOF

cat > /etc/nginx/sites-available/default <<-EOF
server {
listen 127.0.0.1:80 default_server;
 
server_name $your_domain;
 
location / {
proxy_pass https://www.v2rayssr.com;
}
 
location /config {
alias /var/www/trojan-panel/public;
index index.php;
try_files $uri $uri/ @config;
 
location ~ \.php$ {
include snippets/fastcgi-php.conf;
fastcgi_param SCRIPT_FILENAME $request_filename;
fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
}
 
location ~ /\.(?!well-known).* {
deny all;
}
}
 
location @config {
rewrite /config/(.*)$ /config/index.php?/$1 last;
}
 
}
 
server {
listen 127.0.0.1:80;
 
server_name $local_addr;
 
return 301 https://$your_domain$request_uri;
}
 
server {
listen 0.0.0.0:80;
listen [::]:80;
 
server_name _;
 
return 301 https://$host$request_uri;
}
EOF

}


install_5(){
	echo
    green "=============================="
    green " 配置Trojan服务器，并生成最新客户端"
    green "=============================="
    echo
cat > /usr/local/etc/trojan/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$mysqlpasswd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/usr/local/etc/trojan/certificate.crt",
        "key": "/usr/local/etc/trojan/private.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": true,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": "$mysqlpasswd"
    }
EOF

#下载官方最新Trojan-win客户端
mkdir /usr/local/etc/trojan/trojanwin-temp /usr/local/etc/trojanwin
cd /usr/local/etc/trojan
wget https://github.com/V2RaySSR/Trojan_Panel/raw/master/v2rayN-win-with-trojan-v2.zip
unzip v2rayN-win-with-trojan-v2.zip
wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest
    latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
wget -P /usr/local/etc/trojan/trojanwin-temp https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-win.zip
unzip /usr/local/etc/trojan/trojanwin-temp/trojan-${latest_version}-win.zip -d /usr/local/etc/trojan/trojanwin-temp
mv -f /usr/local/etc/trojan/trojanwin-temp/trojan.exe /usr/local/etc/trojan/v2rayN-win-with-trojan
zip -q -r trojanwin.zip /usr/local/etc/trojan/v2rayN-win-with-trojan
mv /usr/local/etc/trojan/v2rayN-win-with-trojan/trojanwin.zip /usr/local/etc/trojanwin


}

install_6(){
	echo
    green "========================="
    green " 开始设置启动项，并重启服务"
    green "========================="
    echo	
systemctl restart trojan
systemctl restart nginx
systemctl enable trojan
systemctl enable nginx
}

function bbr_boost_sh(){
    wget -N --no-check-certificate -q -O tcp.sh "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && bash tcp.sh
}

start_menu(){
    clear
    green "=================================================="
    green " 介绍：适用Debian9，一键安装Trojan-Panel "
    green " 作者：波仔 "
    green " Youtube：波仔分享 "
    green " 博客：www.v2rayssr.com "
    green "=================================================="
    red " 本脚本仅仅支持Debian9，其他Debian系统未测试！"
    red " 本脚本仅仅支持Debian9，其他Debian系统未测试！"
    red " 本脚本仅仅支持Debian9，其他Debian系统未测试！"
    green "=================================================="
    red "若觉得脚本有用，请订阅波仔的YouTube，谢谢支持"
    green "=================================================="
    green "1. 一键安装Trojan-Panel"
    green "2. 安装BBRPlus4合一加速"
    red "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
        1)
        check_domain
        ;;
        2)
        bbr_boost_sh
        ;;
        0)
        exit 1
        ;;
        *)
    clear
    echo "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
