# AI Workstation Tools

ChatGPT desktop, Codex CLI, and Claude Code are standard on every host in the
`all_workstations` inventory group. The `ai_workstation_tools` role is their
single Ansible owner; do not add either CLI to NVM or another baseline role.

## Deploy and Verify

From the repository root:

```bash
make deploy-ai-tools
make deploy-ai-tools HOST=armitage
make validate-ai-tools HOST=armitage
make update-ai-tools
```

The direct playbook is
`ansible/playbooks/deploy-ai-workstation-tools.yml`. Use `--tags chatgpt`,
`--tags codex`, `--tags claude_code`, or `--tags verify` for a focused run.

## Platform Installers

- Fedora 43/44 installs OpenAI's architecture-specific RPM. The package adds
  OpenAI's signed DNF repository; normal updates can use
  `dnf upgrade --refresh chatgpt`. Keep XWayland as the default because native
  Wayland support is experimental.
- Linux and macOS install Codex with OpenAI's standalone installer under the
  target user's home directory.
- Fedora installs Claude Code from Anthropic's signed stable DNF repository.
- macOS uses Homebrew casks. Windows uses vendor Winget/Store packages, with
  the supported Codex npm package as the Windows CLI path.

Set `ai_workstation_tools_update=true` only for an intentional upgrade run.
The primary desktop user defaults to `ansible_user`; override
`ai_workstation_tools_target_user` in host vars when the automation account is
different (for example, `count-zero`).

## Authentication and Troubleshooting

Authentication is deliberately interactive and per user. Never commit OpenAI
or Anthropic tokens, CLI auth files, or copied browser sessions. After first
deployment, launch `chatgpt`, `codex`, and `claude` as the desktop user and
complete each vendor's sign-in flow.

Verify versions with `chatgpt --version`, `codex --version`, and
`claude --version`. For Claude diagnostics, run `claude doctor`. If a shell
finds an old npm copy first, remove that legacy package only after the managed
binary verifies successfully, then open a new login shell.
