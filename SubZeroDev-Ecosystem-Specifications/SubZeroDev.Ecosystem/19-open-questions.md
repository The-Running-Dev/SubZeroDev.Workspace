# Open Questions and Review Checklist

## Platform

1. Is `SubZeroDev.Platform` the final root name?
2. Which packages belong in Phase One?
3. Does Platform own workflow abstractions, or only jobs/scheduling?
4. Which persistence model is preferred?
5. Should identity be based on ASP.NET Core Identity initially?
6. Is multi-tenancy required from first schema design?
7. Which billing provider is preferred first?
8. Which license model is expected?

## Automator

1. Is local execution the initial product or server-first?
2. Should workflows be YAML, JSON, code, or all three?
3. Is the execution event history append-only?
4. Are plugins installed globally, per project, or per tenant?
5. What is the first remote-agent transport?
6. Which commands may be exposed through MCP?
7. Does the control plane execute local plugins, or always dispatch to an agent?
8. What are default network and filesystem restrictions?

## Plugin contract

1. Final manifest serialization: YAML or JSON?
2. Is JSON Schema the canonical input/output definition?
3. Does every plugin need a CLI?
4. Are multiple runtime implementations allowed in one manifest?
5. How are runtime-specific options represented?
6. What signing mechanism is planned?
7. How are capability permissions reviewed?
8. What is the version compatibility policy?

## GitHub plugin

1. Owned repositories only in Phase One?
2. Include forks?
3. Include archived?
4. Include organization repositories?
5. Include contributed repositories?
6. Basic, Standard, or Detailed collection by default?
7. Is historical activity needed?
8. One consolidated output or per-project files too?
9. Where do portfolio overrides live?
10. Should raw API responses be retained?

## Requirements Compiler

1. Which AI provider is Phase One?
2. What issue hierarchy is preferred?
3. Should estimates be generated?
4. Which GitHub Project fields are required?
5. What reconciliation behavior is safe?
6. Should publishing require human approval?
7. How are stable IDs generated?
8. How are conflicting requirements represented?

## Review instructions for Opus

Review for:

- hidden coupling
- incorrect boundaries
- unnecessary complexity
- missing failure modes
- security gaps
- missing lifecycle semantics
- unsuitable technology choices
- unclear ownership
- over-broad Phase One
- contracts that will be difficult to evolve

Produce:

1. findings
2. critical changes
3. recommended ADRs
4. revised phase plan
5. questions requiring Ben's decision
