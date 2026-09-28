<!-- nav:start -->
[Course home](../README.md) › [Chapter 01: Introduction to Ansible](README.md) › Lab solution (6 of 6)
<!-- nav:end -->

# Chapter 01 Lab Solution: `intro_review`

Read this only after `lab grade intro_review`. For every step, the reason matters more than the command: the exam words requirements differently each time.

---

## 1. Git identity

```bash
git config --global user.name 'Student User'
git config --global user.email student@lab.example.com
```

The grader reads the author of the pushed commit, so the identity must be set **before** you commit. If you committed first, fix the last commit and push again:

```bash
git commit --amend --reset-author --no-edit
git push --force
```

---

## 2. `ansible.cfg`

```bash
cd ~/intro_review
cat > ansible.cfg <<'EOF'
[defaults]
inventory = ./inventory
remote_user = devops
ask_pass = false
log_path = ./ansible.log

[privilege_escalation]
become = true
become_method = sudo
become_user = root
become_ask_pass = false
EOF
```

| Requirement wording | Setting | Why |
|---|---|---|
| "inventory is the file in the same directory" | `inventory = ./inventory` | Relative paths resolve against the location of `ansible.cfg` |
| "logs in as devops using SSH keys, without prompting" | `remote_user = devops`, `ask_pass = false` | `ask_pass = true` would demand a password |
| "every play runs with privilege escalation by default" | `become = true` | Default for all plays; a play can still set `become: false` |
| "through sudo to root without prompting" | `become_method = sudo`, `become_user = root`, `become_ask_pass = false` | Defaults, but written explicitly because the task lists them |
| "output also written to ansible.log" | `log_path = ./ansible.log` | If unsure of the key name: `ansible-config init --disabled \| grep -n log_path` |

Verify before moving on:

```bash
ansible --version | grep 'config file'
ansible-config dump --only-changed
```

Expected source for every line: `/home/student/intro_review/ansible.cfg`.

---

## 3. `ansible-navigator.yml`

```bash
cat > ansible-navigator.yml <<'EOF'
---
ansible-navigator:
  execution-environment:
    container-engine: podman
    enabled: true
    image: utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest
    pull:
      policy: missing
      arguments:
        - "--tls-verify=false"
  mode: stdout
  playbook-artifact:
    enable: false
EOF
```

| Requirement wording | Key |
|---|---|
| "runs content in an execution environment with Podman" | `enabled: true`, `container-engine: podman` |
| "pulls only when not present locally" | `pull.policy: missing` |
| "TLS verification disabled" | `pull.arguments: ["--tls-verify=false"]` |
| "prints output directly to the terminal" | `mode: stdout` |
| "does not create playbook artifact files" | `playbook-artifact.enable: false` |

Verify the YAML parses and navigator accepts it:

```bash
python3 -c 'import yaml,sys; yaml.safe_load(open("ansible-navigator.yml")); print("YAML ok")'
ansible-navigator exec -- ansible --version | head -2     # runs inside the configured image
```

---

## 4. Run the playbook

```bash
ansible-navigator run mark_hosts.yml
```

Expected recap: `changed=1` for each of the four servers. Run it again to confirm idempotency: `changed=0`.

Why it works without editing the playbook: `mark_hosts.yml` has no `become` keyword, so it inherits `become = true` from `ansible.cfg`. The content line uses `ansible_facts['user_id']`, which facts gathering reports as the effective user, so the file says `Configured by root through Ansible` only when escalation really happened.

Proof from the managed side:

```bash
ssh devops@servera.lab.example.com 'ls -l /etc/intro_review_marker; cat /etc/intro_review_marker'
ls -l *-artifact-*.json 2>/dev/null | wc -l       # 0
ls -l ansible.log
```

Common failures:

| Output | Cause |
|---|---|
| `UNREACHABLE ... root@servera ... Permission denied` | `remote_user` missing or misspelled; navigator fell back to root |
| `Destination /etc not writable` or permission denied on `/etc/intro_review_marker` | `become` not enabled |
| `provided hosts list is empty` | `inventory` path wrong, or command run outside `~/intro_review` |

---

## 5. Git repository and push

```bash
cat > .gitignore <<'EOF'
ansible.log
*-artifact-*.json
EOF

git init -b main
git add -A
git status -s                       # ansible.log must NOT appear
git commit -m 'Configure intro_review project for devops with EE execution'
git remote add origin http://utility.lab.example.com:3000/student/intro_review.git
git push -u origin main             # student / Student@123
git status -sb                      # ## main...origin/main
```

Order matters: create `.gitignore` **before** `git add -A`, otherwise `ansible.log` is staged. If that happened:

```bash
git rm --cached ansible.log
git commit -m 'Stop tracking ansible.log'
git push
```

---

## 6. Grade and finish

```bash
lab grade intro_review
lab finish intro_review
```

## Time Check

At exam pace this lab takes about 12 minutes: 3 for `ansible.cfg`, 3 for `ansible-navigator.yml`, 2 for the run and verification, 4 for Git. If you needed more than 20, repeat it tomorrow from `lab start` without looking at this page.

<!-- navfoot:start -->

---

← Previous: [Chapter 01 Lab: Configure a Project, Run It Through an Execution Environment, Publish It](04_lab.md) | Next: [Chapter 02: Developing Automation Content](../02_developing_content/README.md) →

<!-- navfoot:end -->
