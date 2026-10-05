# プライバシーポリシー（にもつひろ）

制定日：2026年10月5日
最終更新日：2026年10月5日

このプライバシーポリシーは、Chrome 拡張機能「にもつひろ」（以下「本拡張機能」）における情報の取り扱いについて説明するものです。本拡張機能のバージョン 2.0 以降に適用されます。日本語版と英語版で内容に相違がある場合は、日本語版が優先されます。

[English version is below.](#privacy-policy-nimotsu-hiro)

## 1. まとめ

- 本拡張機能が読み取るのは、Google 検索の結果ページの URL に含まれる検索語だけです。伝票番号かどうかの判定は、お使いのブラウザの中だけで行います。
- 検索語や伝票番号を保存することはなく、本拡張機能が開発者や第三者に送信することもありません。開発者が利用者の情報を受け取ることはありません。
- カードのボタンを押したときだけ、追跡ページを開くために、伝票番号がページの URL の一部として運送会社に渡ります（第 5 項）。
- アクセス解析、広告、Cookie、トラッキングの仕組みは一切使用していません。

## 2. 本拡張機能が読み取る情報と、その使い道

本拡張機能は、次の URL パターンに一致するページでのみ動作します。

- `https://www.google.com/search*`
- `https://www.google.co.jp/search*`

これらのパターンに一致するのは、www.google.com と www.google.co.jp のページのうち、URL のパス（ドメイン名に続く部分）が「/search」で始まるもので、Google 検索の結果ページがこれに当たります。これ以外のサイトやページでは動作しません。

これらのページで本拡張機能が読み取るのは、表示中のページ URL の `q` パラメーター（検索語）だけです。ページの URL は閲覧中のページに関する情報にあたるため、その使い道を以下に明記します。

読み取った検索語は、全角英数字を半角にそろえ、ハイフンやダッシュ類（全角の「－」を含む）、空白を取り除いたうえで、宅配便・郵便物の伝票番号（追跡番号）の形式に当てはまるかどうかを判定するためだけに、ブラウザの中で一時的に使います。当てはまる場合は、その番号の追跡リンクを並べたカードを、検索結果の先頭に 1 つ表示します。当てはまらない場合は何もしません。

- 判定はブラウザ内のメモリ上で行うだけで、検索語や伝票番号をどこにも記録しません。カードは表示中のページの中にだけ存在し、別の語句で検索し直したりページを閉じたりすると消えます。
- 検索結果ページの中で検索し直したときは、新しい URL の検索語を同じように読み取り、カードを更新または削除します。
- カードを挿入する場所を決めるために、検索結果の領域にあたる要素がページ内にあるかどうかを確認します。ただし、検索結果の本文やページ上のその他の情報を読み取ることはありません。

## 3. 本拡張機能が行わないこと

- 検索語、伝票番号、閲覧履歴、ページの内容、個人を特定できる情報などを、記録したり蓄積したりすることはありません。
- `chrome.storage`、`localStorage`、IndexedDB、Cookie などへの保存は行いません。
- 本拡張機能自体はネットワーク通信を一切行わず、開発者や第三者のサーバーに情報を送信しません（ボタンを押したときの運送会社のページへの移動については第 5 項をご覧ください）。
- 情報の販売、第三者への提供・共有、広告目的での利用、信用力の判断や融資を目的とした利用は行いません。
- アクセス解析ツール、広告、トラッキング技術は組み込んでいません。
- 外部から取得したプログラム（リモートコード）は実行しません。処理はすべて、拡張機能のパッケージに含まれるコードだけで行います。

## 4. 権限について

本拡張機能は、`manifest.json` で `permissions`（タブ、閲覧履歴、ストレージ、ダウンロード、Cookie など）を一切宣言していません。ブラウザに求めるアクセスは、第 2 項の URL パターンに一致するページでコンテンツスクリプト（`content.js` と `content.css`）を実行することだけです。

Chrome に追加するときの確認画面には、「www.google.com 上にあるデータの読み取りと変更」という趣旨の表示が出ます。これは特定のサイトでコンテンツスクリプトを実行する拡張機能に対して Chrome が表示するものです。Chrome はサイト名（ホスト名）だけを表示し、末尾のドメイン（.com や .co.jp など）だけが違うサイト名は 1 つにまとめます。このため、www.google.co.jp は www.google.com の表示にまとめられて別には表示されず、URL の「/search」による絞り込みも表示には反映されません。本拡張機能が実際に行うのは、第 2 項に記載した検索語の読み取りと、カードの追加だけです。

## 5. 運送会社のサイトへのリンク（外部サイト）

カードのボタンを押すと、運送会社（ヤマト運輸、佐川急便、日本郵便）の追跡ページが新しいタブで開きます。

- これは利用者の操作による通常のページ移動です。ボタンが押される前に、本拡張機能が運送会社のサイトにアクセスすることはありません。
- 開くページの URL には、照会のために伝票番号が含まれます。そのため、ボタンを押すと、伝票番号はその運送会社に渡ります。これは追跡ページを開くという本拡張機能の目的どおりの動作です。あわせて、IP アドレスやブラウザの種類など、通常のウェブサイト閲覧と同じ情報がその運送会社に届きます。
- リンクには `rel="noopener noreferrer"` を指定しています。このため、Google 検索の結果ページの URL（検索語を含む）がリファラ（参照元）として運送会社に送られることはありません。
- 運送会社のサイトでの情報の取り扱いには、各社のプライバシーポリシーが適用されます。これらのサイトでの取り扱いは、本ポリシーの対象外です。

## 6. Google および Chrome ウェブストアについて

- Google 検索の利用に伴う情報の取り扱いには、Google のプライバシーポリシーが適用されます。本拡張機能が Google に情報を送信することはありません。
- 本拡張機能のインストールや自動更新は、Chrome と Chrome ウェブストアの仕組みによって行われます。その際の情報の取り扱いには、Google のプライバシーポリシーが適用されます。

## 7. お子さまの情報

本拡張機能は、お子さまを含め、どなたの個人情報も記録したり、開発者や第三者に送信したりしません。

## 8. Chrome ウェブストアのポリシーへの準拠

本拡張機能による情報の取り扱いは、Chrome ウェブストアのユーザーデータに関するポリシー（Limited Use〔使用制限〕要件を含む）に準拠しています。

## 9. 本ポリシーの変更

本ポリシーを変更する場合は、このページを更新し、冒頭の最終更新日を改めます。変更の履歴は、GitHub リポジトリのコミット履歴でも確認できます。

情報の取り扱い方法を変更する場合（たとえば、情報を保存したり、外部に送信したりするようになる場合）は、その変更を含むバージョンを公開する前に、このページと Chrome ウェブストアの掲載情報でその内容を明示し、必要な場合は拡張機能の中で同意をいただきます。

## 10. お問い合わせ

本ポリシーや本拡張機能に関するご質問は、次のいずれかの方法でお寄せください。

- GitHub の Issues：https://github.com/MasayaSENGA/Nimotsu-Hiro/issues （投稿には GitHub のアカウントが必要です）
- Chrome ウェブストアの「にもつひろ」のページに表示されている、デベロッパーの連絡先メールアドレス

Issues に書き込んだ内容は、だれでも閲覧できます。実際の伝票番号や、氏名・住所などの個人情報は書き込まないでください。画面の画像を添付する場合も、これらが写らないようにしてください。

開発者：Masaya Senga

## 11. 商標と非提携について

本拡張機能は個人が開発した非公式の拡張機能です。ヤマト運輸株式会社、佐川急便株式会社、日本郵便株式会社および Google LLC とは関係がなく、各社から承認・提携・推奨を受けたものではありません。追跡情報は各社のウェブサイトで提供されます。Google 検索および Chrome は Google LLC の商標です。その他の会社名・サービス名は、各社の商標または登録商標です。

---

# Privacy Policy (Nimotsu-Hiro)

Effective date: October 5, 2026
Last updated: October 5, 2026

This privacy policy explains how the Chrome extension "Nimotsu-Hiro" (にもつひろ, "the Extension") handles information. It applies to version 2.0 and later. If the Japanese and English versions differ, the Japanese version prevails.

## 1. Summary

- The only thing the Extension reads is the search terms in the URL of a Google Search results page. Whether they look like a tracking number is decided entirely inside your browser.
- The search terms and tracking numbers are never stored, and the Extension never sends them to the developer or any third party. The developer receives no information about you.
- Only when you click a button on the card is the tracking number passed to the carrier, as part of the URL of its tracking page (see section 5).
- It uses no analytics, ads, cookies or tracking of any kind.

## 2. What the Extension reads, and why

The Extension runs only on pages that match the following URL patterns.

- `https://www.google.com/search*`
- `https://www.google.co.jp/search*`

These patterns match pages on www.google.com and www.google.co.jp whose URL path (the part after the domain name) starts with "/search", which is where Google Search results pages are. The Extension does not run on any other site or page.

On these pages, the Extension reads only the `q` parameter (the search terms) of the current page URL. Because the page URL is information about the page you are viewing, how it is used is stated explicitly below.

The Extension converts full-width letters and digits to half-width, removes hyphens and dashes (including the full-width hyphen "－") and spaces, and uses the result temporarily, inside your browser, only to decide whether it matches the format of a Japanese parcel or postal tracking number. If it does, the Extension adds one card with tracking links for that number at the top of the search results. If it does not, the Extension does nothing.

- The check runs in your browser's memory, and the search terms and tracking number are not recorded anywhere. The card exists only on the page you are viewing and disappears when you search for something else or close the page.
- When you search again from the results page, the Extension reads the search terms of the new URL in the same way and updates or removes the card.
- To decide where to insert the card, the Extension checks whether the element that holds the search results exists on the page. It does not read the text of the search results or any other information on the page.

## 3. What the Extension does not do

- It does not record or accumulate any information, such as search terms, tracking numbers, browsing history, page content or personally identifiable information.
- It does not store anything in `chrome.storage`, `localStorage`, IndexedDB, cookies or any other storage.
- The Extension itself makes no network requests and sends no information to the developer's or any third party's servers (for the navigation to a carrier's page when you click a button, see section 5).
- It does not sell, transfer or share information with third parties, use it for advertising, or use it to determine creditworthiness or for lending purposes.
- It contains no analytics tools, ads or tracking technologies.
- It does not run remotely hosted code. All processing is done by code included in the Extension's package.

## 4. Permissions

The Extension declares no `permissions` in `manifest.json` (no tabs, history, storage, downloads, cookies or the like). The only access it asks the browser for is to run a content script (`content.js` and `content.css`) on pages that match the URL patterns in section 2.

When you add the Extension, Chrome's confirmation dialog says roughly "Read and change your data on www.google.com". Chrome shows this for any extension that runs content scripts on specific sites. It lists only site names (host names) and shows names that differ only in the domain ending (such as .com and .co.jp) as one. As a result, www.google.co.jp is covered by www.google.com instead of being listed separately, and the "/search" restriction in the URL patterns is not reflected in the wording. What the Extension actually does is limited to reading the search terms and adding the card, as described in section 2.

## 5. Links to carrier websites (third-party sites)

When you click a button on the card, the tracking page of the carrier (Yamato Transport, Sagawa Express or Japan Post) opens in a new tab.

- This is an ordinary navigation that you start. The Extension does not access any carrier's website before you click a button.
- The URL of the page that opens contains the tracking number so that the carrier can look it up. When you click a button, the tracking number is therefore passed to that carrier. This is the intended function of the Extension. As with any website visit, the carrier also receives standard information such as your IP address and browser type.
- The links use `rel="noopener noreferrer"`, so the URL of your Google Search results page (which contains your search terms) is not sent to the carrier as the referrer.
- Information handled on a carrier's website is governed by that carrier's privacy policy and is outside the scope of this policy.

## 6. Google and the Chrome Web Store

- Google's privacy policy applies to information handled when you use Google Search. The Extension does not send any information to Google.
- Installation and automatic updates of the Extension are handled by Chrome and the Chrome Web Store. Google's privacy policy applies to the information handled in that process.

## 7. Children

The Extension does not record personal information of anyone, including children, or send it to the developer or any third party.

## 8. Compliance with Chrome Web Store policies

Nimotsu-Hiro's handling of data complies with the Chrome Web Store User Data Policy, including the Limited Use requirements.

## 9. Changes to this policy

If this policy changes, this page will be updated together with the "Last updated" date above. The history of changes can also be seen in the commit history of the GitHub repository.

If the way the Extension handles information changes (for example, if it starts to store information or send it outside your browser), the change will be clearly disclosed on this page and in the Chrome Web Store listing before a version with that change is published, and your consent will be requested within the Extension where required.

## 10. Contact

Please send questions about this policy or the Extension in either of the following ways.

- GitHub Issues: https://github.com/MasayaSENGA/Nimotsu-Hiro/issues (a GitHub account is required to post)
- The developer contact email address shown on the Nimotsu-Hiro page in the Chrome Web Store

Anything you post in Issues can be read by anyone. Please do not include real tracking numbers or personal information such as your name or address, and make sure they do not appear in any screenshots you attach.

Developer: Masaya Senga

## 11. Trademarks and non-affiliation

Nimotsu-Hiro is an unofficial extension developed by an individual. It is not affiliated with, authorized or endorsed by Yamato Transport Co., Ltd., SAGAWA EXPRESS CO., LTD., JAPAN POST Co., Ltd. or Google LLC. Tracking information is provided on each carrier's website. Google Search and Chrome are trademarks of Google LLC. Other company and service names are trademarks or registered trademarks of their respective owners.
