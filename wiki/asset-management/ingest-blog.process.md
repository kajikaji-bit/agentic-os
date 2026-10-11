# ingest-blog

ブログ記事、技術記事、記事形式の Web ページに使う。

## 出力

```text
library/blog/
├── <slug>.md
├── <slug>-ja.md
└── images/
    ├── <slug>-hero.png
    └── <slug>-architecture.png
```

## 手順

1. 記事を取得し、本文全体を Markdown として抽出する。
   タイトル、著者、日付、見出し、リスト、コードブロックを残す。ナビゲーション、サイドバー、フッター、Cookie バナー、無関係なおすすめは除く。
2. タイトルか URL から slug を決める。
   3〜8 語にする。主題が分かるようにする。
3. 原文の Markdown を `library/blog/<slug>.md` に保存する。
4. 先頭にメタデータを置く:

```markdown
# Article Title

- **Source:** <original URL>
- **Authors:** <authors>
- **Date:** YYYY-MM-DD
- **Categories:** <categories if available>

---
```

5. 本文の画像だけを特定する。
   ナビゲーション、ヘッダー、フッター、アイコン、トラッキング、アバターの画像は除く。
6. 本文の画像を `library/blog/images/` にダウンロードする。
   画像名は記事の slug を使う。例: `<slug>-hero.png`。
7. 記事の該当位置に画像参照を挿入する。
   ダウンロードに失敗したら、その画像はスキップし壊れた参照を消す。
8. `library/blog/<slug>-ja.md` を作る。
   ソース URL は同一にし、`原文` とラベルを付け、同じ画像パスを共有する。

## 日本語訳のルール

- `enum`、`config-as-code`、`API`、製品名などの技術用語は、自然な場合はそのまま残す。
- 役割名やドメイン固有の概念は、助けになる場合は原語を括弧で添える: `探索者（Explorer）`。
- 自然な日本語で書く。読みやすさを損なう逐語訳は避ける。
- コードブロックはそのまま残す。ただしブロック内の散文が解説テキストの場合は訳す。

## 完了報告

次を報告する。

- 原文ファイルのパス
- 日本語ファイルのパス
- ダウンロードした画像の数
- スキップした画像や欠けているメタデータ
