# Архитектура проекта na-web

## Обзор

Главная страница-портал образовательной платформы **Академия Наянова**. Статический сайт (HTML + CSS + JS) без сборки и серверной логики. Служит единой точкой входа для всех подпроектов.

## Архитектура

```
na-web/
├── index.html          # Единая точка входа — каталог проектов
├── css/                # design-tokens.css, styles.css
├── js/                 # script.js, progress-client.js, progress-summary.js, uptime.js
├── data/projects.json  # Каталог проектов (id, домен, статус, описание)
├── shared/             # Канонические общие компоненты экосистемы (sync.ps1)
├── NULogo.png          # Логотип (PNG)
├── favicon.ico         # Фавикон
├── deploy.ps1          # Деплой портала на сервер
├── deploy-all.ps1      # Деплой всех проектов экосистемы
├── clone-repos.ps1     # Клонирование всех репозиториев (по github.txt)
├── github.txt          # Список репозиториев экосистемы
└── .git/               # Git-репозиторий
```

## Ключевые файлы

### index.html

Единый файл, содержащий:

1. **Шапку** — логотип, заголовок, описание
2. **Карточку «Мой прогресс»** — сводку по всем курсам (js/progress-summary.js → auth.nayanovaacademy.ru/api/progress.php)
3. **Сетку проектов** — карточки-ссылки на поддомены, рендерятся из data/projects.json (js/script.js)
4. **Поиск и фильтр** по названию/домену/статусу
5. **Подвал** — копирайт

Стили вынесены во внешние файлы `css/design-tokens.css` и `css/styles.css`.

### data/projects.json

Единственный источник данных о проектах: `id`, `title`, `domain`, `description`, `status` (`active`/`wip`), `icon`, `badge`, `theme`. Читается `js/script.js` при загрузке.

### shared/

Канонический источник общих компонентов экосистемы (`php/auth-client`, `php/progress-reporter`, `css/design-tokens.css`, `js/progress-client.js`, `js/progress-sync/*`, `pwa/*`). Распространяется по проектам скриптом `shared/sync.ps1`. Изменять файлы нужно только здесь, после чего запускать sync.

## Навигация

Каждая карточка является ссылкой (`<a>`) на соответствующий поддомен:

```
nayanovaacademy.ru
├── python.nayanovaacademy.ru   → Python-курс
├── ai.nayanovaacademy.ru       → ИИ и нейросети
├── j.nayanovaacademy.ru        → Журнал информационных технологий
├── oge.nayanovaacademy.ru      → Подготовка к ОГЭ
├── vpr.nayanovaacademy.ru      → Подготовка к ВПР
├── office.nayanovaacademy.ru   → Офисные приложения
├── history.nayanovaacademy.ru  → История России
├── contest.nayanovaacademy.ru  → Контесты
├── canvas.nayanovaacademy.ru   → Совместный холст
├── ege.nayanovaacademy.ru      → Подготовка к ЕГЭ (в разработке)
├── inf.nayanovaacademy.ru      → Информатика 7–9 (в разработке)
└── kege.nayanovaacademy.ru     → КЕГЭ (в разработке)
```

## Дизайн-система

Все проекты экосистемы используют общие визуальные принципы (см. shared/css/design-tokens.css):

| Элемент | Значение |
|---------|----------|
| Фон | `linear-gradient(135deg, #0f0c29, #302b63, #24243e)` |
| Акцент | `linear-gradient(135deg, #667eea, #764ba2)` |
| Карточки | `rgba(255, 255, 255, 0.06)` с бордером `rgba(255, 255, 255, 0.1)` |
| Шрифт | `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto` |

## Деплой

- **deploy.ps1** — деплой портала на VPS
- **deploy-all.ps1** — деплой всех проектов экосистемы (github.txt)
- **clone-repos.ps1** — клонирование всех репозиториев из GitHub (github.txt)

## Связь с другими проектами

Портал не содержит серверной логики — это статический каталог. Все проекты размещаются на отдельных поддоменах. Сводка прогресса по курсам получается из единого API прогресса `auth.nayanovaacademy.ru/api/progress.php` (клиент — `js/progress-client.js`).

## Ограничения

- Нет серверной логики
- Нет сборки (чистые HTML/CSS/JS)
- Нет тестов
