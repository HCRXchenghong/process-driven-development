---
name: process-driven-development
description: Process-driven project development workflow for software and embedded projects. Use when starting, continuing, or delivering a project that needs explicit project naming, final delivery definition, current technology-stack research, generated bitmap UI previews, Markdown trace records, staged core-first implementation, mandatory deployment scripts, project-short-name CLI management menus, per-feature integration gates, troubleshooting discipline, version tags, README cleanup, or context recovery.
---

# Process-Driven Development

## Core Rule

Run development as a recorded, staged workflow. Clarify the target first, research current stack choices before committing, build the core/code layer before UI, integrate one feature at a time, and keep Markdown records current so the project can recover after context loss.

## Context Recovery

At the start of every project session:

- Inspect the project for Markdown records with `rg --files -g "*.md"` or the fastest available equivalent.
- Read existing project Markdown before planning or coding, prioritizing `PROJECT_BRIEF.md`, `DEVELOPMENT_LOG.md`, `DECISIONS.md`, `INTEGRATION_CHECKS.md`, `DEPLOYMENT.md`, `UI_PREVIEWS.md`, and `README.md`.
- Reconstruct the current state, latest working milestone, open blockers, approved UI previews, and next integration gate from those files.
- If the project has different Markdown names, reuse the existing convention and do not create duplicate records unless needed.
- If no project records exist, create them from `references/project-record-template.md`.

## Intake Gate

Before implementation, establish and record:

- Project Chinese name and English name.
- Project short name / command slug, using lowercase ASCII letters, digits, and hyphens only. This slug is required for deployment scripts and the command-line management menu when the project is deployed or installed.
- Final delivery effect: what the user should be able to run, see, install, flash, deploy, or download at completion.
- Project type: software development, embedded development, or hybrid.
- Target platform, runtime, operating system, browser/device, hardware board, MCU/SoC, peripherals, and deployment target as applicable.
- UI direction, color constraints, and visual quality bar when a visual interface exists.
- Acceptance checks for the first working milestone.

Ask concise questions when these facts are missing. Do not start coding until the project identity, delivery effect, and project type are clear enough to record.

## Technology Stack Research Gate

Always browse the web before selecting or changing the primary technology stack. Do not rely only on memory for current stack decisions.

Research and record at least these three dimensions:

- Most advanced and mature: current stable versions, maintenance activity, ecosystem, production adoption, documentation quality, license, and long-term support.
- Strongest database fit: ORM/query tooling, migrations, schema safety, transactions, pooling, offline/local storage, sync needs, and support for the target database.
- Closest to real delivery: packaging, deployment, installers, firmware flashing, CI/test support, production build behavior, hosting/device constraints, and similarity between development and final output.

Write the comparison to `DECISIONS.md` with source URLs and access date. Prefer primary sources, official docs, release notes, framework/database documentation, and reputable production case studies. If network access is unavailable, record the blocker and ask whether to proceed with a temporary assumption.

## Markdown Records

Keep Markdown records current throughout development:

- `PROJECT_BRIEF.md`: project identity, delivery effect, type, stack, target platform, acceptance criteria.
- `DEVELOPMENT_LOG.md`: chronological work log with timestamp, step, files changed, commands run, result, next step.
- `DECISIONS.md`: architecture, stack, database, UI, and delivery decisions with reasons and sources.
- `INTEGRATION_CHECKS.md`: feature gates, test commands, manual checks, hardware checks, pass/fail results.
- `DEPLOYMENT.md`: one-command deployment path, GitHub raw Bash command, supported Ubuntu/local targets, installed paths, service name, CLI command name, admin-management behavior, update command, uninstall/delete command, rollback notes, and verification results.
- `UI_PREVIEWS.md`: image-generation prompts, preview image paths, approval status, and implemented screen/component mapping.

Update records before and after meaningful changes. If context is lost, these files must be enough to resume without guessing.

## Development Sequence

Follow this order unless the user explicitly overrides it:

1. Clarify and record intake details.
2. Research and record the technology stack.
3. Define the smallest working milestone and integration checks.
4. Implement the core/code layer first.
5. Integrate and verify one feature before starting the next.
6. Build UI only after the relevant core behavior works.
7. Deliver with verification, README cleanup, and an explicit Markdown retention decision.

For software projects, "core/code layer" means domain model, data layer, APIs, services, business logic, state machines, tests, and real integration paths. For embedded projects, it means toolchain setup, board configuration, drivers/HAL, protocols, timing-sensitive logic, storage, communication, tests/simulation, flashing, and serial/debug verification.

## Feature Gate

For every feature:

- Define the smallest observable behavior and write its acceptance check.
- Implement only the code needed for that behavior.
- Run the relevant unit, integration, build, lint, browser, device, or hardware checks.
- Record commands, outputs, failures, and fixes in Markdown.
- Continue to the next feature only after the current feature is integrated through the real path.

Do not treat static code inspection as proof. A feature is not complete until it runs, integrates, and has an observed result.

## Deployment Automation Gate

For every website, web app, API service, worker, bot, dashboard, backend, self-hosted tool, or any project that must be deployed to a server or installed somewhere outside the development checkout:

