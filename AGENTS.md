# AGENTS.md — Инструкции для ИИ-ассистентов

Главный портал Академии Наяновой (лендинг + карточки курсов) — `https://nayanovaacademy.ru`.
Статический сайт: HTML + CSS (design tokens) + vanilla JS (ES5-IIFE), без сборки и фреймворков.
Ключевая роль — **хаб экосистемы из 12 поддоменов** и **источник канонических shared-файлов**,
которые копируются в другие проекты.

## ⚠️ Критические правила

1. **`shared/` — канонический источник** для экосистемы. Файлы там копируются (не через package/submodule)
   в другие репозитории, чтобы каждый проект оставался само-деплоящимся:
   - `shared/js/progress-client.js`, `shared/js/progress-sync/*`
   - `shared/php/auth-client/AuthClient.php` (используется auth-web/contest/j/ai)
   - `shared/php/progress-reporter/ProgressReporter.php`
   - `shared/css/design-tokens.css`
   - `shared/sync.ps1` — синк этих файлов на поддомены. **После правки канонического файла запускайте синк**,
     иначе экосистема разойдётся.
2. **`data/projects.json` — реестр проектов** (12 записей). Согласован с `js/progress-summary.js`
   (`COURSE_NAMES`: oge, office, inf, vpr7, vpr8, python, ai, j, contest) — при добавлении курса
   править оба места + `index.html` карточки.
3. **Не вводите легаси-зависимости в shared-файлах**: они ES5-IIFE (`var`, `'use strict'`, `window.Nayanova*`)
   и должны работать на всех поддоменах. Экспорты — только глобальные (`window.NayanovaProgress`, `window.NayanovaTrack`).
4. **`.env` закоммичен** (содержит IP сервера и SSH-параметры). Не печатать значения; новые секреты туда
   не добавлять. `.gitignore` в проекте НЕТ — секреты защищает только exclude-список `deploy.ps1`.
5. **`github.txt` — НЕ токен**, это список URL репозиториев для клонирования. Не «фиксить».
6. **SSO-интеграция**: все карточки прогресса и курсы зависят от `auth.nayanovaacademy.ru` (auth-web).
   `progress-client.js`/`progress-summary.js`/`tracking-client.js` зовут его с `credentials: 'include'`.
7. **`sw.js` не кэширует `progress-*` и `tracking-client.js`** в STATIC_ASSETS — учитывать при работе с оффлайном.
8. **Нет тестов и нет `.gitignore`** — CI (`.github/workflows/deploy.yml`) валидирует только JSON/XML/sitemap.
9. **HSTS с `preload` и `includeSubDomains`** (в nginx-конфиге) — влияет на ВСЕ поддомены; менять осознанно.
10. **Рабочее дерево впереди git**: есть правки `deploy.ps1`, `index.html`, `shared/sync.ps1` и
    untracked `js/tracking-client.js`, `nayanovaacademy.ru`. Не «чистить».

## 🔧 Команды

```bash
python -m http.server 8000       # локальный dev-сервер
.\shared\sync.ps1                # синк канонических shared-файлов на поддомены
.\deploy.ps1 -DryRun             # деплой портала
.\deploy-all.ps1                 # синк shared + per-project fetch/pull/deploy (вся экосистема)
.\clone-repos.ps1                # клонирование репозиториев поддоменов
.\deploy.ps1                     # деплой (SSH + nginx)
```

## 🏗 Структура

```
index.html               # лендинг: карточки курсов, uptime, прогресс по курсам
data/projects.json       # реестр 12 проектов (source of truth для карточек)
shared/                  # КАНОНИЧЕСКИЕ файлы экосистемы + sync.ps1 (см. крит. правило 1)
  js/progress-client.js, progress-sync/*, css/design-tokens.css
  php/auth-client/AuthClient.php, php/progress-reporter/ProgressReporter.php
css/                     # styles + design-tokens (общие токены --na-*)
js/script.js, uptime.js, progress-summary.js, tracking-client.js
manifest.json, sw.js, sitemap.xml, robots.txt, 404.html, offline.html
deploy.ps1, deploy-all.ps1, clone-repos.ps1
nayanovaacademy.ru       # nginx-конфиг (деплоится deploy.ps1)
.github/workflows/deploy.yml   # CI: push в main → rsync-деплой
```

## 💻 Конвенции кода

- **JS (shared/ и js/)**: ES5-IIFE, `'use strict'`, только `var`, глобальные `window.Nayanova*`,
  конкатенация строк, `document.createElement` + `innerHTML`, HTML-экранирование пользовательских
  данных через локальный `esc()`. Заголовок файла: `/* ==== ... Канонический источник: <path> ... ==== */`.
- **PHP (shared/)**: `if (!class_exists(...))` guard (безопасно включать многократно), статические методы,
  `curl` с таймаутом 5с и проверкой SSL, `Throwable` catch.
- **CSS**: CSS-переменные `--na-*` в `design-tokens.css` (грузится первым), BEM-подобные `.na-btn--primary`,
  mobile-first `@media (max-width: 768px/480px)`, `prefers-reduced-motion`, `:focus-visible`,
  `[data-theme="light"]` для ручного переключателя темы.
- **HTML**: семантика, `lang="ru"`, OG + Twitter, Schema.org Organization JSON-LD, ARIA.
- Контент, комментарии, доки — **русский**.

## 🚀 Деплой

**Два пути на один сервер** (`79.143.31.184`, root `/var/www/nayanovaacademy.ru/public/`):

1. **Вручную** (`deploy.ps1`): tar по SSH → удалённо `rm -rf` + распаковка → опц. nginx-конфиг + reload.
2. **CI** (`.github/workflows/deploy.yml`, push в `main`): `rsync -avzr --delete`, исключает `.git/`,
   `.github/`, `refactoring.md`. Требует GitHub-секреты `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY`, `REMOTE_PATH`.
   ⚠️ CI **не исключает `.env`** — не коммитьте в него секреты.
3. **Вся экосистема** (`deploy-all.ps1`): синк shared → по каждому проекту pull + deploy.

Требования сервера: nginx, SSL-серты `/etc/ssl/certs/nayanovaacademy.ru/`, TLS 1.2/1.3, HSTS preload,
static `immutable 30d`, `no-cache` для `/sw.js` и `/js/tracking-client.js`, dotfiles deny, `error_page 404 /404.html`.

## 🔒 Безопасность

- `G:\WebSites\na\ssh-private.key` — незашифрованный SSH-ключ вне репозиториев: никогда не читать, не печатать, не коммитить.
- `.env` не печатать; при изменении помнить про exclude-список `deploy.ps1` и CI.
- `refactoring.md` (от Cline) — исторический анализ, местами устарел (там «10 проектов», сейчас 12;
  утверждал отсутствие 404/filtering — они есть). Не принимать как текущую истину.
- `uptime.js` выводит id проекта из домена (`domain.replace(...)`) — ломается на доменах с точками; хрупкое место.