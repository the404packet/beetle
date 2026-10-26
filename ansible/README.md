# Beetle Ansible

Ansible playbooks to install [Beetle](https://github.com/the404packet/beetle) on Ubuntu hosts, run audits and hardening, and pull the PDF reports back to the control machine.

## Files

| File | Purpose |
|------|---------|
| `ansible.cfg` | Ansible settings |
| `hosts.ini` | Your target hosts |
| `vars.yml` | All settings (severity, repo, paths) |
| `install.yml` | Clone the repo, run `install.sh`, start `beetled` |
| `audit.yml` | Run `beetle audit` and fetch the report |
| `harden.yml` | Run `beetle harden` and fetch the report |
| `fetch_reports.yml` | Pull every existing report from the hosts |
| `site.yml` | Install, audit, harden, audit again |

## Requirements

- Control machine: Ansible installed, SSH access to the hosts
- Targets: Ubuntu, a user with sudo

## Setup

1. Edit `hosts.ini` with your hosts and SSH user.
2. Optionally change defaults in `vars.yml`.

## Usage

```bash
# 1. Install Beetle
ansible-playbook install.yml

# 2. Audit (basic | moderate | strict)
ansible-playbook audit.yml -e beetle_severity=moderate

# 3. Harden (requires confirmation, try one host first)
ansible-playbook harden.yml -e beetle_harden_confirm=true --limit ubuntu-web-01

# Pull all reports already on the hosts
ansible-playbook fetch_reports.yml

# Whole pipeline
ansible-playbook site.yml -e beetle_harden_confirm=true
```

Add `-K` if sudo needs a password.

## Reports

Reports are saved on the control machine in:

```
reports/<hostname>/
├── audit_basic_20261026_123000.pdf
├── audit_basic_20261026_123000.log
└── harden_basic_....pdf
```

The `.pdf` is created by Beetle on the host (`/var/lib/beetle/reports`). The `.log` is the console output.

## Useful variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `beetle_severity` | `basic` | `basic`, `moderate` or `strict` |
| `beetle_target` | `""` | Run only one sub-folder of checks |
| `beetle_generate_report` | `true` | Create the PDF report |
| `beetle_harden_confirm` | `false` | Must be `true` to harden |
| `beetle_force_config` | `false` | Pass `--force-config` to `install.sh` |
| `beetle_reinstall` | `false` | Re-run `install.sh` even if installed |

## Warning

Hardening can change the firewall, SSH and services and may lock you out of a host. Test on one machine first with `--limit`. Beetle takes a snapshot before hardening.