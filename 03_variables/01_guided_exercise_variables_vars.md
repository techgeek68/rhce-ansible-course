<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Guided exercise (2 of 7)
<!-- nav:end -->

# Guided Exercise: Place Variables at the Right Scope

| | |
|---|---|
| **Exercise name** | `variables_vars` |
| **Time** | 40 minutes |
| **Covers** | README section 1 |
| **You will** | Use play variables, then build a precedence ladder with one variable defined at six levels, then drive user creation from dictionaries in `group_vars` and override them with extra variables |

---

## Before You Begin

```bash
lab start variables_vars
```

Start creates `~/variables_vars` (inventory with groups `dev` = servera, serverb and `prod` = serverc, serverd, `banner.yml`, and `solutions/`), and removes the accounts, packages, and banner used here from all four servers.

Open the project in the dev container or a workstation terminal. `ansible.cfg` enables `become` for every play in this project.

---

## Part A: Play variables

### Step 1: Write `tools.yml`

```yaml
---
- name: Admin tools are installed and the scheduler runs
  hosts: all
  vars:
    tool_pkgs:
      - at
      - tmux
    scheduler_svc: atd
  tasks:
    - name: Admin tool packages are installed
      ansible.builtin.dnf:
        name: "{{ tool_pkgs }}"
        state: present

    - name: Scheduler runs and starts at boot {{ scheduler_svc }}
      ansible.builtin.systemd_service:
        name: "{{ scheduler_svc }}"
        state: started
        enabled: true
```

`name:` of `dnf` accepts the whole list variable. `systemd_service` accepts exactly one service name. The template in the second task name sits at the end, where lint accepts it.

```bash
ansible-lint tools.yml
ansible-navigator run tools.yml
```

The second task header prints `Scheduler runs and starts at boot atd`: names are templated too.

---

## Part B: One variable, six levels

`banner.yml` writes the value of `motd_banner` into `/etc/motd` and prints it per host. You will define that variable at increasing levels of precedence and predict the result each time **before** you run.

### Step 2: Level 1, `group_vars/all.yml`

```bash
mkdir -p group_vars host_vars
cat > group_vars/all.yml <<'EOF'
---
motd_banner: Set in group_vars/all.yml
EOF
ansible-navigator run banner.yml
```

All four hosts: `Set in group_vars/all.yml`.

### Step 3: Level 2, a more specific group

```bash
cat > group_vars/prod.yml <<'EOF'
---
motd_banner: Set in group_vars/prod.yml
EOF
ansible-navigator run banner.yml
```

serverc and serverd switch to the prod value; servera and serverb keep `all`. Any group beats `all`.

### Step 4: Level 3, a host variable file

```bash
cat > host_vars/serverd.lab.example.com.yml <<'EOF'
---
motd_banner: Set in host_vars/serverd.lab.example.com.yml
EOF
ansible-navigator run banner.yml
```

Only serverd changes. Host beats group.

Check it without running a playbook:

```bash
ansible-inventory --host serverd.lab.example.com
ansible-inventory --host servera.lab.example.com
```

### Step 5: Level 4, a host variable in the inventory file

Change the serverb line in `inventory`:

```ini
serverb.lab.example.com motd_banner="Set on the inventory host line"
```

```bash
ansible-navigator run banner.yml
```

serverb shows the inventory line value: an inventory file host variable beats every group variable. Remove the variable from the line again; keeping host data in `host_vars` is the cleaner habit.

### Step 6: Level 5, play variables

Add to the play in `banner.yml`, between `hosts:` and `tasks:`:

```yaml
  vars:
    motd_banner: Set in the play
```

```bash
ansible-navigator run banner.yml
```

All four hosts show `Set in the play`, **including serverd**: play variables beat `host_vars`. This is why site specific values belong in the inventory side and play `vars` should hold only values that are the same everywhere.

### Step 7: Level 6, extra variables

```bash
ansible-navigator run banner.yml -e 'motd_banner="Set with -e"'
```

Everything shows `Set with -e`. Now delete the `vars:` block from `banner.yml` and run once more without `-e`; the ladder from Step 4 returns.

```bash
ansible all -m ansible.builtin.command -a 'cat /etc/motd' -o
grep -Rnw 'motd_banner:' .
```

The `grep` lists every definition; the trailing colon excludes places that only use the variable.

---

## Part C: Dictionaries, registered results, and overrides

### Step 8: Describe one account per stage

Append to `group_vars/prod.yml`, and create `group_vars/dev.yml`:

```yaml
# group_vars/prod.yml, added below motd_banner
team_user:
  name: oncall
  uid: 7002
  comment: On call engineer
```

```yaml
# group_vars/dev.yml
---
team_user:
  name: devlead
  uid: 7001
  comment: Development lead
```

### Step 9: Write `users.yml`

```yaml
---
- name: Team account exists on every host
  hosts: all
  tasks:
    - name: Team account is present
      ansible.builtin.user:
        name: "{{ team_user['name'] }}"
        uid: "{{ team_user['uid'] }}"
        comment: "{{ team_user['comment'] }}"
        state: present
      register: team_account

    - name: Report the account
      ansible.builtin.debug:
        msg: >-
          {{ team_account['name'] }} has UID {{ team_account['uid'] }}
          and home {{ team_account['home'] }}
```

```bash
ansible-navigator run users.yml
```

dev hosts report `devlead has UID 7001 and home /home/devlead`; prod hosts report `oncall`. One playbook, two data sets, chosen by group membership.

Look at everything the `user` module returned once, to learn which keys exist:

```bash
ansible servera.lab.example.com -m ansible.builtin.user -a 'name=devlead state=present'
```

### Step 10: Override a whole dictionary for one run

```bash
ansible-navigator run users.yml \
  -e '{"team_user": {"name": "auditor", "uid": 7010, "comment": "Temporary auditor"}}'
ansible all -m ansible.builtin.command -a 'id auditor' -o
```

JSON keeps `uid` an integer and replaces the complete dictionary. The auditor account now exists on all four hosts; `lab finish` removes it.

Close the dev container.

---

## Finish

```bash
lab finish variables_vars
```

## What You Proved

| Rule | Step |
|---|---|
| Group beats `all` | 3 |
| Host beats group | 4, 5 |
| Play vars beat all inventory data | 6 |
| `-e` beats everything | 7, 10 |
| Group membership selects data | 9 |

## Troubleshooting

| Symptom | Fix |
|---|---|
| serverd ignores its host file | File name must be `host_vars/serverd.lab.example.com.yml` |
| `team_user is undefined` on one host | That host is in neither `dev` nor `prod` |
| `-e` JSON rejected | Keep the whole JSON inside single quotes; keys and strings in double quotes |

<!-- navfoot:start -->

---

← Previous: [Chapter 03: Variables, Facts, and Secrets](README.md) | Next: [Guided Exercise: Drive Automation from Facts](02_guided_exercise_variables_facts.md) →

<!-- navfoot:end -->
