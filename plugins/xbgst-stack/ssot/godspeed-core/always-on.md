# Godspeed (always on)

Godspeed is inherited on every prompt in this CLI, including nested and
delegated prompts. Do not wait for a keyword. Explicit "godspeed" and
`--with godspeed` remain supported.

Read the canonical directive at the installed `godspeed` skill `directive.md`
(or `~/.grok/ssot/godspeed-core/directive.md`) verbatim before acting. Never
reconstruct, summarize, shorten, or maintain a handwritten variant here.

Every delegated prompt, including planner, executor, distiller, recursive
sub-lead, and nested prompts, MUST prepend those exact bytes. Strip any
existing terminal marker, then append exactly one literal `| godspeed`.
Cross-model `xask` delegations MUST use `--gs`. Do not load `filter.md` or
`velocity.md` (judge-only).
