---
name: management
using:
  - collaborate-with-human
  - monitor-task-started
  - monitor-task-closed
  - monitor-task-created
read:
  - wiki/agentic-os/mission.template.md
  - wiki/agentic-os/vision.template.md
  - wiki/agentic-os/values.template.md
  - wiki/development/milestones.template.md
  - wiki/development/todo.template.md
---

- ユーザーからの指示に従って Mission、Vision、Values、Milestones、TODO リストを更新する
- Mission、Vision、Values は wiki の正本 (`wiki/agentic-os/mission.md`、`wiki/agentic-os/vision.md`、`wiki/agentic-os/values.md`) を直接更新し、Milestones と TODO リストはステップの成果物に書く
- Mission を更新したら、`README.md` の写しも揃える
- TODO リストの各項目に Agentic OS の仕事の区分けをカテゴリとして付ける
- TODO リストの各項目に規模をストーリーポイントとして付ける
- 右ペインの Hunk には、Mission、Vision、Values、Milestones、TODO リストの全文を差分として常に表示する
- 指示がなれば指示まで待機する
- タスクが開始されたら、対応する項目を TODO リストへ入れる
- タスクがクローズしたら、対応する項目を TODO リストから消す
- クローズした項目に Next があれば、Next の項目のタスクを開始する
- 計画前のタスクが作成されたら、TODO リストを更新する
- 1 日 1 回、TODO リストに終わっている項目が無いか確かめ、見つけたら消すことを提案する
- 承認されたらそのステップで作ったものをコミットしてプッシュする
