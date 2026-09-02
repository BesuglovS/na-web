# ==========================================
# 1. Редирект HTTP → HTTPS
# ==========================================
server {
    listen 80;
    server_name nayanovaacademy.ru www.nayanovaacademy.ru;

    # Перенаправляем все запросы на HTTPS
    return 301 https://$host$request_uri;
}

# ==========================================
# 2. Основной HTTPS-сервер
# ==========================================
server {
    listen 443 ssl http2;
    server_name nayanovaacademy.ru www.nayanovaacademy.ru;

    # --- SSL-сертификаты (ваши пути) ---
    ssl_certificate     /etc/ssl/certs/nayanovaacademy.ru/cert.pem;
    ssl_certificate_key /etc/ssl/private/nayanovaacademy.ru/key.pem;

    # --- Настройки безопасности SSL ---
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # HSTS (обязывает браузер использовать только HTTPS)
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # --- Основные параметры сайта ---
    root /var/www/nayanovaacademy.ru/public;
    index index.html index.htm;

    # Логирование
    access_log /var/log/nginx/nayanovaacademy.ru.access.log;
    error_log  /var/log/nginx/nayanovaacademy.ru.error.log;

    # 1. Основная маршрутизация
    location / {
        try_files $uri $uri/ =404;
    }

    # 2. Кэширование статики
    # Ecosystem-скрипты без content-hash - ne keshirovat, inache obnovleniya
    # dohodyat do 30 dney (tracking-client, progress-client, progress-sync).
    location = /js/tracking-client.js {
        add_header Cache-Control "no-cache, must-revalidate";
    }

    location = /js/progress-client.js {
        add_header Cache-Control "no-cache, must-revalidate";
    }

    location = /js/progress-summary.js {
        add_header Cache-Control "no-cache, must-revalidate";
    }

    location = /sw.js {
        add_header Cache-Control "no-cache, must-revalidate";
    }

    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|mp4|webm|pdf|zip)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # 3. Блокировка скрытых файлов
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # 4. Кастомная 404 страница (опционально)
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }
}
