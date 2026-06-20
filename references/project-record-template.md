# Project Record Template

Use these sections when a project does not already have its own Markdown record convention. Keep entries concise but specific enough that a future session can resume from them.

## PROJECT_BRIEF.md

```markdown
# Project Brief

## Identity
- Chinese name:
- English name:
- Project short name / command slug:
- Project type: software / embedded / hybrid
- Final delivery effect:

## Targets
- Runtime/platform:
- Database/storage:
- Deployment/install/flash target:
- Fresh-server deployment required: yes / no
- Local install required: yes / no
- Deployment script path:
- CLI menu command:
- Hardware, board, MCU, peripherals:

## Technology Stack
- Selected stack:
- Why this stack:
- Research date:
- Source links:

## UI Direction
- Visual goal:
- Color palette:
- Approved preview paths:

## Acceptance Criteria
- First milestone:
- Final delivery:
- Deployment and management:
```

## DEVELOPMENT_LOG.md

```markdown
# Development Log

## YYYY-MM-DD HH:mm
- Step:
- Files changed:
- Commands/checks:
- Result:
- Next step:
```

## DECISIONS.md

```markdown
# Decisions

## Decision: title
- Date:
- Context:
- Options compared:
- Selected option:
- Reason:
- Database fit:
- Delivery fit:
- Sources:
```

## INTEGRATION_CHECKS.md

```markdown
# Integration Checks

## Feature: name
- Acceptance check:
- Command/manual check:
- Expected result:
- Actual result:
- Status: pending / passed / failed
- Follow-up:
```

## DEPLOYMENT.md

```markdown
# Deployment

## Project Command
- Project slug:
- CLI command:
- Server install path:
- Local install path:
- Service/process name:

## One-Command Deploy
- GitHub raw Bash command:
- Local command:
- Supported operating systems:
- Required environment variables:

## Management Menu
- Status/logs:
- Update command/path:
- Admin management:
- Backup/restore:
- Delete/uninstall:
- Destructive confirmation phrase:

## Verification
- Syntax checks:
- Fresh Ubuntu smoke test:
- Local install test:
- Update test:
- Admin-management test:
- Uninstall test:
- Known limitations:
```

## UI_PREVIEWS.md

```markdown
# UI Previews

## Preview: screen or component name
- Date:
- Prompt:
- Image path:
- User decision: approved / revise / rejected
- Implemented files:
- Runtime verification:
- Notes:
```
