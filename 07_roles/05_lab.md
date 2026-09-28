<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Graded lab (6 of 7)
<!-- nav:end -->

# Chapter 07 Lab: Team Development Portal from Roles and Collections

| | |
|---|---|
| **Exercise name** | `roles_review` |
| **Time limit** | 45 minutes |
| **Rules** | Work as `student` on workstation. Documentation tools and `/usr/share/doc/rhel-system-roles/` are allowed; the chapter is not |
| **Solution** | [06_lab_solution.md](06_lab_solution.md), after grading only |

```bash
lab start roles_review
```

Start creates `/home/student/roles_review` and publishes the infrastructure team's role `infra.httpd` on the lab Git server (tag `v1.0.0`) at `http://utility.lab.example.com:3000/student/infra.httpd`. The project contains:

| File | Content |
|---|---|
| `inventory` | Group `portal` with serverb |
| `ansible.cfg` | Privilege escalation off by default; `collections_path` with `./collections` first |
| `site_tasks.yml` | Tasks for the new role: team accounts, document roots, pages, virtual hosts, firewall ports |
| `site.conf.j2` | Template used by those tasks |
| `sites.yml` | `team_sites`: team alpha on port 8181, team bravo on port 8182 |
| `selinux.yml` | Variables for `redhat.rhel_system_roles.selinux` |
| `collections/` | `ansible.posix` and `redhat.rhel_system_roles` |

It removes any earlier portal from serverb, including SELinux port labels.

---

## Requirements

**1. Collection.** Create `collections/requirements.yml` that installs the `community.general` archive published on `http://materials.example.com/collections/`, and install it into the project's `collections/` directory.

**2. Role from Git.** Create `roles/requirements.yml` that installs `infra.httpd` from the Git repository above, pinned to `v1.0.0`, and install it into the project's `roles/` directory. Make sure Ansible searches `./roles` for roles.

**3. Your role.** Create a role named `team.sites` in `roles/`:

* it depends on `infra.httpd`, declared with the same name, source, SCM, and version as in the requirements file;
* `site_tasks.yml` becomes its main task file and `site.conf.j2` its template; neither file remains in the project root;
* fill in the role's `meta/main.yml` (author, description, license).

**4. Variables.** `sites.yml` and `selinux.yml` provide variables for the hosts of group `portal`; place them accordingly.

**5. Playbook `portal.yml`,** one play named `Configure the team portal` for group `portal` with privilege escalation, which forces notified handlers to run even if a later task fails, and whose tasks are, in this order:

1. include the role `redhat.rhel_system_roles.selinux`;
2. include the role `team.sites`;
3. with `community.general.ini_file`, record in `/etc/portal.ini`, section `portal`, option `teams`, the comma separated names of all teams in `team_sites` (mode 0644).

**6. Run** the playbook until it succeeds. The main page on port 80 and both team pages must answer:

* `http://serverb.lab.example.com`
* `http://serverb.lab.example.com:8181`
* `http://serverb.lab.example.com:8182`

Tip: build the playbook with only step 5.2 first and run it once. Read why the handler fails, then add step 5.1.

---

## Grade

```bash
lab grade roles_review
```

| Area | Checks |
|---|---|
| Requirements | Git entry for `infra.httpd` with `scm: git`; `community.general` installed from `collections/requirements.yml` |
| Roles | `infra.httpd` installed; `team.sites` has the tasks and template, depends on `infra.httpd`; originals moved |
| Variables | `sites.yml` and `selinux.yml` in `group_vars/portal/` |
| Playbook | Hosts `portal`, `become`, `force_handlers`, selinux role before `team.sites` |
| serverb | 8181 and 8182 labeled `http_port_t`; httpd running; ports open; all three pages served; `/etc/portal.ini` correct |

## Finish

```bash
lab finish roles_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 07 Quiz: Roles and Collections](04_quiz.md) | Next: [Chapter 07 Lab Solution: `roles_review`](06_lab_solution.md) →

<!-- navfoot:end -->
