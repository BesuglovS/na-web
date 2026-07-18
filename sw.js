var CACHE_NAME = 'na-web-v2';
var STATIC_ASSETS = [
    '/',
    '/index.html',
    '/404.html',
    '/offline.html',
    '/css/styles.css',
    '/js/script.js',
    '/js/uptime.js',
    '/data/projects.json',
    '/NULogo.png',
    '/favicon.ico',
    '/manifest.json'
];

// Установка: кэшируем статику
self.addEventListener('install', function (event) {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(function (cache) {
                return cache.addAll(STATIC_ASSETS);
            })
            .then(function () {
                return self.skipWaiting();
            })
    );
});

// Активация: удаляем старые кэши
self.addEventListener('activate', function (event) {
    event.waitUntil(
        caches.keys().then(function (keys) {
            return Promise.all(
                keys.filter(function (key) { return key !== CACHE_NAME; })
                    .map(function (key) { return caches.delete(key); })
            );
        }).then(function () {
            return self.clients.claim();
        })
    );
});

// Классификатор: статические ресурсы vs API/данные
function isStaticAsset(url) {
    var path = new URL(url).pathname;
    // Статика = локальные файлы (css, js, png, ico, json, html, манифест, корень)
    return /\.(css|js|png|ico|json|xml|svg)$/.test(path)
        || path === '/' || path === '/index.html'
        || path === '/offline.html'
        || path === '/404.html'
        || path === '/manifest.json';
}

self.addEventListener('fetch', function (event) {
    if (event.request.method !== 'GET') return;

    var url = event.request.url;

    // Cache-first для статических ресурсов
    if (isStaticAsset(url)) {
        event.respondWith(
            caches.match(event.request).then(function (cached) {
                if (cached) {
                    // Фоновое обновление кэша (stale-while-revalidate)
                    fetch(event.request).then(function (response) {
                        if (response && response.status === 200) {
                            caches.open(CACHE_NAME).then(function (cache) {
                                cache.put(event.request, response);
                            });
                        }
                    }).catch(function () {
                        // Не удалось обновить — не страшно, используем кэш
                    });
                    return cached;
                }
                // Если в кэше нет — идём в сеть
                return fetch(event.request).then(function (response) {
                    if (response && response.status === 200) {
                        var clone = response.clone();
                        caches.open(CACHE_NAME).then(function (cache) {
                            cache.put(event.request, clone);
                        });
                    }
                    return response;
                });
            }).catch(function () {
                // Если нет сети и нет в кэше — offline.html для navigation
                if (event.request.mode === 'navigate') {
                    return caches.match('/offline.html');
                }
                return new Response('Offline', { status: 503 });
            })
        );
        return;
    }

    // Network-first для всего остального (данные, внешние ресурсы)
    event.respondWith(
        fetch(event.request).then(function (response) {
            if (response && response.status === 200 && response.type === 'basic') {
                var clone = response.clone();
                caches.open(CACHE_NAME).then(function (cache) {
                    cache.put(event.request, clone);
                });
            }
            return response;
        }).catch(function () {
            return caches.match(event.request).then(function (cached) {
                if (cached) return cached;
                if (event.request.mode === 'navigate') {
                    return caches.match('/offline.html');
                }
                return new Response('Offline', { status: 503 });
            });
        })
    );
});