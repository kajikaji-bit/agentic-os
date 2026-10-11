---
name: create-monitor-skill
description: イベントを検出して Herdr 経由で通知するスキルと専用シェルスクリプトをテンプレートから作る。「イベント駆動のスキルを作って」「監視スキルを作って」と言われたときに使う。
---

# Create Monitor Skill

各スキルが自分の `scripts/monitor.sh` を持つ。共通ランタイムへの依存は作らない。

## 手順

1. テンプレートを埋める
2. スキルとスクリプトを書き出す
3. 検出と通知を確かめる

### 1. テンプレートを埋める

- 本文: [monitor-skill.template.md](references/monitor-skill.template.md)
- シェルスクリプト: [monitor-script.template.sh](references/monitor-script.template.sh)

監視対象、検出する変化、起動時点の対象を含めるか、観測間隔、通知文、終了条件を決める。スクリプトの `{}` の箇所に観測と差分検出を入れる。`events` は通知する観測結果の文字列配列にし、各要素は `- ` で始める。

セッション名、通知先の `pane_id`、監視名、対象、通知文を起動引数にする。対象特有の引数は必要なものだけ足す。観測ごとのログとイベント時の Herdr 通知の書式を維持する。

### 2. スキルとスクリプトを書き出す

記入用コメントとプレースホルダを消し、`.agents/skills/<skill-name>/SKILL.md` と `.agents/skills/<skill-name>/scripts/monitor.sh` に保存する。実行には Bash を使う。

`monitor` タブのシェルで対象ごとに `&` で起動し、標準出力へログを流す。停止用に `$!` を保存する。通知ID、通知先の消失検知、再試行は設けない。

### 3. 検出と通知を確かめる

`bash -n` で構文を確認する。一時ディレクトリで対象を変化させ、起動時の扱い、変化がないときのログ、イベント時の通知文、一度通知した変化を再通知しないこと、停止を確認する。送信の検証にはテスト用の `herdr` コマンドを使える。
