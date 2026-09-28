<!-- nav:start -->
[Course home](../README.md) › [Chapter 06: Automation at Scale](README.md) › Graded lab (5 of 6)
<!-- nav:end -->

# Chapter 06 Lab: Refactor an Inherited Playbook

| | |
|---|---|
| **Exercise name** | `scale_review` |
| **Time limit** | 30 minutes |
| **Rules** | Work as `student` on workstation. Documentation tools are allowed; the chapter is not |
| **Solution** | [05_lab_solution.md](05_lab_solution.md), after grading only |

```bash
lab start scale_review
```

Start creates `/home/student/scale_review` containing:

* `inventory`: groups `app_east` (servera, serverb), `app_west` (serverc, serverd), `support` (utility), `legacy` (server9.old.example.com, which does not exist);
* `site.yml`: one play that lists the four application servers by name and contains seven tasks for httpd, a status page, and firewalld;
* `plays/check.yml`: a play that requests every application server's status page from the control side;
* an empty `tasks/` directory, `ansible.cfg` (privilege escalation off by default), the navigator settings, and `ansible.posix` in `collections/`.

It also removes httpd, the status page, and the http and https firewall rules from the four servers.

Read `site.yml` before you change anything, and run `ansible-navigator run site.yml --list-tasks` to record the task list you must preserve.

---

## Requirements

**1. Host pattern.** Replace the play's list of four host names with **one** pattern containing a wildcard, no commas, that selects exactly servera, serverb, serverc, and serverd from this inventory, and nothing else.

**2. Split the play.**

* The first four tasks (httpd and the status page) move to `tasks/web_tasks.yml`.
* The last three tasks (firewalld and its rules) move to `tasks/firewall_tasks.yml`.
* The play in `site.yml` keeps exactly two tasks, both `ansible.builtin.import_tasks`: first `tasks/web_tasks.yml`, then `tasks/firewall_tasks.yml`.

**3. Remove the duplication.** Both files install a package and then start and enable a service. Create `tasks/install_and_enable.yml` with two tasks that install the package named by the variable `package` and start and enable the service named by the variable `service`. It must not contain any literal package or service names. In each of the two files, replace the install and start tasks with one `ansible.builtin.import_tasks` of `install_and_enable.yml`, passing `package` and `service` through `vars:` (httpd for the web file, firewalld for the firewall file). No other task in those two files may install packages or manage services.

**4. Verify.** `site.yml` ends with a second top level entry that imports `plays/check.yml`.

**5. Run** `site.yml` with `ansible-navigator` until everything succeeds. A second run must report no changes.

---

## Grade

```bash
lab grade scale_review
```

| Area | Checks |
|---|---|
| Pattern | One wildcard term; `--list-hosts` shows exactly the four servers |
| Structure | Play tasks are the two imports, in order; `plays/check.yml` imported last |
| Reuse | Both task files import `install_and_enable.yml` with the right `package` and `service`; the shared file uses only variables; no leftover install or service tasks |
| Behavior | Check mode rerun reports no changes |
| Hosts | httpd and firewalld running, http and https open, status page correct on all four |

## Finish

```bash
lab finish scale_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 06 Quiz: Imports, Includes, and Host Patterns](03_quiz.md) | Next: [Chapter 06 Lab Solution: `scale_review`](05_lab_solution.md) →

<!-- navfoot:end -->
