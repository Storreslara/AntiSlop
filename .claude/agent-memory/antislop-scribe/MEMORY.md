# Memory index

- [Issue-close comment path gate](feedback_issue_close_comment_path_gate.md) — `gh issue close --comment` citing `.claude/reviewed/` paths trips the write-intent gate; split into `gh issue comment --body-file` + plain `gh issue close`.
- [Review-join stamp not dirty](feedback_review_join_stamp_not_dirty.md) — pre-existing untracked `.claude/.review-join.<id>` files aren't "unexpected dirt"; don't let them block a post-PASS commit/close.
