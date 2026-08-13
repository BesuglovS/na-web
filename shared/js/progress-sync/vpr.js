/* ==========================================================================
   vpr7 → единая система прогресса Nayanova Academy
   Канонический источник: shared/js/progress-sync/vpr.js
   Переносит локальный прогресс разделов 7 и 8 классов (vpr7-progress /
   vpr8-progress) в единую систему (auth.nayanovaacademy.ru/api/progress.php)
   и в nayanova-progress. Обрабатывает оба курса за один запуск.
   Подключается на лендингах после progress-client.js.
   ========================================================================== */
(function (global) {
  'use strict';

  var COURSES = [
    { key: 'vpr7-progress', course: 'vpr7', total: 12 },
    { key: 'vpr8-progress', course: 'vpr8', total: 10 }
  ];

  function getLocalProgress(key) {
    try {
      return JSON.parse(global.localStorage.getItem(key) || 'null');
    } catch (e) {
      return null;
    }
  }

  function buildUpdates(cfg) {
    var p = getLocalProgress(cfg.key);
    if (!p || typeof p !== 'object') return [];

    var done = {};
    var completedList = Array.isArray(p.completed) ? p.completed : [];
    for (var i = 0; i < completedList.length; i++) {
      done[completedList[i]] = true;
    }

    var scores = (p && typeof p.scores === 'object') ? p.scores : {};
    var updates = [];
    var completed = 0;

    for (var n = 1; n <= cfg.total; n++) {
      if (!done[n]) continue;
      completed++;
      var sc = scores[n];
      updates.push({
        module: 'task-' + n,
        completed: 1,
        score: (sc && typeof sc.score === 'number') ? sc.score : null,
        data: sc ? { attempts: sc.attempts || null, correct: !!sc.correct } : null
      });
    }

    if (!updates.length) return [];

    updates.push({
      module: '__summary__',
      completed: completed ? 1 : 0,
      data: { completed: completed, total: cfg.total }
    });
    return updates;
  }

  function sync() {
    if (!global.NayanovaProgress) return;
    for (var i = 0; i < COURSES.length; i++) {
      var cfg = COURSES[i];
      var updates = buildUpdates(cfg);
      if (!updates.length) continue;
      NayanovaProgress.init({ course: cfg.course });
      NayanovaProgress.setBatch(updates);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', sync);
  } else {
    sync();
  }
})(window);
