<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Graded lab (7 of 8)
<!-- nav:end -->

# Chapter 02 Lab: Inventory, Repair, Build, and Verify

| | |
|---|---|
| **Exercise name** | `develop_review` |
| **Time limit** | 30 minutes |
| **Rules** | Work as `student` on workstation. VS Code or terminal, your choice. No looking at the chapter or guided exercises; `ansible-doc`, `ansible-navigator doc`, man pages, and `--help` are allowed |
| **Solution** | [07_lab_solution.md](07_lab_solution.md), after grading only |

```bash
lab start develop_review
```

Start creates `/home/student/develop_review` with `ansible.cfg`, `ansible-navigator.yml`, a dev container definition, `ansible.posix` in `collections/`, and a faulty `database.yml`. It removes httpd from serverb and serverc and MariaDB from serverd, together with their firewall rules.

---

## Requirements

**1. Inventory.** Create `inventory` in the project using fully qualified host names:

| Host | Group |
|---|---|
| servera.lab.example.com | probes |
| serverb.lab.example.com, serverc.lab.example.com | web (write them as one range) |
| serverd.lab.example.com | db |

* Group `app` contains the groups `web` and `db` as child groups.
* The variable `http_welcome` has the value `App tier ready` for members of `web` only.

**2. Logging.** Every playbook run from the project directory is also written to `ansible.log` in the project directory.

**3. Repair `database.yml`.** Without changing its host pattern:

* it must pass `ansible-lint` with no findings;
* it must run successfully and leave MariaDB running and enabled at boot on serverd, with the `mysql` firewall service allowed permanently and immediately.

**4. Write `webserver.yml`** with two plays.

Play 1 targets group `web` with privilege escalation and ensures that:

* `httpd` and `firewalld` are installed, without upgrading them if already present;
* firewalld is running and enabled at boot, and the `http` service is allowed permanently and immediately;
* `/var/www/html/index.html` has mode `0644` and contains exactly one line: the value of `http_welcome`, followed by ` on `, followed by the inventory host name. For serverb the line is `App tier ready on serverb.lab.example.com`;
* httpd is running and enabled at boot.

Play 2 targets group `probes` **without** privilege escalation and uses `ansible.builtin.uri` to confirm that serverb and serverc both answer HTTP requests with status 200.

`webserver.yml` must pass `ansible-lint` and report no changes when run a second time.

**5. Run.** Use `ansible-navigator` to run `database.yml` and then `webserver.yml` until both succeed.

---

## Grade

```bash
lab grade develop_review
```

| Criterion | How it is checked |
|---|---|
| Inventory groups | `ansible-inventory --list` in the project: web, db, probes, and app children |
| Group variable | `http_welcome` present for serverb and serverc, absent for serverd |
| Lint | `ansible-lint` on `database.yml` and on `webserver.yml` |
| Idempotency | `ansible-playbook webserver.yml --check` reports no `changed` |
| Logging | `ansible.log` contains a play recap |
| Database host | MariaDB active and enabled; `mysql` allowed permanently |
| Web hosts | httpd active and enabled; `http` allowed permanently; page content exact |

Fix every `FAIL` and grade again.

## Finish

```bash
lab finish develop_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 02 Quiz: Inventories, Playbooks, and Troubleshooting](05_quiz.md) | Next: [Chapter 02 Lab Solution: `develop_review`](07_lab_solution.md) →

<!-- navfoot:end -->
