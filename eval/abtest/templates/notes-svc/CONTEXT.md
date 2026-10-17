# notes-svc glossary

**note**: one titled entry owned by one user, with an id, a body and a creation time.
_Avoid_: item, record, memo.

**owner**: the user whose bearer token created a note; the HTTP routes show a note only to its owner.
_Avoid_: author, account.

**filter**: a JavaScript expression over `note` that selects notes in the store's `query`.
_Avoid_: predicate string.
