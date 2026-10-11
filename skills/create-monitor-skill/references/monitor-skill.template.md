---
name: {スキル名}
description: {監視するイベントと起動表現}
---

# {表示名}

前提: `HERDR_ENV=1`、Bash、Herdr、{観測に必要なコマンド}が使える。

## 手順

1. 観測と通知先を決める
2. monitor タブで起動する
3. 検出したイベントを通知する

### 1. 観測と通知先を決める

[herdr](../herdr/SKILL.md) に従い、この会話のセッション名とエージェントの `pane_id` を特定する。監視する対象、ジョブを区別する名前、検知時の通知文を決める。

{監視対象と検出する変化}

{起動時点の対象を通知するかどうか}

### 2. monitor タブで起動する

同じワークスペースの `monitor` タブを使う。なければ `herdr --session <セッション名> tab create --workspace <ワークスペースID> --label monitor --cwd <プロジェクトの絶対パス> --no-focus` で作る。

次の値を埋め、`herdr --session <セッション名> pane run <monitorペインID> <起動コマンド>` で、そのシェルに送る。通知文やパスはシェル引数として引用する。

```bash
bash '<このスキルの絶対パス>/scripts/monitor.sh' \
  '<Herdr セッション名>' '<通知先 pane_id>' '{監視名}' \
  '{監視対象}' '{通知文}' &
monitor_pid=$!
```

監視対象ごとに一つのジョブを起動し、監視名と PID を保存する変数を分ける。標準出力はリダイレクトしない。既定は60秒間隔で、起動コマンドの先頭に `MONITOR_INTERVAL=10` のように付けて変更できる。

停止するときは同じシェルで `kill "$monitor_pid"` を実行する。`jobs -l` でジョブを確認できる。

### 3. 検出したイベントを通知する

起動時に `started`、観測ごとに `checked changes=...`、検知時に `detected count=...`、送信後に `sent pane=...` をログへ出す。変化がない場合も `checked changes=0` を出す。

```text
2026-09-21T11:01:00+09:00 INFO monitor={監視名} event=checked changes=0
```

起動時の指示と観測結果を次の書式で `herdr --session <セッション名> agent prompt <pane_id> <メッセージ>` へ一度渡す。`--wait` は付けない。

```text
[monitor:{監視名}]
指示: {通知文}
観測:
- {観測結果}
```

{通知後も継続するか一度で終了するか}

通知ID、通知先の消失検知、再試行は設けない。イベントの扱いは使用者に委ねる。
