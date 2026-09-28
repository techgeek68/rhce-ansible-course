<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Guided exercise (4 of 7)
<!-- nav:end -->

# Guided Exercise: Install Collections and Use RHEL System Roles

| | |
|---|---|
| **Exercise name** | `roles_collections` |
| **Time** | 40 minutes |
| **Covers** | README sections 4 and 5 |
| **You will** | Install a collection from a requirements file, watch collection shadowing happen, use a community module by FQCN, and configure time synchronization with a RHEL system role driven by `group_vars` |

---

## Before You Begin

```bash
lab start roles_collections
```

Start creates `~/roles_collections` (inventory: `web` = servera; `ansible.posix` already in `collections/`; `verify_time.yml`; `solutions/`) and sets servera's time zone to UTC.

Open the project in the dev container or a workstation terminal.

---

## Step 1: What is installed, and where

```bash
grep collections_path ansible.cfg
ansible-galaxy collection list 2>/dev/null | grep -E '^#|posix|general|rhel_system'
```

The project path comes first, then `/usr/share/ansible/collections`, where the `rhel-system-roles` RPM installed `redhat.rhel_system_roles` on workstation.

---

## Step 2: Install community.general from a requirements file

Find the exact archive name on the materials server:

```bash
curl -s http://materials.example.com/collections/ | grep -o 'community-general-[0-9.]*\.tar\.gz' | sort -u
```

Create `collections/requirements.yml` with that name:

```yaml
---
collections:
  - name: http://materials.example.com/collections/community-general-X.Y.Z.tar.gz
```

```bash
ansible-galaxy collection install -r collections/requirements.yml -p collections
ansible-galaxy collection list community.general
```

The collection sits in `collections/ansible_collections/community/general`. Without `-p collections` it would have gone to `~/.ansible/collections`, invisible to navigator's execution environment.

---

## Step 3: Use a module from it

```bash
ansible-doc community.general.timezone | sed -n '1,25p'
```

Create `timezone.yml`:

```yaml
---
- name: Time zone from a community collection module
  hosts: web
  tasks:
    - name: Time zone is set
      community.general.timezone:
        name: America/New_York
```

```bash
ansible-navigator run timezone.yml
ansible-navigator run verify_time.yml | grep 'Time zone'
```

`Time zone: America/New_York`. The module exists only because the collection is installed; remove the `community.general` directory and the syntax check fails with `couldn't resolve module/action`.

---

## Step 4: Shadowing, seen with your own eyes

Copy the system role collection from the RPM into the project:

```bash
mkdir -p collections/ansible_collections/redhat
cp -a /usr/share/ansible/collections/ansible_collections/redhat/rhel_system_roles collections/ansible_collections/redhat/
ansible-galaxy collection list redhat.rhel_system_roles
```

Two entries, one per path. Now look from inside the execution environment:

```bash
ansible-navigator collections -m interactive
```

Scroll to `redhat.rhel_system_roles`. With the Red Hat execution environment you see two rows: the project copy (type `bind_mount`, `Shadowed False`) and the copy built into the image (type `contained`, `Shadowed True`). The project copy wins because `./collections` is first in `collections_path`. Press `Esc`, then `:q`.

(With the community execution environment, only the project copy appears, because that image contains no RHEL system roles. The project copy is what makes the next steps work with any image.)

---

## Step 5: Read the system role documentation offline

```bash
ls /usr/share/ansible/roles/ | head
ls /usr/share/doc/rhel-system-roles/timesync/
less /usr/share/doc/rhel-system-roles/timesync/README.md
```

Search the README for `timesync_ntp_servers` and `timesync_ntp_provider`. The directory also contains example playbooks you can copy. The legacy names in `/usr/share/ansible/roles/` (`rhel-system-roles.timesync`) point to the same content as the collection role.

---

## Step 6: Variables in group_vars, role by FQCN

```bash
mkdir -p group_vars/all
```

`group_vars/all/timesync.yml`:

```yaml
---
# Variables for redhat.rhel_system_roles.timesync
timesync_ntp_provider: chrony
timesync_ntp_servers:
  - hostname: bastion.lab.example.com
    iburst: true
```

`time_sync.yml`:

```yaml
---
- name: Time synchronization from a RHEL system role
  hosts: web
  tasks:
    - name: Chrony uses the lab time server
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.timesync
```

```bash
ansible-navigator run time_sync.yml --syntax-check
ansible-navigator run time_sync.yml
ansible-navigator run verify_time.yml
```

The role runs dozens of tasks, most `skipping` (they handle other providers and versions), and ends with `RUNNING HANDLER [redhat.rhel_system_roles.timesync : Restart chronyd]`. The verification shows `server bastion.lab.example.com iburst`.

```bash
ansible web -m ansible.builtin.command -a 'chronyc -n sources'
ansible-navigator run time_sync.yml     # changed=0
```

Close the dev container.

---

## Finish

```bash
lab finish roles_collections
```

Finish sets servera's time zone back to UTC. The chrony configuration stays; it points at the same bastion server as before, only by name.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `couldn't resolve module/action 'community.general.timezone'` | Collection not installed in `collections/`, or `collections_path` lacks `./collections` |
| `the role 'redhat.rhel_system_roles.timesync' was not found` | Community EE without the project copy; repeat Step 4 |
| Chrony configuration unchanged | Variable names misspelled; copy them from the README |
| `ansible-galaxy` downloads from the internet instead of using the URL | The `name:` line must be the full archive URL |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Install Pinned Roles from an Archive and from Git](02_guided_exercise_roles_external.md) | Next: [Chapter 07 Quiz: Roles and Collections](04_quiz.md) →

<!-- navfoot:end -->
