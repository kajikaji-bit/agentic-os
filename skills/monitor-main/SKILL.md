---
name: monitor-main
description: リモートの `main` が進んだことを監視し、検出したイベントを通知する。「origin/main が更新されたら教えて」「main の更新を監視して」と言われたときに使う。
---

# Monitor Main

前提: `HERDR_ENV=1`、Bash、Git、Herdr が使え、対象リポジトリが `main` を持つリモートを追跡している。

## 手順

1. 観測と通知先を決める
2. monitor タブで起動する
3. 検出したイベントを通知する

### 1. 観測と通知先を決める

[herdr](../herdr/SKILL.md) に従い、この会話の Herdr セッション名とエージェントの `pane_id` を特定する。環境変数の ID が古い場合は `agent list` と `pane read` で照合する。対象リポジトリの絶対パス、ジョブを区別する名前、検知時の通知文を決める。

観測ごとにリモートから `main` を取得し、`origin/main` が指すコミットが前回から変わったかを見る。パスでは絞らず、入ったコミットすべてを観測結果にする。ローカルの `main` は見ない。

起動時の `origin/main` を基準にし、起動以前のコミットは通知しない。

### 2. monitor タブで起動する

同じワークスペースの `monitor` タブのシェルを使う。なければ作り、返された `.result.root_pane.pane_id` を起動先とする。

```bash
herdr --session <セッション名> tab list --workspace <ワークスペースID>
herdr --session <セッション名> tab create --workspace <ワークスペースID> --label monitor --cwd <プロジェクトの絶対パス> --no-focus
```

次の値を埋め、`herdr --session <セッション名> pane run <monitorペインID> <起動コマンド>` で、そのシェルへ送る。パスや通知文はシェル引数として引用する。

```bash
bash '<このスキルの絶対パス>/scripts/monitor.sh' \
  '<Herdr セッション名>' '<通知先 pane_id>' 'main-updated' \
  '<対象リポジトリの絶対パス>' \
  'ローカルの main を origin/main へ早送りしてください。' &
main_updated_pid=$!
```

引数は順にセッション名、通知先、監視名、リポジトリ、通知文。対象ごとにジョブを起動し、監視名と PID を保存する変数を分ける。標準出力はリダイレクトしない。既定は60秒間隔で、変更する場合は起動コマンドの先頭に `MONITOR_INTERVAL=10` のように付ける。

停止するときは `monitor` タブの同じシェルで実行する。

```bash
jobs -l
kill "$main_updated_pid"
```

### 3. 検出したイベントを通知する

起動時に `event=started target=... interval=60s`、観測ごとに `event=checked changes=0` のように標準出力へログを出す。取得に失敗したときは `event=failed reason=fetch` を出し、監視を続ける。イベントを検知したときは `detected count=...` と、送信後の `sent pane=...` も出す。

```text
2026-09-23T09:01:00+09:00 INFO monitor=main-updated event=checked changes=0
```

起動時の通知文と観測結果を次の形式にし、`herdr --session <セッション名> agent prompt <pane_id> <メッセージ>` で一度送る。応答完了を待つ `--wait` は付けない。

```text
[monitor:main-updated]
指示: ローカルの main を origin/main へ早送りしてください。
観測:
- abc1234 ワークフローを更新
```

通知後も監視を続ける。通知ID、再試行、通知先の消失検知は設けない。イベントの扱いは使用者に委ねる。
