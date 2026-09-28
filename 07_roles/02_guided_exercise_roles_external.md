<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Guided exercise (3 of 7)
<!-- nav:end -->

# Guided Exercise: Install Pinned Roles from an Archive and from Git

| | |
|---|---|
| **Exercise name** | `roles_external` |
| **Time** | 35 minutes |
| **Covers** | README section 3 |
| **You will** | Point Ansible at a project roles directory, install one role from an archive and another from a tagged Git repository, customize both from a playbook, and upgrade one deliberately |

---

## Before You Begin

```bash
lab start roles_external
```

Start creates `~/roles_external` with `shell_env.tar` (the `labteam.shell_env` role), and publishes the role `labteam.motd` on the lab Git server with two tags:

| Tag | Content |
|---|---|
| `v1.0.0` | Banner with a message and the host name |
| `v1.1.0` | Adds a support contact line (`motd_contact`) |

Browse `http://utility.lab.example.com:3000/student/labteam.motd` to see both tags. Open the project in the dev container or a workstation terminal.

---

## Step 1: A roles directory Ansible searches

```bash
mkdir roles
ansible-galaxy role list
```

Only the default paths are listed. Add to `[defaults]` in `ansible.cfg`:

```ini
roles_path = ./roles
```

```bash
ansible-galaxy role list
```

`# /workspaces/roles_external/roles` (or your workstation path) now appears first. Installs will land here, inside the project that navigator mounts.

---

## Step 2: The requirements file

Create `roles/requirements.yml`:

```yaml
---
- name: labteam.shell_env
  src: shell_env.tar

- name: labteam.motd
  src: http://utility.lab.example.com:3000/student/labteam.motd.git
  scm: git
  version: v1.0.0
```

```bash
ansible-galaxy role install -r roles/requirements.yml
ansible-galaxy role list
```

```
- labteam.motd, v1.0.0
- labteam.shell_env, (unknown version)
```

An archive has no version information; a Git role reports the requested version.

---

## Step 3: Read the roles before using them

```bash
cat roles/labteam.shell_env/README.md
cat roles/labteam.shell_env/defaults/main.yml
cat roles/labteam.motd/defaults/main.yml roles/labteam.motd/templates/motd.j2
```

| Role | Variables | Effect |
|---|---|---|
| `labteam.shell_env` | `shell_env_prompt`, `shell_env_history_size` | Writes `/etc/profile.d/lab_shell.sh` |
| `labteam.motd` | `motd_message` | Renders `/etc/motd` |

---

## Step 4: Use them with your own values

Create `team_login.yml`:

```yaml
---
- name: Team login experience
  hosts: web
  tasks:
    - name: Shell environment with a custom prompt
      ansible.builtin.import_role:
        name: labteam.shell_env
      vars:
        shell_env_prompt: '[\u on \h in \W]\$ '
        shell_env_history_size: 10000

    - name: Login banner
      ansible.builtin.import_role:
        name: labteam.motd
      vars:
        motd_message: Development host. Ask before rebooting.
```

Single quotes keep the backslashes of the prompt literal.

```bash
ansible-navigator run team_login.yml
ansible web -m ansible.builtin.command -a 'bash -lc "echo $HISTSIZE"'
ansible web -m ansible.builtin.command -a 'cat /etc/motd'
ssh devops@servera.lab.example.com
```

`HISTSIZE` is 10000, the banner shows your message, and the interactive login shows the prompt `[devops on servera in ~]$`. Log out.

---

## Step 5: Upgrade one role on purpose

Change `version: v1.0.0` to `version: v1.1.0` in `roles/requirements.yml`:

```bash
ansible-galaxy role install -r roles/requirements.yml
```

`labteam.motd (v1.0.0) is already installed - use --force to change version to v1.1.0`. Nothing changed: upgrades are never silent.

```bash
ansible-galaxy role install -r roles/requirements.yml --force
ansible-galaxy role list
cat roles/labteam.motd/templates/motd.j2
ansible-navigator run team_login.yml --check --diff
ansible-navigator run team_login.yml
```

The new template adds `Support: platform-team@lab.example.com`, the default of the new variable `motd_contact`. The diff showed you the effect of the upgrade before you applied it: always preview a role upgrade this way.

---

## Step 6: Remove and reinstall

```bash
ansible-galaxy role remove labteam.shell_env
ansible-galaxy role list
ansible-navigator run team_login.yml --syntax-check
ansible-galaxy role install -r roles/requirements.yml
```

Without the role, even the syntax check fails (`the role 'labteam.shell_env' was not found`), because `import_role` is resolved at parse time. The requirements file restores the exact state in one command, which is why it belongs in version control and the installed roles usually do not.

Close the dev container.

---

## Finish

```bash
lab finish roles_external
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Roles installed into `~/.ansible/roles` | `roles_path` missing from `ansible.cfg`; use `-p roles` or add it |
| `- git clone ... failed` | Check the URL with `git ls-remote http://utility.lab.example.com:3000/student/labteam.motd.git` |
| `version v1.2.0 not found` | Only `v1.0.0` and `v1.1.0` exist |
| YAML error about an unknown escape in the prompt | The value was double quoted, so YAML tried to read `\u` as an escape; use single quotes |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Write a Reusable Role](01_guided_exercise_roles_create.md) | Next: [Guided Exercise: Install Collections and Use RHEL System Roles](03_guided_exercise_roles_collections.md) →

<!-- navfoot:end -->
