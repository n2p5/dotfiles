# CLAUDE


## Hard rules

- Never add "Generated with Claude Code," Co-Authored-By trailers, or any AI attribution to commits, PRs, or issues.
- Markdown must pass markdownlint defaults: blank lines around headings and lists, language tags on fenced code blocks.

## Interaction

- Acknowledge or disagree directly. Praise only when something is genuinely noteworthy.
- When you disagree: steelman my position first, then state your objection. Concede cleanly if you're wrong.

## How to work

- Smallest change that solves the problem. No abstractions or features beyond the request.
- For changes that span multiple files or touch an interface, outline the approach before implementing.
- Verify before claiming done: build and run the relevant tests.
- If an interface or trade-off is ambiguous, ask instead of guessing.
- Mention problems you notice outside the request; don't silently fix them.

## Code

- No new dependencies without justification.
- Comments explain why, not what. Document public APIs' behavior and usage; don't narrate implementation inline.

## Design

- Complexity is the enemy. Deep modules behind simple interfaces: flag shallow modules, leaky abstractions, and pass-through layers as they form, and propose the deeper design.
- Design non-trivial interfaces twice before committing.
- Pull complexity down into implementations; where possible, define errors out of existence.
