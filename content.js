(function() {
  const insertTrackingLinks = () => {
    // すでに表示済みの場合は重複させない
    if (document.getElementById('tracking-quick-links')) return;

    const urlParams = new URLSearchParams(window.location.search);
    const query = urlParams.get('q');
    if (!query) return;

    const cleanId = query.replace(/[-\s]/g, '');
    
    // 10〜13桁の数字判定
    if (/^\d{10,13}$/.test(cleanId)) {
      const trackingId = cleanId;
      
      const links = [
        { name: "ヤマト運輸", url: `https://jizen.kuronekoyamato.co.jp/jizen/servlet/crjz.b.NQ0010?id=${trackingId}`, color: "#fee100", textColor: "#000" },
        { name: "佐川急便", url: `https://k2k.sagawa-exp.co.jp/p/web/okurijosearch.do?okurijoNo=${trackingId}`, color: "#004098", textColor: "#fff" },
        { name: "日本郵便", url: `https://trackings.post.japanpost.jp/services/srv/search/direct?searchKind=S003&locale=ja&SVID=023&reqCodeNo1=${trackingId}`, color: "#ff0000", textColor: "#fff" }
      ];

      const container = document.createElement('div');
      container.id = 'tracking-quick-links';
      
      const style = document.createElement('style');
      style.textContent = `
        #tracking-quick-links {
          margin: 15px 0;
          padding: 16px;
          border: 1px solid #dadce0;
          border-radius: 12px;
          background-color: #ffffff;
          box-shadow: 0 1px 6px rgba(32,33,36,0.1);
        }
        .tracking-title { font-weight: bold; margin-bottom: 12px; font-size: 16px; color: #202124; }
        .tracking-btn-group { display: flex; gap: 8px; flex-wrap: wrap; }
        .tracking-link { padding: 10px 20px; border-radius: 8px; text-decoration: none; font-size: 14px; font-weight: bold; transition: opacity 0.2s; }
        .tracking-link:hover { opacity: 0.8; }
        @media (prefers-color-scheme: dark) {
          #tracking-quick-links { background-color: #202124; border-color: #3c4043; box-shadow: 0 1px 6px rgba(0,0,0,0.3); }
          .tracking-title { color: #e8eaed; }
        }
      `;
      document.head.appendChild(style);

      const title = document.createElement('div');
      title.className = 'tracking-title';
      title.innerText = `📦 伝票番号「${trackingId}」`;
      container.appendChild(title);

      const linkWrapper = document.createElement('div');
      linkWrapper.className = 'tracking-btn-group';

      links.forEach(link => {
        const a = document.createElement('a');
        a.href = link.url;
        a.target = '_blank';
        a.className = 'tracking-link';
        a.innerText = link.name;
        a.style.backgroundColor = link.color;
        a.style.color = link.textColor;
        linkWrapper.appendChild(a);
      });

      container.appendChild(linkWrapper);

      // 挿入場所候補を複数用意（Googleの仕様変更対策）
      const target = document.querySelector('#rcnt') || document.querySelector('#center_col') || document.querySelector('main');
      if (target) {
        target.prepend(container);
      }
    }
  };

  // 初回実行
  insertTrackingLinks();

  // 検索結果が動的に書き換わった際（URLが変わった時）にも再実行
  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      setTimeout(insertTrackingLinks, 500); // 描画待ち
    }
  }).observe(document, {subtree: true, childList: true});
})();