- Create a concrete deployment script in the project, usually `scripts/deploy.sh`, adapted from `templates/deploy.sh`.
- The script must support a fresh Ubuntu LTS server and a local install path. Prefer Ubuntu 24.04 LTS and support Ubuntu 22.04 LTS unless the stack makes that impossible.
- The script must be runnable from GitHub with a single Bash command, for example:

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/scripts/deploy.sh | sudo bash -s -- --repo https://github.com/<owner>/<repo>.git --branch <branch>
```

- The script must also support local use, for example `bash scripts/deploy.sh --local`.
- The script must be idempotent: re-running it should update or repair the install without duplicating services, users, files, cron jobs, reverse-proxy blocks, or CLI commands.
- The script must detect prerequisites, install required system packages, clone or update the repository, install runtime dependencies, build the project, create or validate environment files, run migrations when applicable, configure the process manager or systemd service, and print the installed URLs, paths, service name, and CLI command.
- Never commit secrets. If environment variables are required, ship `.env.example`, create `.env` only on the target machine, and document required values.
- Install a project-short-name CLI command, usually `/usr/local/bin/<project-slug>` on servers and `$HOME/.local/bin/<project-slug>` for local installs. Running this command must open a menu adapted from `templates/project-cli.sh`.
- The CLI menu must manage project status, start/stop/restart, logs, health checks, updates, backups when data exists, environment/config review, and full project deletion/uninstall.
- If the project has users, roles, owners, or administrators, the CLI menu must include admin management: create admin, list admins, reset credentials or invite link, enable/disable admin, and delete admin when safe. If the project has no admin concept, record that in `DEPLOYMENT.md` and keep the menu item as an operator/owner configuration screen only if useful.
- Update behavior must pull or fetch the selected branch, install dependencies, build, run migrations, restart services, and show a health check result.
- Delete/uninstall behavior must require an explicit typed confirmation using the project slug, stop services, remove services, remove reverse-proxy configuration owned by the project, optionally create a backup, remove install files, and remove the CLI command. It must not delete shared databases, shared users, or shared proxy config unless the script created and owns them.
- Record the deployment command, supported targets, menu command, destructive-action confirmations, update path, and observed deployment verification in `DEPLOYMENT.md` and `INTEGRATION_CHECKS.md`.
- Before delivery, run at least syntax checks on the deployment and CLI scripts. When feasible, run a local dry run or container/VM Ubuntu smoke test and record the result.

## UI Preview Gate

For any UI, frontend, visual screen, dashboard, app interface, game view, device display UI, or visual style decision:

- Use an image generation tool to create a raster bitmap preview. This is mandatory.
- Do not substitute SVG, HTML, CSS, Mermaid, canvas, or hand-coded mockups for the required preview.
- Generate one preview image at a time.
- After each generated image, ask the user whether it is approved, needs changes, or should be regenerated.
- Only after approval, implement that preview into the actual code.
- Run the app/device UI and verify the approved design is connected to working functionality.
- Record the prompt, preview path, approval, implementation files, and verification result in `UI_PREVIEWS.md`.
- Move to the next preview only after the current screen/component is implemented and integrated.

When image generation instructions are available as a separate skill, load and follow that skill before generating the preview.

## Embedded Development Gate

For embedded work:

- Confirm hardware, board revision, MCU/SoC, debugger/flasher, sensors/actuators, display, power constraints, and communication protocols.
- Build firmware layers before visual/display UI or enclosure-level polish.
- Verify incrementally with compile checks, simulations where useful, flashing steps, serial logs, test firmware, and hardware observations.
- Record pin maps, peripheral assumptions, firmware versions, toolchain versions, flash commands, serial output, and observed behavior.
- When blocked by hardware uncertainty, isolate the smallest test firmware or diagnostic path and record expected versus actual behavior.

## Troubleshooting Discipline

When a problem is unclear:

- Search current cases, issues, docs, and examples on the web when the bug may depend on a library, framework, toolchain, device, driver, OS, or browser behavior.
- Form one concrete hypothesis at a time.
- Add targeted instrumentation, logs, assertions, screenshots, serial output, or minimal reproduction code.
- Run the smallest check that can confirm or reject the hypothesis.
- Record expected result, actual result, and next hypothesis.
- Avoid saying the code "looks fine" as a conclusion.

## Version Tags

When a meaningful batch of optimized features or a complete milestone is integrated and verified:

- Check whether the project is a Git repository.
- Summarize the milestone and current verification state.
- Ask before creating a version tag unless the user already instructed tagging.
- Prefer annotated SemVer tags such as `v0.1.0`, `v0.2.0`, or `v1.0.0`.
- Never force-move or delete tags unless explicitly requested.

## Delivery Gate

Before final delivery:

- Run the full relevant verification set and record results.
- For deployed or installed projects, verify the deployment script and CLI menu enough to prove the user can install, update, manage admins, and uninstall the project from the command line.
- Update `README.md` so it explains the final project, setup, run/build/deploy/flash steps, and known limitations.
- Summarize important decisions and final architecture in the README or an appropriate docs file.
- Ask whether to keep, archive, condense, or delete the process Markdown records.
- Do not delete project records without explicit approval.
- If records are removed or condensed, preserve essential decisions, setup steps, verification results, and rollback/version-tag information in `README.md`.

## Reference

Use `references/project-record-template.md` when creating new project records.
Use `templates/deploy.sh` and `templates/project-cli.sh` as starting points for deployment automation, then adapt them to the actual stack before delivery.
