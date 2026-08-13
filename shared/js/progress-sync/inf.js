/* ==========================================================================
   inf-web → единая система прогресса Nayanova Academy
   Канонический источник: shared/js/progress-sync/inf.js
   Переносит локальный прогресс (inf_progress) в единую систему
   (auth.nayanovaacademy.ru/api/progress.php) и в nayanova-progress.
   Подключается на лендинге после progress-client.js.
   ========================================================================== */
(function (global) {
  'use strict';

  var COURSE = 'inf';
  var STORAGE_KEY = 'inf_progress';
  var TOTAL_TOPICS = 24;

  function getLocalProgress() {
    try {
      return JSON.parse(global.localStorage.getItem(STORAGE_KEY) || '{}');
    } catch (e) {
      return {};
    }
  }

  function buildUpdates() {
    var data = getLocalProgress();
    var updates = [];
    var completed = 0;

    for (var topicId in data) {
      if (!Object.prototype.hasOwnProperty.call(data, topicId)) continue;
      var t = data[topicId];
      if (!t || typeof t !== 'object') continue;
      var done = !!t.completed;
      if (done) completed++;
      updates.push({
        module: topicId,
        completed: done ? 1 : 0,
        score: null,
        data: { date: t.date || null }
      });
    }

    if (!updates.length) return [];

    updates.push({
      module: '__summary__',
      completed: completed ? 1 : 0,
      data: { completed: completed, total: TOTAL_TOPICS }
    });
    return updates;
  }

  function sync() {
    if (!global.NayanovaProgress) return;
    var updates = buildUpdates();
    if (!updates.length) return;
    NayanovaProgress.init({ course: COURSE });
    NayanovaProgress.setBatch(updates);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', sync);
  } else {
    sync();
  }
})(window);
