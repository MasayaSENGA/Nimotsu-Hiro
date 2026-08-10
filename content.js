/*
 * にもつひろ
 * Google 検索のクエリが追跡番号に見えるとき、各運送会社の追跡ページへのリンクを差し込む。
 */
(function () {
  'use strict';

  const CONTAINER_ID = 'nimotsu-hiro';
  const TARGET_SELECTORS = ['#rcnt', '#center_col', 'main'];
  const TARGET_WAIT_MS = 5000;
  const TARGET_POLL_MS = 100;

  const CARRIERS = {
    yamato: {
      name: 'ヤマト運輸',
      modifier: 'nimotsu-hiro-link--yamato',
      url: (no) =>
        'https://jizen.kuronekoyamato.co.jp/jizen/servlet/crjz.b.NQ0010?id=' +
        encodeURIComponent(no)
    },
    sagawa: {
      name: '佐川急便',
      modifier: 'nimotsu-hiro-link--sagawa',
      url: (no) =>
        'https://k2k.sagawa-exp.co.jp/p/web/okurijosearch.do?okurijoNo=' +
        encodeURIComponent(no)
    },
    japanpost: {
      name: '日本郵便',
      modifier: 'nimotsu-hiro-link--japanpost',
      url: (no) =>
        'https://trackings.post.japanpost.jp/services/srv/search/direct' +
        '?searchKind=S003&locale=ja&SVID=023&reqCodeNo1=' +
        encodeURIComponent(no)
    }
  };

  /**
   * 全角数字・全角英字を半角に変換し、ハイフンと空白を除去する。
   */
  const normalize = (input) =>
    input
      .replace(/[Ａ-Ｚａ-ｚ０-９]/g, (c) =>
        String.fromCharCode(c.charCodeAt(0) - 0xfee0)
      )
      .replace(/[-‐‑–—ー\s]/g, '')
      .trim()
      .toUpperCase();

  /**
   * 12桁のモジュラス7チェックディジット検証。
   * 先頭11桁を数値として7で割った余りが末尾1桁と一致する（ヤマト運輸・佐川急便）。
   * 11桁は最大 99,999,999,999 で Number.MAX_SAFE_INTEGER 未満のため精度上の問題はない。
   */
  const isValidMod7 = (no) =>
    /^\d{12}$/.test(no) && Number(no.slice(0, 11)) % 7 === Number(no[11]);

  /**
   * 追跡番号らしき文字列から、該当しうる運送会社のキー配列を返す。
   * 該当なしなら空配列（＝何も表示しない）。
   *
   * - ヤマト運輸  : 12桁 + モジュラス7
   * - 佐川急便    : 10〜14桁。12桁のときだけモジュラス7を適用する
   * - 日本郵便    : 国内 11〜13桁 / 国際 S10形式（例 EM123456789JP）。チェックディジットなし
   */
  const detectCarriers = (value) => {
    // 日本郵便の国際郵便（S10形式）
    if (/^[A-Z]{2}\d{9}JP$/.test(value)) return ['japanpost'];

    if (!/^\d{10,14}$/.test(value)) return [];

    const length = value.length;
    const mod7 = length === 12 ? isValidMod7(value) : null;
    const carriers = [];

    if (mod7 === true) carriers.push('yamato');
    if (mod7 === true || mod7 === null) carriers.push('sagawa');
    if (length >= 11 && length <= 13) carriers.push('japanpost');

    return carriers;
  };

  /**
   * 挿入先の要素を待つ。Google の描画完了タイミングは一定ではないため、
   * 固定の setTimeout ではなく実際に要素が現れるまでポーリングする。
   */
  const waitForTarget = () =>
    new Promise((resolve) => {
      const deadline = Date.now() + TARGET_WAIT_MS;

      const attempt = () => {
        for (const selector of TARGET_SELECTORS) {
          const element = document.querySelector(selector);
          if (element) return resolve(element);
        }
        if (Date.now() >= deadline) return resolve(null);
        setTimeout(attempt, TARGET_POLL_MS);
      };

      attempt();
    });

  const buildCard = (trackingNo, carrierKeys) => {
    const container = document.createElement('div');
    container.id = CONTAINER_ID;

    const title = document.createElement('div');
    title.className = 'nimotsu-hiro-title';

    const icon = document.createElement('span');
    icon.setAttribute('aria-hidden', 'true');
    icon.textContent = '📦 ';
    title.appendChild(icon);
    title.appendChild(
      document.createTextNode(`にもつひろ ｜ 伝票番号「${trackingNo}」`)
    );
    container.appendChild(title);

    const buttons = document.createElement('div');
    buttons.className = 'nimotsu-hiro-buttons';

    carrierKeys.forEach((key) => {
      const carrier = CARRIERS[key];
      const a = document.createElement('a');
      a.href = carrier.url(trackingNo);
      a.target = '_blank';
      // 逆タブナビング対策と、検索クエリ（＝伝票番号）のリファラ送出防止
      a.rel = 'noopener noreferrer';
      a.className = `nimotsu-hiro-link ${carrier.modifier}`;
      a.textContent = carrier.name;
      a.setAttribute('aria-label', `${carrier.name}で${trackingNo}を追跡する`);
      buttons.appendChild(a);
    });

    container.appendChild(buttons);
    return container;
  };

  const removeCard = () => {
    const existing = document.getElementById(CONTAINER_ID);
    if (existing) existing.remove();
  };

  let renderToken = 0;

  const render = async () => {
    // 非同期処理の競合で古い結果が後から描画されるのを防ぐ
    const token = ++renderToken;

    const query = new URLSearchParams(window.location.search).get('q');
    const trackingNo = query ? normalize(query) : '';
    const carrierKeys = trackingNo ? detectCarriers(trackingNo) : [];

    // 表示条件を満たさない場合は既存のカードを片付けて終了
    if (carrierKeys.length === 0) {
      removeCard();
      return;
    }

    const target = await waitForTarget();
    if (token !== renderToken || !target) return;

    // 早期 return せず作り直すことで、別の番号を検索したときに表示が更新される
    removeCard();
    target.prepend(buildCard(trackingNo, carrierKeys));
  };

  render();

  // 検索結果はページ遷移なしで書き換わるため、URL の変化を監視して再描画する
  if (window.navigation && typeof window.navigation.addEventListener === 'function') {
    window.navigation.addEventListener('navigate', () => {
      // ナビゲーション確定後に読み直す
      setTimeout(render, 0);
    });
  } else {
    // Navigation API 非対応環境向けのフォールバック。
    // document 全体の監視はコストが高いため、URL 比較のみに絞りデバウンスする。
    let lastUrl = location.href;
    let scheduled = false;

    new MutationObserver(() => {
      if (scheduled || location.href === lastUrl) return;
      lastUrl = location.href;
      scheduled = true;
      requestAnimationFrame(() => {
        scheduled = false;
        render();
      });
    }).observe(document.body, { subtree: true, childList: true });
  }
})();
