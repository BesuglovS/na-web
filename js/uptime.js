(function () {
    'use strict';

    /**
     * Проверить доступность домена
     * @param {string} domain
     * @returns {Promise<boolean>}
     */
    function checkProjectStatus(domain) {
        return new Promise(function (resolve) {
            try {
                var controller = new AbortController();
                var timeoutId = setTimeout(function () {
                    controller.abort();
                    resolve(false);
                }, 5000);

                fetch('https://' + domain, {
                    mode: 'no-cors',
                    signal: controller.signal
                })
                    .then(function () {
                        clearTimeout(timeoutId);
                        resolve(true);
                    })
                    .catch(function () {
                        clearTimeout(timeoutId);
                        resolve(false);
                    });
            } catch (e) {
                resolve(false);
            }
        });
    }

    /**
     * Обновить бейджи статусов на основе реального uptime
     * @param {Array} projects
     */
    function updateStatuses(projects) {
        var activeDomains = projects.filter(function (p) { return p.status === 'active'; });
        var pending = activeDomains.length;
        var results = {};

        if (pending === 0) return;

        activeDomains.forEach(function (project) {
            checkProjectStatus(project.domain).then(function (isUp) {
                results[project.id] = isUp;
                pending--;

                if (pending === 0) {
                    applyResults(results);
                }
            });
        });

        // Fallback: apply whatever we have after 8 seconds
        setTimeout(function () {
            if (pending > 0) {
                pending = 0;
                applyResults(results);
            }
        }, 8000);
    }

    /**
     * Применить результаты проверки к DOM
     * @param {Object.<string, boolean>} results
     */
    function applyResults(results) {
        var cards = document.querySelectorAll('.project-card');
        cards.forEach(function (card) {
            var status = card.getAttribute('data-status');
            if (status === 'active') {
                var badge = card.querySelector('.badge');
                var domainEl = card.querySelector('.card-domain');
                var domain = domainEl ? domainEl.textContent : '';
                var id = domain.replace(/\.nayanovaacademy\.ru$/, '').replace(/\./g, '');

                // Try multiple ways to find the project id
                var isUp = results[id];
                if (isUp === undefined) {
                    // Try matching by domain
                    for (var key in results) {
                        if (results.hasOwnProperty(key) && domain.indexOf(key) === 0) {
                            isUp = results[key];
                            break;
                        }
                    }
                }

                if (badge) {
                    if (isUp === true) {
                        badge.className = 'badge badge-live';
                        badge.textContent = 'В сети';
                        badge.title = 'Сайт доступен';
                    } else if (isUp === false) {
                        badge.className = 'badge badge-down';
                        badge.textContent = 'Недоступен';
                        badge.title = 'Сайт временно недоступен';
                    }
                }
            }
        });
    }

    /**
     * Запустить проверку
     */
    function init(projects) {
        // Проверяем только активные проекты (не wip)
        var activeProjects = projects.filter(function (p) { return p.status === 'active'; });
        if (activeProjects.length > 0) {
            updateStatuses(activeProjects);
        }
    }

    // Экспорт в глобальную область видимости
    window.checkUptime = init;
})();