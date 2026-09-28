<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Guided exercise (3 of 10)
<!-- nav:end -->

# Guided Exercise: Signed Repositories, Packages, and Package Facts

| | |
|---|---|
| **Exercise name** | `system_software` |
| **Time** | 30 minutes |
| **Covers** | README section 2 |
| **You will** | Trust a repository signing key, define an internal repository, install a signed package, prove that package facts are a snapshot, and start the timer the package ships |

---

## Before You Begin

```bash
lab start system_software
```

Start builds (once) and publishes the lab repository at `http://materials.example.com/yum/labrepo/`. It contains `lab-agent`, signed with the key `RPM-GPG-KEY-labexample`. servera has neither the key nor the repository.

```bash
curl -s http://materials.example.com/yum/labrepo/ | grep -o 'lab-agent[^"<]*rpm' | sort -u
curl -s http://materials.example.com/yum/labrepo/RPM-GPG-KEY-labexample | head -2
```

Open `~/system_software` in the dev container or a workstation terminal.

---

## Step 1: What the host has now

Create `repo.yml`:

```yaml
---
- name: Lab repository and agent
  hosts: web
  become: true
  vars:
    agent_pkg: lab-agent
    repo_url: http://materials.example.com/yum/labrepo
  tasks:
    - name: Package facts are gathered
      ansible.builtin.package_facts:

    - name: Report the agent state before changes
      ansible.builtin.debug:
        msg: >-
          {{ agent_pkg }}
          {{ 'is installed' if agent_pkg in ansible_facts['packages'] else 'is not installed' }}
```

```bash
ansible-navigator run repo.yml
```

`lab-agent is not installed`.

---

## Step 2: Watch signature checking work

Append a repository **without** a key, and the installation:

```yaml
    - name: Lab repository is configured
      ansible.builtin.yum_repository:
        name: lab-internal
        description: Lab Example internal packages
        file: lab_internal
        baseurl: "{{ repo_url }}/"
        gpgcheck: true
        enabled: true

    - name: Agent is installed
      ansible.builtin.dnf:
        name: "{{ agent_pkg }}"
        state: present
```

```bash
ansible-navigator run repo.yml
```

The install fails: the package is signed, `gpgcheck` is on, and the host does not trust the key. This is the protection working. Never "fix" it with `disable_gpg_check`.

---

## Step 3: Trust the key

Insert this task **before** the repository task, and add `gpgkey` to the repository so dnf also knows where the key lives:

```yaml
    - name: Repository signing key is trusted
      ansible.builtin.rpm_key:
        key: "{{ repo_url }}/RPM-GPG-KEY-labexample"
        state: present
```

```yaml
        gpgkey: "{{ repo_url }}/RPM-GPG-KEY-labexample"
```

```bash
ansible-navigator run repo.yml
ansible web -m ansible.builtin.command -a 'cat /etc/yum.repos.d/lab_internal.repo'
ansible web -m ansible.builtin.shell -a 'rpm -qi lab-agent | grep -E "^(Version|Signature)"'
```

The repository file has the `[lab-internal]` section with `gpgcheck = 1`, and the package reports an RSA signature.

---

## Step 4: Facts are a snapshot

Append:

```yaml
    - name: Report the installed version
      ansible.builtin.debug:
        msg: "{{ ansible_facts['packages'][agent_pkg][0]['version'] }}"
```

Remove the package and run:

```bash
ansible web -b -m ansible.builtin.dnf -a 'name=lab-agent state=absent'
ansible-navigator run repo.yml
```

The last task fails with an undefined variable error for `lab-agent`: the facts were gathered before the package existed. Insert a refresh before the report:

```yaml
    - name: Package facts are refreshed after the installation
      ansible.builtin.package_facts:
```

Replace the report message with version and release:

```yaml
        msg: >-
          {{ agent_pkg }} {{ ansible_facts['packages'][agent_pkg][0]['version'] }}-{{
          ansible_facts['packages'][agent_pkg][0]['release'] }} is installed
```

```bash
ansible web -b -m ansible.builtin.dnf -a 'name=lab-agent state=absent'
ansible-navigator run repo.yml
```

`lab-agent 1.0-1 is installed`.

---

## Step 5: Use what the package ships

```bash
ansible web -m ansible.builtin.command -a 'rpm -ql lab-agent'
```

The package ships a service and a timer, not a cron file. Append:

```yaml
    - name: Agent timer runs and starts at boot
      ansible.builtin.systemd_service:
        name: lab-agent.timer
        state: started
        enabled: true
```

```bash
ansible-navigator run repo.yml
ansible web -m ansible.builtin.command -a 'systemctl list-timers lab-agent.timer'
ansible web -b -m ansible.builtin.command -a 'systemctl start lab-agent.service'
ansible web -m ansible.builtin.command -a 'cat /var/lib/lab-agent/last_run'
ansible-navigator run repo.yml     # changed=0
```

Compare with `solutions/repo.yml` and close the dev container.

---

## Finish

```bash
lab finish system_software
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Failed to download metadata for repo 'lab-internal'` | Check the URL with `curl http://materials.example.com/yum/labrepo/repodata/repomd.xml`; rerun `lab start` |
| `Public key for lab-agent-1.0-1.noarch.rpm is not installed` | The key task is missing or after the install |
| Repository file named `lab-internal.repo` | `file: lab_internal` missing |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Time Zones, Time Sync, and SELinux with System Roles](01_guided_exercise_system_roles.md) | Next: [Guided Exercise: Accounts, Keys, sudo, and sshd](03_guided_exercise_system_users.md) →

<!-- navfoot:end -->
