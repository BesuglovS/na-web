(function () {
    'use strict';

    /**
     * Текущий фильтр: 'all' | 'active' | 'wip'
     */
    var currentFilter = 'all';
    var currentSearch = '';

    /**
     * Escape HTML-символы
     */
    function esc(str) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }

    /**
     * Создать DOM-элемент карточки проекта
     */
    function createCard(project) {
        var isWip = project.status === 'wip';
        var statusClass = isWip ? 'wip-card' : 'active-card';
        var badgeClass = isWip ? 'badge-wip' : 'badge-live';
        var url = 'https://' + esc(project.domain);

        var a = document.createElement('a');
        a.href = url;
        a.className = 'project-card ' + statusClass;
        a.setAttribute('data-status', project.status);

        a.innerHTML =
            '<div class="card-header">' +
            '  <div class="card-icon" role="img" aria-label="' + esc(project.title) + '">' + esc(project.icon) + '</div>' +
            '  <div class="card-title-area">' +
            '    <div class="card-title">' +
            '      ' + esc(project.title) +
            '      <span class="badge ' + badgeClass + '">' + esc(project.badge) + '</span>' +
            '    </div>' +
            '    <div class="card-domain">' + esc(project.domain) + '</div>' +
            '  </div>' +
            '</div>' +
            '<p class="card-description">' + esc(project.description) + '</p>' +
            '<div class="card-footer">' +
            '  <span>' + (isWip ? 'Следите за обновлениями' : 'Перейти к проекту') + '</span>' +
            '  <span class="arrow">→</span>' +
            '</div>';

        if (isWip) {
            a.style.opacity = '0.6';
        }
        return a;
    }

    /**
     * Проверить, соответствует ли проект поиску и фильтру
     */
    function matches(project) {
        if (currentFilter !== 'all' && project.status !== currentFilter) {
            return false;
        }
        if (currentSearch) {
            var term = currentSearch.toLowerCase();
            return project.title.toLowerCase().indexOf(term) !== -1
                || project.domain.toLowerCase().indexOf(term) !== -1
                || project.description.toLowerCase().indexOf(term) !== -1;
        }
        return true;
    }

    /**
     * Рендерить все карточки
     */
    function render(projects) {
        var grid = document.querySelector('.projects-grid');
        var noResults = document.querySelector('.no-results');

        // Очистить сетку
        while (grid.firstChild !== noResults) {
            if (grid.firstChild) {
                grid.removeChild(grid.firstChild);
            } else {
                break;
            }
        }

        var visible = 0;
        projects.forEach(function (p) {
            if (matches(p)) {
                grid.insertBefore(createCard(p), noResults);
                visible++;
            }
        });

        noResults.classList.toggle('visible', visible === 0);
    }

    /**
     * Загрузить projects.json и отрисовать
     */
    function init() {
        fetch('data/projects.json')
            .then(function (res) {
                if (!res.ok) throw new Error('Failed to load projects');
                return res.json();
            })
            .then(function (projects) {
                render(projects);

                // Обработчики поиска и фильтрации
                var searchInput = document.getElementById('search-input');
                if (searchInput) {
                    searchInput.addEventListener('input', function () {
                        currentSearch = this.value;
                        render(projects);
                    });
                }

                var filterButtons = document.querySelectorAll('.filter-btn');
                filterButtons.forEach(function (btn) {
                    btn.addEventListener('click', function () {
                        filterButtons.forEach(function (b) { b.classList.remove('active'); });
                        this.classList.add('active');
                        currentFilter = this.getAttribute('data-filter');
                        render(projects);
                    });
                });

                // Запускаем uptime-проверку после рендера
                if (typeof window.checkUptime === 'function') {
                    window.checkUptime(projects);
                }
            })
            .catch(function (err) {
                console.error('Ошибка загрузки проектов:', err);
            });
    }

    /**
     * Инициализация переключателя темы
     */
    function initThemeToggle() {
        var toggle = document.getElementById('theme-toggle');
        if (!toggle) return;

        var saved = localStorage.getItem('na-theme');
        if (saved === 'light' || saved === 'dark') {
            document.documentElement.setAttribute('data-theme', saved);
            toggle.textContent = saved === 'light' ? '\u2600\uFE0F' : '\uD83C\uDF19';
        }

        toggle.addEventListener('click', function () {
            var current = document.documentElement.getAttribute('data-theme');
            var next = current === 'light' ? 'dark' : 'light';
            document.documentElement.setAttribute('data-theme', next);
            localStorage.setItem('na-theme', next);
            toggle.textContent = next === 'light' ? '\u2600\uFE0F' : '\uD83C\uDF19';
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () {
            initThemeToggle();
            init();
        });
    } else {
        initThemeToggle();
        init();
    }
})();