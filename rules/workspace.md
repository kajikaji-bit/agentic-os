---
name: workspace
using:
  - herdr
  - monitor-hunk-comments
---

- 作業用ディレクトリは `workspace/<YYYY>/<YYYYMM>/<タスク ID>/` に置き、作ったあとは動かさない
- worktree のパスは `workspace/<YYYY>/<YYYYMM>/<タスク ID>/worktrees/<リポジトリ名>/` とする
- Herdr タブは左から `main` / `plan` / `yazi` / `workspace` / `<リポジトリ名>` とする
  - `main` … エージェントとの会話（cwd は `~/dev`）。右ペインはレビュー・確認用
  - `plan` … 左ペインに `.agents/` を表示。右ペインは現在のワークスペースの `workflow.yaml`
  - `yazi` … 作業用ディレクトリを表示
  - `workspace` … 作業用ディレクトリ
  - `<リポジトリ名>` … 対応する worktree（一対一）
- 監視するときは同じワークスペースに `monitor` タブを追加し、監視対象ごとのバックグラウンドジョブと標準出力のログを置く
- worktree を作成したとき、規約どおりにパスとタブを追加し、全差分を表示し、監視対象に足す
- 右ペインに Hunk を出したとき、または表示を切り替えたとき、右ペインの監視を起動し直す
