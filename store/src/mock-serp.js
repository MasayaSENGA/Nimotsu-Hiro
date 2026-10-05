// モック検索結果ページの表示だけを担当する（伝票番号の判定は content.js が行う）。
(function () {
  'use strict';
  var params = new URLSearchParams(window.location.search);
  var query = params.get('q') || '';

  document.getElementById('mock-query').textContent = query;
  document.title = query ? query + ' - 検索（モック）' : document.title;

  if (params.get('bare') === '1') {
    document.documentElement.classList.add('is-bare');
  }

  // col=<px> で検索結果カラム（＝カード）の幅を変える。狭い枠に収めたいとき用
  var col = parseInt(params.get('col'), 10);
  if (col >= 320 && col <= 800) {
    document.documentElement.style.setProperty('--col', col + 'px');
  }
})();
