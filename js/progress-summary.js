(function () {
    'use strict';

    /**
     * Карточка «Мой прогресс» на портале na-web.
     * Показывает сводку по всем курсам через единый серверный прогресс
     * (shared/js/progress-client.js → auth.nayanovaacademy.ru/api/progress.php).
     */

    var AUTH_SERVICE_URL = 'https://auth.nayanovaacademy.ru';

    var COURSE_NAMES = {
        oge: 'ОГЭ — информатика',
        office: 'Офисные приложения',
        inf: 'Информатика 7–9',
        vpr7: 'ВПР — 7 класс',
        vpr8: 'ВПР — 8 класс',
        python: 'Python',
        ai: 'ИИ и нейросети',
        j: 'Программирование (Java)',
        contest: 'Контесты'
    };

    function esc(str) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(String(str)));
        return div.innerHTML;
    }

    function courseName(id) {
        return COURSE_NAMES[id] || id;
    }

    function buildCourseRow(id, stat) {
        var pct = Math.max(0, Math.min(100, stat.percentage || 0));
        var div = document.createElement('div');
        div.className = 'course-row';
        div.innerHTML =
            '<div class="course-row-header">' +
            '  <span class="course-name">' + esc(courseName(id)) + '</span>' +
            '  <span class="course-pct">' + pct + '%</span>' +
            '</div>' +
            '<div class="course-bar" role="progressbar" aria-valuenow="' + pct + '" aria-valuemin="0" aria-valuemax="100">' +
            '  <div class="course-bar-fill" style="width:' + pct + '%"></div>' +
            '</div>' +
            '<div class="course-count">' + (stat.completed || 0) + ' / ' + (stat.total || 0) + ' заданий</div>';
        return div;
    }

    function buildLoginPrompt() {
        var div = document.createElement('div');
        var returnUrl = encodeURIComponent(window.location.href);
        div.className = 'progress-empty';
        div.innerHTML =
            '<p class="progress-empty-text">Войдите, чтобы видеть свой прогресс по всем проектам</p>' +
            '<a class="progress-login-btn" href="' + AUTH_SERVICE_URL +
            '/index.php?page=login&redirect=' + returnUrl + '">Войти</a>';
        return div;
    }

    function buildUnavailable() {
        var div = document.createElement('div');
        div.className = 'progress-empty';
        div.innerHTML =
            '<p class="progress-empty-text">Сервис авторизации временно недоступен. Обновите страницу позже — прогресс никуда не денется.</p>';
        return div;
    }

    function buildNoData() {
        var div = document.createElement('div');
        div.className = 'progress-empty';
        div.innerHTML =
            '<p class="progress-empty-text">У вас пока нет сохранённого прогресса. Пройдите любое задание в проектах — он появится здесь.</p>';
        return div;
    }

    function buildHeader(summary) {
        var courses = summary.courses || {};
        var totalCompleted = 0;
        var totalAll = 0;
        Object.keys(courses).forEach(function (id) {
            totalCompleted += (courses[id].completed || 0);
            totalAll += (courses[id].total || 0);
        });
        var overall = totalAll > 0 ? Math.round(totalCompleted / totalAll * 100) : 0;

        var div = document.createElement('div');
        div.className = 'progress-header';
        div.innerHTML =
            '<h2 class="progress-title">Мой прогресс</h2>' +
            '<div class="progress-overall">' +
            '  <div class="progress-overall-bar" role="progressbar" aria-valuenow="' + overall + '" aria-valuemin="0" aria-valuemax="100">' +
            '    <div class="progress-overall-fill" style="width:' + overall + '%"></div>' +
            '  </div>' +
            '  <span class="progress-overall-pct">' + overall + '%</span>' +
            '</div>';
        return div;
    }

    function render(data) {
        var card = document.getElementById('progress-card');
        if (!card) return;
        card.innerHTML = '';
        card.classList.add('ready');

        if (data === null) {
            var state = window.NayanovaProgress && typeof NayanovaProgress.getAuthState === 'function'
                ? NayanovaProgress.getAuthState()
                : { authed: false, unavailable: false };
            card.appendChild(state.unavailable ? buildUnavailable() : buildLoginPrompt());
            return;
        }

        var courses = (data && data.courses) || {};
        var ids = Object.keys(courses).sort();
        if (ids.length === 0) {
            card.appendChild(buildNoData());
            return;
        }

        card.appendChild(buildHeader(data));
        var list = document.createElement('div');
        list.className = 'course-list';
        ids.forEach(function (id) {
            list.appendChild(buildCourseRow(id, courses[id]));
        });
        card.appendChild(list);
    }

    function init() {
        if (!window.NayanovaProgress) return;
        NayanovaProgress.init();
        NayanovaProgress.getSummary().then(render).catch(function () {
            render(null);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
