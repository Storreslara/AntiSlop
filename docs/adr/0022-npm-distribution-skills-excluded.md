# ADR-0022: npm Distribution — Skills Excluded

**Status:** Decided (unit #137, 2026-08-15)

**Decision:** The `package.json` `files` array intentionally ships only 2 of 17 skills: `skills/coding-discipline` and `skills/install-antislop`. All other skills are excluded from the npm package.

**Rationale:**

Vendored skills (mattpocock/skills, project-owned optional skills) are distributed via the **git/marketplace path**, not npm:
- The plugin marketplace (`/plugin install antislop@antislop-marketplace`) delivers the full `.claude/` directory structure, including all skills
- A git clone (`git clone https://github.com/Storreslara/AntiSlop.git`) delivers the full `skills/` tree
- The npm package (`npm install antislop`) is a zero-cost installation path intended only for the `bin/cli.js` scaffolding script and its immediate dependencies

The two included skills (`coding-discipline` and `install-antislop`) are the only skills end users interact with **directly and immediately** during initial setup. All other skills are optional, project-specific, and routed through the persona system — they do not execute until a persona is selected and later dispatched. Distributing them via npm would bloat the install footprint without providing value, since users access them via the plugin or git anyway.

**Trade-offs Accepted:**

- Users installing via `npx /path/to/clone` or `npm install antislop` will need to run the full setup (including fetching additional skills) rather than having them pre-cached
- This is acceptable because both paths explicitly invoke `bin/cli.js --update` during setup, which fetches/renders skills as needed

**Related Decisions:**

- [[Skills-library remediation completed]] (CONTEXT.md) — all persona-declared skills now reachable in all modes
- [ADR-0005: Vendor mattpocock/skills](0005-vendor-mattpocock-skills.md) — documents the vendored skills approach
