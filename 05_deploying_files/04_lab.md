<!-- nav:start -->
[Course home](../README.md) › [Chapter 05: Deploying and Managing Files](README.md) › Graded lab (5 of 6)
<!-- nav:end -->

# Chapter 05 Lab: Node Profiles, Login Banners, and Cleanup

| | |
|---|---|
| **Exercise name** | `files_review` |
| **Time limit** | 35 minutes |
| **Rules** | Work as `student` on workstation. Documentation tools are allowed; the chapter is not |
| **Solution** | [05_lab_solution.md](05_lab_solution.md), after grading only |

```bash
lab start files_review
```

Start creates `/home/student/files_review` with `ansible.cfg` (privilege escalation off by default; `ansible_managed` set to `Managed by Ansible: changes will be overwritten`), an inventory (`web`: servera, serverb; `db`: serverc), `group_vars/web.yml` (defines `maintenance_window`), `files/issue`, the navigator settings, and `ansible.posix` in `collections/`.

On servera, serverb, and serverc it restores the default `/etc/issue`, `/etc/issue.net` (a regular file), and SSH banner setting, and creates `/var/tmp/labcache` containing `old1.tmp`, `old2.tmp`, `keep.log` (all ten days old) and `new1.tmp` (new).

---

## Requirements

**1. Template `templates/node_profile.j2`.** Rendered on a host, it produces exactly these lines, in this order:

```
# <the ansible_managed text>
node = <fully qualified host name from facts>
address = <default IPv4 address from facts>
os = <distribution> <distribution version>
memory_gib = <total memory in GiB, rounded to one decimal place with the round filter>
vcpus = <number of virtual CPUs from facts>
maintenance = <value of maintenance_window, or the word unscheduled when it is not defined>
role = <group name>                  (one line per group the host belongs to, sorted)
peers = <every other inventory host, sorted, separated by commas>
```

Example for serverc: `maintenance = unscheduled`, `role = db`, `peers = servera.lab.example.com,serverb.lab.example.com`.

**2. Playbook `profile.yml`,** one play for all hosts with privilege escalation, that ensures:

* the template is rendered to `/etc/node-profile.conf`, owned by `root:root`, mode `0644`;
* `files/issue` is installed as `/etc/issue`, owned by `root:root`, mode `0644`;
* `/etc/issue.net` is a symbolic link to `/etc/issue`;
* sshd uses `Banner /etc/issue.net`: the setting is changed in `/etc/ssh/sshd_config` with a single line edit, the new file is validated with `sshd -t` before it is installed, and sshd is reloaded only when the file changed;
* `/etc/profile.d/lab_env.sh` (owned by `root:root`, mode `0644`) contains a managed block between the markers `# BEGIN LAB ENVIRONMENT` and `# END LAB ENVIRONMENT` with two lines: `export LAB_ROLE=<first group of the host>` and `export LAB_NODE=<short inventory host name>`;
* in `/var/tmp/labcache`, every file matching `*.tmp` that is older than seven days is deleted; other files stay;
* each host's `/etc/node-profile.conf` is copied back into the project as `profiles/<inventory host name>.conf`.

**3. Run** `profile.yml` with `ansible-navigator` until every task succeeds, then log in to serverb to see both banners.

---

## Grade

```bash
lab grade files_review
```

| Area | Checks |
|---|---|
| Template | Uses `ansible_managed`, a `for` loop, and the `default` filter |
| Node profile | Every required line with the host's real values; header first; owner and mode |
| Banners | `/etc/issue` content, owner, mode; `/etc/issue.net` is a link to it; `sshd -T` reports the banner |
| Environment block | Markers and both export lines; owner and mode |
| Cleanup | Only `keep.log` and `new1.tmp` remain |
| Collection | `profiles/<host>.conf` identical to the host's file |

## Finish

```bash
lab finish files_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 05 Quiz: Files and Templates](03_quiz.md) | Next: [Chapter 05 Lab Solution: `files_review`](05_lab_solution.md) →

<!-- navfoot:end -->
