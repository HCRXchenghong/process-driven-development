# process-driven-development

开发工作自用 Codex skill，用来把项目开发固定成可恢复、可审计、可交付的流程。

## 能力范围

- 项目立项信息记录：中文名、英文名、项目简称、最终交付效果、目标平台。
- 技术栈调研记录：选择框架、数据库、部署方式前必须查当前资料并记录原因。
- 分阶段开发：先核心代码，再集成功能，再做 UI。
- 每个功能都有集成检查，避免只靠静态阅读判断完成。
- UI 项目必须先生成位图预览，获得确认后再实现。
- 网站、服务端、机器人、后台、面板等需要部署的项目，必须交付一键部署脚本和项目简称 CLI 管理菜单。

## 新增部署要求

所有需要部署到服务器或安装到某个环境的项目，都要包含：

- `scripts/deploy.sh`：可从 GitHub raw URL 直接用 Bash 部署到全新 Ubuntu 服务器，也支持本地 `--local` 安装。
- 项目简称命令：部署后可输入项目 slug，例如 `my-project`，进入命令行菜单。
- CLI 菜单能力：状态、启动、停止、重启、日志、更新、备份、管理员管理、环境配置、完整删除/卸载。
- `DEPLOYMENT.md`：记录部署命令、安装路径、服务名、CLI 命令、更新路径、管理员管理方式、删除确认方式和验证结果。

模板文件：

- [templates/deploy.sh](templates/deploy.sh)
- [templates/project-cli.sh](templates/project-cli.sh)
- [references/project-record-template.md](references/project-record-template.md)

## 使用方式

在 Codex 中使用：

```text
Use $process-driven-development to plan and build this project step by step with Markdown records and integration checks.
```

触发后，按 `SKILL.md` 的流程推进项目，并在需要部署时把 `templates/` 下的脚本复制到项目内，替换占位符，接入真实启动、更新、管理员、备份和删除逻辑。
