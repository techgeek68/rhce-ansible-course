<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Graded lab (6 of 7)
<!-- nav:end -->

# Chapter 04 Lab: Central Logging with Task Control

| | |
|---|---|
| **Exercise name** | `control_review` |
| **Time limit** | 40 minutes |
| **Rules** | Work as `student` on workstation. Documentation tools are allowed; the chapter is not |
| **Solution** | [06_lab_solution.md](06_lab_solution.md), after grading only |

```bash
lab start control_review
```

Start creates `/home/student/control_review` with `ansible.cfg` (privilege escalation on), an inventory (`loghost`: serverd; `clients`: servera, serverb, serverc), `vars/logging.yml`, `files/loghost.conf` (rsyslog receives TCP 514 and writes one file per sender under `/var/log/remote/`), `files/forward.conf` (rsyslog forwards everything to serverd), the navigator settings, and `ansible.posix` in `collections/`. It removes any earlier logging setup.

---

## Requirements

Write `logging.yml` in the project. It loads `vars/logging.yml`, and every value defined there is used through its variable.

**Play 1** targets `loghost` and ensures, in this order, that:

1. the play stops for the host, with a message containing `does not meet the log server requirements`, when its total memory is below `log_min_ram_mb` or its distribution is not `RedHat`. This check must also work when `log_min_ram_mb` is supplied on the command line with `-e log_min_ram_mb=VALUE`;
2. the packages in `log_server_pkgs` are installed;
3. every directory in `log_dirs` exists, owned by `root:root`, mode `0750`;
4. `files/loghost.conf` is installed as `/etc/rsyslog.d/loghost.conf`, and rsyslog is **restarted only when that file changes**, through a handler;
5. every service in `log_services` runs and starts at boot;
6. every port in `log_ports` is open in firewalld, permanently and immediately;
7. any pending handler has run before the next step;
8. a block waits up to 15 seconds for port 514 to accept connections; if that fails, a rescue task reports the problem and causes rsyslog to be restarted through the same handler.

**Play 2** targets `clients` and ensures that:

1. `files/forward.conf` is installed as `/etc/rsyslog.d/forward.conf`, with rsyslog restarted through a handler only when the file changes;
2. the `sysstat` package is installed only on clients whose total memory is at least `sysstat_min_ram_mb`;
3. pending handlers run before the next step;
4. each client sends one test message with the tag `control_review` using the `logger` command, without reporting a change.

A second run of `logging.yml` must report no changes on any host.

Run the playbook with `ansible-navigator` and confirm on serverd that `/var/log/remote/` contains one file per client.

---

## Grade

```bash
lab grade control_review
```

| Area | Checks |
|---|---|
| Playbook | Uses `loop`, `handlers`, `flush_handlers`, `block`, `rescue`; loads the variable file |
| Behavior | Check mode rerun reports no changes; running with `-e log_min_ram_mb=999999` stops with the required message |
| serverd | Both directories with correct owner and mode; rsyslog listening on 514/tcp; port open permanently; a `control_review` message received from each client |
| Clients | Forwarding rule present; sysstat present exactly on clients with at least 1400 MiB |

## Finish

```bash
lab finish control_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 04 Quiz: Loops, Conditionals, Handlers, and Failures](04_quiz.md) | Next: [Chapter 04 Lab Solution: `control_review`](06_lab_solution.md) →

<!-- navfoot:end -->
