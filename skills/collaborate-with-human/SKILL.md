---
name: collaborate-with-human
description: 左ペインで会話し、右ペインへ資料を出して人間のレビューを受ける。「レビューして欲しい」「見てもらって」と言われたときや、承認・指摘を待つときに使う。
---

# Collaborate With Human

Herdr のペインで会話と資料を分け、Hunk のレビューセッションでコメントをやり取りする。

前提: `HERDR_ENV=1` で、`herdr` と `hunk` が PATH にある。満たさないときは、この手順を使わず会話だけで進める。

## 手順

1. 左ペインで会話し、右ペインへ資料を出す
2. レビューを依頼する
3. レビューコメントを監視する
4. レビューコメントへ対応する

### 1. 左ペインで会話し、右ペインへ資料を出す

まずセッション一覧を取得し、稼働中のセッションごとにワークスペースとエージェントの一覧から候補を絞る。直近のユーザー発言とエージェントの応答がこの会話と一致するペインを選ぶ。

既定の接続先や環境変数のペインIDは、現在の会話と異なるセッションを指す場合がある。一つのセッションで見つからなければ、残りの稼働中セッションも調べる。ペインIDはセッションと組で扱い、以降の Herdr 操作にも選んだ `--session` を指定する。

```bash
herdr session list
herdr --session <候補のセッション名> workspace list
herdr --session <候補のセッション名> agent list
herdr --session <候補のセッション名> pane list --workspace <候補の workspace_id>
herdr --session <候補のセッション名> pane read <候補の pane_id> --source recent-unwrapped --lines 60
```

選んだペインのIDを指定して右隣を取得する。応答の `result.neighbor.neighbor_pane_id` を右ペインIDとして使う。

```bash
herdr --session <選んだセッション名> pane neighbor --direction right --pane <自分の pane_id>
```

右隣が無ければ作る。作成結果の `result.pane.pane_id` を右ペインIDとして使う。

```bash
herdr --session <選んだセッション名> pane split --pane <自分の pane_id> --direction right --ratio 0.5 --cwd <資料のリポジトリ> --no-focus
```

右ペインのプロセスを調べる。

```bash
herdr --session <選んだセッション名> pane process-info --pane <右ペイン ID>
```

シェルの入力待ちなら、資料のリポジトリでHunkを開く。レビュー対象はリポジトリルートからの相対パスで指定する。

```bash
herdr --session <選んだセッション名> pane run <右ペイン ID> 'hunk diff -- <対象パス1> <対象パス2>'
```

右ペインのHunkプロセスのPIDと、セッション一覧の `pid` を照合して `sessionId` を取得する。Hunkを新しく開いた場合はプロセス情報を再取得する。

```bash
herdr --session <選んだセッション名> pane process-info --pane <右ペイン ID>
hunk session list --json
```

以降の表示・注記・監視には、そのセッションIDを使う。表示と再読み込みには同じ対象パスを指定し、レビュー対象に絞る。

```bash
hunk session reload <右ペインの sessionId> -- diff [ref] -- <対象パス1> <対象パス2>
```

### 2. レビューを依頼する

見てほしい場所へ右ペインの視点を寄せる。

```bash
hunk session navigate <右ペインの sessionId> --file <path> --hunk 1
```

読み手が資料だけでは気づけない点があるときに限り、注記を残す。

```bash
hunk session comment add <右ペインの sessionId> --file <path> --new-line <n> --summary '<見てほしい理由>'
```

左ペインでは、右ペインに出したもの、見てほしい場所、判断してほしいことを述べてターンを終える。

### 3. レビューコメントを監視する

[monitor-hunk-comments](../monitor-hunk-comments/SKILL.md) に従い、`monitor` タブで右ペイン用の専用シェルスクリプトをバックグラウンド起動する。通知先は会話中のエージェントの `pane_id` とする。通知文には、コメントを読み、このスキルの手順 4 で対応することを指定する。

表示を切り替えたら右ペイン用のジョブだけを停止し、新しい Hunk セッションで起動し直す。観測ログは `monitor` タブへ出し続け、コメントが増えたら Herdr から会話へ通知する。起動時点の既存コメントは起動前に読んで対応する。

### 4. レビューコメントへ対応する

1 件ずつ、位置を右ペインへ映してから読む。

```bash
hunk session navigate <右ペインの sessionId> --next-comment
```

直したら資料を最新にし、対応した注記を消す。

```bash
hunk session reload <右ペインの sessionId> -- diff -- <対象パス1> <対象パス2>
hunk session comment rm <右ペインの sessionId> <noteId>
```

消すときに渡す値は、`comment list` の `noteId` (`comment add` が返す `commentId` と同じ値)である。

直さないと決めた注記は消さず、理由を左ペインで述べて判断を仰ぎ、手順 3 へ戻る。

すべての注記が消えたら、直したことを左ペインでまとめて次の判断を仰ぐ。
