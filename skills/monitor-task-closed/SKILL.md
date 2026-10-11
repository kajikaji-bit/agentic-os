---
name: monitor-task-closed
description: steering のタスクのクローズを監視し、検出したイベントを通知する。「タスクのクローズを監視して」と言われたときに使う。
---

# Monitor Task Closed

前提: `HERDR_ENV=1` と Bash 4.3 以降、Herdr が使える。

## 手順

1. 観測と通知先を決める
2. monitor タブで起動する
3. 検出したイベントを通知する

### 1. 観測と通知先を決める

[herdr](../herdr/SKILL.md) に従い、この会話の Herdr セッション名とエージェントの `pane_id` を特定する。環境変数の ID が古い場合は `agent list` と `pane read` で照合する。監視する対象、ジョブを区別する名前、検知時の通知文を決める。

`workspace/*/*/*/state` が `closed` のタスクを観測する。起動時点でクローズ済みのタスクも通知する。その後は前回 closed でなかったタスクが closed になったときに通知する。

### 2. monitor タブで起動する

同じワークスペースの `monitor` タブのシェルを使う。なければ作り、返された `.result.root_pane.pane_id` を起動先とする。

```bash
herdr --session <セッション名> tab list --workspace <ワークスペースID>
herdr --session <セッション名> tab create --workspace <ワークスペースID> --label monitor --cwd <プロジェクトの絶対パス> --no-focus
```

次の値を埋め、`herdr --session <セッション名> pane run <monitorペインID> <起動コマンド>` で、そのシェルへ送る。パスや通知文はシェル引数として引用する。

```bash
bash '<このスキルの絶対パス>/scripts/monitor.sh' \
  '<Herdr セッション名>' '<通知先 pane_id>' 'tasks-closed' \
  '<workspace ディレクトリ>' \
  'クローズされたタスクを確認してください。' &
monitor_pid=$!
```

引数は順にセッション名、通知先、監視名、対象、通知文。対象は絶対パスで渡す。 対象ごとにジョブを起動し、監視名と PID を保存する変数を分ける。標準出力はリダイレクトしない。既定は60秒間隔で、変更する場合は起動コマンドの先頭に `MONITOR_INTERVAL=10` のように付ける。

停止するときは `monitor` タブの同じシェルで実行する。

```bash
jobs -l
kill "$monitor_pid"
```

### 3. 検出したイベントを通知する

起動時に `event=started target=... interval=60s`、観測ごとに `event=checked changes=0` のように標準出力へログを出す。イベントを検知したときは `detected count=...` と、送信後の `sent pane=...` も出す。

```text
2026-09-21T11:01:00+09:00 INFO monitor=tasks-closed event=checked changes=0
```

起動時の通知文と観測結果を次の形式にし、`herdr --session <セッション名> agent prompt <pane_id> <メッセージ>` で一度送る。応答完了を待つ `--wait` は付けない。

```text
[monitor:tasks-closed]
指示: クローズされたタスクを確認してください。
観測:
- 検出した対象
```

通知後も監視を続ける。通知ID、再試行、通知先の消失検知は設けない。イベントの扱いは使用者に委ねる。
