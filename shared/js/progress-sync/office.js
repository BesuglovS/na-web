/* ==========================================================================
   office-web → единая система прогресса Nayanova Academy
   Канонический источник: shared/js/progress-sync/office.js
   Переносит локальный прогресс (office-web-progress) в единую систему
   (auth.nayanovaacademy.ru/api/progress.php) и в nayanova-progress.
   Подключается на лендинге после progress-client.js.
   ========================================================================== */
(function (global) {
  'use strict';

  var COURSE = 'office';
  var STORAGE_KEY = 'office-web-progress';
  var TOTAL_FALLBACK = 21;
  var totalTopicsPromise = null;

  function getLocalProgress() {
    try {
      return JSON.parse(global.localStorage.getItem(STORAGE_KEY) || '{}');
    } catch (e) {
      return {};
    }
  }

  /**
   * Актуальное число тем курса берётся из data/topics.json
   * (сумма topics по всем разделам), fallback — 21.
   */
  function loadTotalTopics() {
    if (totalTopicsPromise) return totalTopicsPromise;
    totalTopicsPromise = global.fetch('data/topics.json')
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        if (!data || typeof data !== 'object') return TOTAL_FALLBACK;
        var total = 0;
        for (var section in data) {
          if (!Object.prototype.hasOwnProperty.call(data, section)) continue;
          var s = data[section];
          if (!s || typeof s !== 'object') continue;
          if (Array.isArray(s.topics)) total += s.topics.length;
        }
        return total > 0 ? total : TOTAL_FALLBACK;
      })
      .catch(function () { return TOTAL_FALLBACK; });
    return totalTopicsPromise;
  }

  function buildUpdates(total) {
    var data = getLocalProgress();
    var updates = [];
    var completed = 0;

    for (var section in data) {
      if (!Object.prototype.hasOwnProperty.call(data, section)) continue;
      var sec = data[section];
      if (!sec || typeof sec !== 'object') continue;
      for (var topicId in sec) {
        if (!Object.prototype.hasOwnProperty.call(sec, topicId)) continue;
        var t = sec[topicId];
        if (!t || typeof t !== 'object') continue;
        var done = !!t.completed;
        if (done) completed++;
        updates.push({
          module: section + '.' + topicId,
          completed: done ? 1 : 0,
          score: (typeof t.score === 'number' && t.score >= 0) ? t.score : null,
          data: { visited: !!t.visited, attempts: t.attempts || null }
        });
      }
    }

    if (!updates.length) return [];

    updates.push({
      module: '__summary__',
      completed: completed ? 1 : 0,
      data: { completed: completed, total: total }
    });
    return updates;
  }

  function sync() {
    if (!global.NayanovaProgress) return;
    loadTotalTopics().then(function (total) {
      var updates = buildUpdates(total);
      if (!updates.length) return;
      NayanovaProgress.init({ course: COURSE });
      NayanovaProgress.setBatch(updates);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', sync);
  } else {
    sync();
  }
})(window);
