// =====================================================================
//  Master G – web release schedule
//
//  ✏️  YOU ONLY EDIT THE TWO DATES BELOW (format 'YYYY-MM-DD', India time).
//      On that date (from 00:00 IST) games.mitrojan.in/play/ switches to
//      the next version by itself. Then deploy (see HOW_TO_DEPLOY.md).
//
//      V1 2.5.0  – live now (Neon Night theme)
//      V2 2.6.0  – Business + Brain Age, Merry Christmas theme
//      V3 2.7.0  – every game, Happy New Year theme, New Year sale
// =====================================================================
window.MASTERG_SCHEDULE = {
  v2: '2026-11-15',
  v3: '2026-12-15',
};

// ---- Do not edit below this line ------------------------------------
window.MasterG = (function () {
  function startOf(day) {
    // Midnight in India (UTC+05:30) of the given date.
    return new Date(day + 'T00:00:00+05:30').getTime();
  }

  // Version that is live right now: 1, 2 or 3.
  function liveVersion(now) {
    var s = window.MASTERG_SCHEDULE;
    var t = now || Date.now();
    if (t >= startOf(s.v3)) return 3;
    if (t >= startOf(s.v2)) return 2;
    return 1;
  }

  // Preview: open /play/?preview=2 (or 3) to test a version before its date.
  // The choice is kept only for this browser tab.
  function previewVersion() {
    try {
      var m = location.search.match(/[?&]preview=([123])/);
      if (m) sessionStorage.setItem('mg_preview', m[1]);
      var v = sessionStorage.getItem('mg_preview');
      return v ? Number(v) : null;
    } catch (e) {
      return null;
    }
  }

  return {
    liveVersion: liveVersion,
    // The version this visitor should get.
    version: function () {
      return previewVersion() || liveVersion();
    },
  };
})();
