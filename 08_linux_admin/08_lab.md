<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Graded lab (9 of 10)
<!-- nav:end -->

# Chapter 08 Lab: Build an Application Host

| | |
|---|---|
| **Exercise name** | `system_review` |
| **Time limit** | 60 minutes |
| **Rules** | Work as `student` on workstation. Documentation tools and `/usr/share/doc/rhel-system-roles/` are allowed; the chapter is not |
| **Solution** | [09_lab_solution.md](09_lab_solution.md), after grading only |

```bash
lab start system_review
```

Start creates `/home/student/system_review` and resets serverb. The project contains:

| File | Content |
|---|---|
| `inventory` | Group `app` with serverb |
| `ansible.cfg` | Privilege escalation off by default |
| `disk_list.yml`, `nic_facts.yml` | Discovery playbooks from the guided exercises |
| `files/keys/ops1.pub`, `ops2.pub` | Public keys of the two operators (private keys beside them for testing) |
| `collections/` | `ansible.posix` and `redhat.rhel_system_roles` |

You may organize playbooks as you like (one per requirement, or one site playbook). Role variables must be in the files named below.

---

## Requirements

**1. Software.** On every `app` host:

* a repository with ID `lab-internal`, name `Lab Example internal packages`, in `/etc/yum.repos.d/lab_internal.repo`, base URL `http://materials.example.com/yum/labrepo/`, with GPG checking enabled and the key `http://materials.example.com/yum/labrepo/RPM-GPG-KEY-labexample`;
* the package `lab-agent` installed from it, and its `lab-agent.timer` running and enabled.

**2. Users.**

* group `ops` with GID 3000;
* users `ops1` (UID 3001) and `ops2` (UID 3002), both with `ops` as a supplementary group;
* each user accepts the SSH key in `files/keys/USER.pub`;
* members of `ops` may run any command as any user through sudo without a password, defined in `/etc/sudoers.d/ops`, mode 0440, validated before it is installed.

**3. Storage** with `redhat.rhel_system_roles.storage`, variables in `group_vars/app/storage.yml`. On the spare 5 GB disk, volume group `app_vg` with:

| Volume | Size | File system | Mount point |
|---|---|---|---|
| `app_data` | 256 MiB | XFS | `/srv/app` |
| `app_logs` | 128 MiB | XFS | `/var/log/app` |
| `app_swap` | 64 MiB | swap | active now and at boot |

**4. Scheduling.** The system cron file `/etc/cron.d/disk_report` runs, as `devops`, every 15 minutes from 08:00 through 17:59, Monday to Friday, the command `df -h /srv/app >> /home/devops/disk_report.log`.

**5. Network** with `redhat.rhel_system_roles.network`, variables in `group_vars/app/network.yml`. A bridge connection named `labbr0`, without ports, active now and at boot, with the static address `192.168.251.N/24`, where N is the last octet of the host's primary address. DHCP and IPv6 autoconfiguration off. Do not change the primary connection.

**6.** Every playbook reports no changes when run a second time.

---

## Grade

```bash
lab grade system_review
```

| Area | Checks |
|---|---|
| Layout | `group_vars/app/storage.yml` and `network.yml` exist |
| Software | Repository file content; signed package installed; timer enabled and active |
| Users | GID and UIDs, memberships, authorized keys, sudo file valid with mode 0440 |
| Storage | Volume sizes; mounts from the right volumes; fstab entries; swap active and persistent |
| Scheduling | Exact cron line |
| Network | Persistent and active address on `labbr0` |

## Finish

```bash
lab finish system_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 08 Quiz: Linux Administration with Ansible](07_quiz.md) | Next: [Chapter 08 Lab Solution: `system_review`](09_lab_solution.md) →

<!-- navfoot:end -->
