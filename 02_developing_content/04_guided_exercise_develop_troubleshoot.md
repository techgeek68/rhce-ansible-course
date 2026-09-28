<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Guided exercise (5 of 8)
<!-- nav:end -->

# Guided Exercise: Diagnose and Repair Broken Automation

| | |
|---|---|
| **Exercise name** | `develop_troubleshoot` |
| **Time** | 40 minutes |
| **Covers** | README section 4 |
| **You will** | Repair two faulty playbooks and a faulty inventory by following the diagnosis order from the lesson: parse, lint, targets, reach, privilege, run |

The faults are planted in the order you meet them in real work. Resist fixing anything before a tool has shown it to you; the point is to learn what each tool reports.

---

## Before You Begin

```bash
lab start develop_troubleshoot
```

Start creates `~/develop_troubleshoot` with `ftp.yml`, `motd.yml`, `templates/vsftpd.conf.j2`, an inventory, and `solutions/`. It removes vsftpd from servera and empties `/etc/motd` on serverb and serverc.

Open the project in the dev container or a workstation terminal.

---

## Step 1: Turn on logging first

Add `log_path` to the `[defaults]` section of `ansible.cfg`:

```ini
[defaults]
inventory = ./inventory
remote_user = devops
collections_path = ./collections:/usr/share/ansible/collections
log_path = ./ansible.log
```

From now on every run is also recorded in `ansible.log`, which you will search later.

---

## Part A: `ftp.yml`

### Step 2: Parse

```bash
ansible-navigator run ftp.yml --syntax-check
```

The run stops with a YAML error pointing at line 5:

```
    ftp_banner: Welcome: authorized users only
                       ^ here
```

The unquoted value contains `: `, so YAML sees a second key. Quote it:

```yaml
    ftp_banner: "Welcome: authorized users only"
```

Run `--syntax-check` again: it now prints `playbook: .../ftp.yml`.

### Step 3: Lint

```bash
ansible-lint ftp.yml
```

In VS Code, open `ftp.yml`; if the lower right corner says **YAML**, click it and choose **Ansible** so the extension lints it. Findings and fixes:

| Finding | Line | Fix |
|---|---|---|
| `name[play]` | play header | `- name: FTP service is available on the ftp servers` |
| `yaml[truthy]` | `become: yes` | `become: true` |
| `name[casing]` | `install vsftpd` | `Install vsftpd` |
| `fqcn[action-core]` | `dnf:` | `ansible.builtin.dnf:` |
| `yaml[octal-values]` | `mode: 0600` | `mode: "0600"` |
| `yaml[trailing-spaces]` | after `0600` | delete the spaces |
| `yaml[empty-lines]` | end of file | delete the extra blank lines |

The `dnf` task also uses the old `name=vsftpd state=present` shorthand. Depending on the ansible-lint version it may or may not be reported (`no-free-form`); expand it anyway:

```yaml
    - name: Install vsftpd
      ansible.builtin.dnf:
        name: vsftpd
        state: present
```

Rerun `ansible-lint ftp.yml` until it passes. Lint does not know that anything else is wrong; it only judges style and known risks.

### Step 4: Run and read the failure

```bash
ansible-navigator run ftp.yml
```

The template task fails with `Could not find or access 'vsftpd.j2'`. Search the log the way you would after a long run:

```bash
grep -n -i -E 'fatal|failed!' ansible.log
ls templates/
```

The playbook asks for `vsftpd.j2`; the file is `templates/vsftpd.conf.j2`. The `template` module looks in `templates/` automatically, so only the name is wrong. Fix `src:`:

```yaml
        src: vsftpd.conf.j2
```

### Step 5: Run to success and prove idempotency

```bash
ansible-navigator run ftp.yml     # changed=4 on servera
ansible-navigator run ftp.yml     # changed=0
ansible ftp_servers -b -m ansible.builtin.command -a 'grep ftpd_banner /etc/vsftpd/vsftpd.conf'
```

The last line prints `ftpd_banner=Welcome: authorized users only`, rendered from the variable you quoted in Step 2.

---

## Part B: `motd.yml`

### Step 6: Run and collect the symptoms

```bash
ansible-navigator run motd.yml
```

Two hosts, two different `UNREACHABLE` errors at `Gathering Facts`:

| Host | Message fragment |
|---|---|
| `serverb.lab.example.com` | `admin@serverb.lab.example.com: Permission denied (publickey,...)` |
| `serverc.lab.exmaple.com` | `Could not resolve hostname serverc.lab.exmaple.com` |

### Step 7: Fix the target list

Check the targets and resolution without running the play:

```bash
ansible-inventory --graph banner_hosts
getent hosts serverc.lab.exmaple.com || echo "does not resolve"
```

The inventory misspells `example`. Correct it in `inventory`:

```ini
[banner_hosts]
serverb.lab.example.com
serverc.lab.example.com
```

### Step 8: Fix the login user

The user before `@` is `admin`, although `ansible.cfg` says `devops`. Something with higher precedence overrides it: the play contains `remote_user: admin`. Confirm with a quick ad hoc test that devops works, then delete that line from `motd.yml`:

```bash
ansible banner_hosts -m ansible.builtin.ping
```

### Step 9: Fix privilege

```bash
ansible-navigator run motd.yml
```

Both hosts are reached now, and the copy task fails with a message that the destination `/etc` is not writable. The play says `become: false`, and writing `/etc/motd` requires root. Change it to:

```yaml
  become: true
```

```bash
ansible-navigator run motd.yml     # changed=1 on each host
ansible banner_hosts -m ansible.builtin.command -a 'cat /etc/motd' -o
```

---

## Part C: Controlling a run

### Step 10: Step through and start in the middle

```bash
ansible-navigator run ftp.yml --list-tasks
ansible-navigator run ftp.yml --start-at-task "Vsftpd is running and starts at boot"
ansible-navigator run ftp.yml --step -m stdout --pae false
```

With `--step`, answer `y` for Gathering Facts, `n` for the next task, then `c` to continue without further questions. `--pae false` is required because the run prompts you.

### Step 11: Compare with the solutions

```bash
diff ftp.yml solutions/ftp.yml && diff motd.yml solutions/motd.yml && diff inventory solutions/inventory && echo "all match"
```

Differences in task names are fine as long as `ansible-lint` passes and both playbooks rerun with `changed=0`.

Close the dev container.

---

## Finish

```bash
lab finish develop_troubleshoot
```

## What You Practiced

| Fault | Tool that revealed it | Lesson section |
|---|---|---|
| Unquoted colon | `--syntax-check` | 2.1 |
| Style and risk findings | `ansible-lint` | 4.5 |
| Missing template | Run output and `ansible.log` | 4.2, 4.6 |
| Misspelled host | Run output, `ansible-inventory`, `getent` | 1.6, 4.2 |
| Wrong login user | The name before `@` in the error | 3.2, 4.7 |
| Missing privilege | Run output | 4.2 |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Orchestrate Several Plays](03_guided_exercise_develop_multiplay.md) | Next: [Chapter 02 Quiz: Inventories, Playbooks, and Troubleshooting](05_quiz.md) →

<!-- navfoot:end -->
