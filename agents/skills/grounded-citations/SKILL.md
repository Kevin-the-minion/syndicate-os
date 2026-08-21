---
name: grounded-citations
description: Use when answering with sources — every claim gets a verifiable citation.
---

# Grounded Citations

Every claim you make that can be verified gets a citation. Unverified claims
get labeled as such. This is how the fleet keeps itself honest.

## Rules

1. **Cite the source, not the vibe.** A citation is a path, URL, endpoint,
   commit, or message ID — something the reader can open and check.
2. **One claim, one citation.** No citation ranges that paper over gaps.
3. **If you can't cite it, say so.** "No source found" beats a confident guess.
4. **When reading a file or log, quote the exact line.** `config.yaml:12` beats
   "the config says".
5. **When answering from memory, distinguish memory from evidence.** Memory is
   fallible; evidence is what you can re-open.

## Format

```markdown
**Claim:** <the claim>
**Source:** <path/URL/endpoint + where in it>
**Verification:** <one command that re-opens it, e.g. grep/cat/curl>
```

For board posts and tender closes, evidence is a hard requirement — a close
without a citable artifact is rejected by the federation's own rules.

## Pitfalls

- A citation that doesn't actually support the claim is worse than no citation.
- URL with no anchor ("see docs") is not a citation — point at the section.
- Never fabricate a commit hash, message ID, or file path.
