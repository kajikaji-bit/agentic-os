---
name: monitor-commits
description: 指定したパスへの変更のコミットを監視し、検出したイベントを通知する。「カタログの変更を監視して」「このディレクトリーへのコミットを監視して」と言われたときに使う。
---

# Monitor Commits

前提: `HERDR_ENV=1`、Bash、Git、Herdr が使え、対象リポジトリが `main` を持つリモートを追跡している。

## 手順

1. 観測と通知先を決める
2. monitor タブで起動する
3. 検出したイベントを通知する

### 1. 観測と通知先を決める

[herdr](../herdr/SKILL.md) に従い、この会話の Herdr セッション名とエージェントの `pane_id` を特定する。環境変数の ID が古い場合は `agent list` と `pane read` で照合する。

対象リポジトリの絶対パス、監視する Git の pathspec、ジョブを区別する名前、検知時の通知文を決める。`workspace/` は常に監視対象から除く。

観測ごとにリモートから `main` を取得し、`origin/main` を基準に比較する。ローカルの `main` は、一時 worktree から直接プッシュする経路では進まないため見ない。

起動時の `origin/main` を基準に、以後に入った対象パスのコミットを範囲で比較する。起動以前のコミットは通知せず、古い日時のコミットを取り込んだ場合も検出する。

### 2. monitor タブで起動する

同じワークスペースの `monitor` タブのシェルを使う。なければ作り、返された `.result.root_pane.pane_id` を起動先とする。

```bash
herdr --session <セッション名> tab list --workspace <ワークスペースID>
herdr --session <セッション名> tab create --workspace <ワークスペースID> --label monitor --cwd <プロジェクトの絶対パス> --no-focus
```

次のコマンドの値を埋め、`herdr --session <セッション名> pane run <monitorペインID> <起動コマンド>` で、そのシェルに送る。通知文やパスはシェル引数として引用する。

```bash
bash '<このスキルの絶対パス>/scripts/monitor.sh' \
  '<Herdr セッション名>' '<通知先 pane_id>' 'workflow-commits' \
  '<対象リポジトリの絶対パス>' \
  'ワークフローへの変更のコミットを確認してください。' \
  '.agents/workflows' &
workflow_commits_pid=$!
```

引数は順にセッション名、通知先、監視名、リポジトリ、通知文、1個以上の pathspec。複数の pathspec は末尾に並べる。例えば `':(glob)**/*.template.*' ':(exclude)library'` と指定する。

監視する対象の組ごとにジョブを起動し、名前と PID を保存する変数を分ける。ログはリダイレクトせず標準出力へ出す。既定は60秒間隔。変更する場合は起動コマンドの先頭に `MONITOR_INTERVAL=10` のように付ける。

停止するときは `monitor` タブの同じシェルで実行する。

```bash
jobs -l
kill "$workflow_commits_pid"
```

### 3. 検出したイベントを通知する

起動時と観測ごとにログを出す。変化がない場合も `checked` を出す。

```text
2026-09-21T11:00:00+09:00 INFO monitor=workflow-commits event=started target=/repo interval=60s
2026-09-21T11:01:00+09:00 INFO monitor=workflow-commits event=checked changes=0
2026-09-21T11:02:00+09:00 INFO monitor=workflow-commits event=checked changes=1
2026-09-21T11:02:00+09:00 INFO monitor=workflow-commits event=detected count=1
2026-09-21T11:02:01+09:00 INFO monitor=workflow-commits event=sent pane=w1Q:p1
```

イベントを検知したら、次の書式を `herdr --session <セッション名> agent prompt <pane_id> <メッセージ>` で一度送る。応答完了を待つ `--wait` は付けない。

```text
[monitor:workflow-commits]
指示: ワークフローへの変更のコミットを確認してください。
観測:
- abc1234 ワークフローを更新

.agents/workflows/example.yaml
```

通知後も監視を続ける。通知ID、再試行、通知先の消失検知は設けない。イベントを受けて何をするかは使用者に委ねる。
