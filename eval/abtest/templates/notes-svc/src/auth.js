'use strict';

// Bearer-token check shared by every route.
const USERS = { 'tok-alice': 'alice', 'tok-bob': 'bob' };

// Returns the user name for a valid `Authorization: Bearer <token>` header,
// or null.
function requireUser(req) {
  const header = req.headers.authorization || '';
  const match = /^Bearer (\S+)$/.exec(header);
  if (!match) return null;
  return Object.hasOwn(USERS, match[1]) ? USERS[match[1]] : null;
}

module.exports = { requireUser, USERS };
