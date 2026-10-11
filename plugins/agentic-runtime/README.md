# Agentic Runtime

```mermaid
flowchart LR
  Create[Create Task<br>（CLI）] --> Direct[Direct<br>（Hooks）]
  Direct --> Execute[Execute Step<br>（Agent）]
  Execute --> Report[Report<br>Step Completion<br>（CLI）]
  Report -->|rejected| Execute
  Report -->|accepted| Continue{Continue<br>（Hooks）}
  Continue -->|next| Direct
  Continue -->|done| Close[Close<br>（Hooks）]
```

Inspired by:
- [Loop Engineering](https://x.com/steipete/status/2063697162748260627?s=20)
- [Ralph Loop](https://ghuntley.com/ralph/)
