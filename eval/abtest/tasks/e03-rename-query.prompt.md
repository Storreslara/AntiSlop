Refactor: replace `store.query(filterString)` with
`store.where(predicate)`, where `predicate` is a function
`(note) => boolean`. Remove the string-based query entirely and update
every caller in the repository so behaviour is unchanged. Keep the
public CLI and HTTP behaviour identical. Run `npm test` before you
finish.
