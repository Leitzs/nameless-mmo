# Taste — Command Code
- Prefers committing and pushing straight to `main` (including merging feature branches into `main` and pushing) rather than opening PRs — fine during testing/early development. Confidence: 0.8
- Prefers a single, easy-to-run script with everything configurable via a local environment variable, so rebuild/regeneration steps (e.g. regenerating maps, recompiling) can be automated right after making changes. Confidence: 0.75
- When the project is running, expects the agent to connect to it and verify the result live (e.g. connecting to the running Unreal Editor via MCP) instead of only asserting code is correct. Confidence: 0.6
- Expects work to be resumed/continued from where it left off after interruptions (crashes, usage limits, stopped background tasks) without re-doing already-completed steps. Confidence: 0.55
- New features should follow the patterns already established in the codebase (e.g. "add the class following the way we created other classes"). Confidence: 0.8
- Values reusable/shared abstractions between features so the codebase can scale (e.g. common base spells/classes reused across characters) over one-off implementations. Confidence: 0.75
- Prefers the agent to just implement once a pattern is established, without asking clarifying questions ("no questions, go and implement it"). Confidence: 0.6
- Often phrases requests in Spanish (mixed with English); comfortable with Spanish-facing answers. Confidence: 0.55
