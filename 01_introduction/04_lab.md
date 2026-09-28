<!-- nav:start -->
[Course home](../README.md) › [Chapter 01: Introduction to Ansible](README.md) › Graded lab (5 of 6)
<!-- nav:end -->

# Chapter 01 Lab: Configure a Project, Run It Through an Execution Environment, Publish It

| | |
|---|---|
| **Exercise name** | `intro_review` |
| **Time limit** | 20 minutes (exam pace) |
| **Rules** | Terminal only. No VS Code, no copying from the chapter or the guided exercises. `ansible-doc`, `ansible-config`, man pages, and `--help` are allowed, as on the exam |
| **Solution** | [05_lab_solution.md](05_lab_solution.md), open it only after grading |

```bash
lab start intro_review
```

Start creates `/home/student/intro_review` containing `inventory` and `mark_hosts.yml`, creates an empty repository `intro_review` on the lab Gitea server, and removes any marker files left on the managed hosts by earlier attempts.

---

## Requirements

Work as `student` on workstation.

**1. Git identity.** Commits you make on workstation must be authored by `Student User` with the email address `student@lab.example.com`.

**2. Ansible configuration.** Create `/home/student/intro_review/ansible.cfg` so that, when Ansible runs from that directory:

* the inventory is the `inventory` file in the same directory;
* Ansible logs in to managed hosts as `devops` using SSH keys, without prompting for an SSH password;
* every play runs with privilege escalation through `sudo` to `root` by default, without prompting for a sudo password;
* playbook output is also written to `ansible.log` in the project directory.

**3. Automation content navigator.** Create `/home/student/intro_review/ansible-navigator.yml` so that `ansible-navigator`, started from that directory:

* runs content in an execution environment with Podman;
* uses the image `utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest`;
* pulls the image only when it is not present locally, with TLS verification disabled;
* prints output directly to the terminal;
* does not create playbook artifact files.

**4. Run the provided playbook.** Use `ansible-navigator` to run `mark_hosts.yml` against all managed hosts. Do **not** edit `mark_hosts.yml`. When you are done, every managed host must have `/etc/intro_review_marker` owned by `root`, whose content shows that the tasks ran as root.

**5. Version control.** Turn `/home/student/intro_review` into a Git repository on branch `main`:

* add a `.gitignore` that excludes `ansible.log` and playbook artifact files;
* commit all project files;
* push to `http://utility.lab.example.com:3000/student/intro_review.git` (credentials `student` / `Student@123`).

---

## Grade

```bash
lab grade intro_review
```

Criteria checked:

| Criterion | What is checked |
|---|---|
| Active configuration | `ansible.cfg` in the project is the file Ansible uses |
| Inventory | `inventory` setting resolves to the project inventory |
| Remote user | `devops` |
| Privilege escalation | enabled by default |
| Log file | `log_path` resolves to `intro_review/ansible.log` |
| Navigator image | EE enabled with the exact lab image |
| Pull settings | policy `missing`, argument `--tls-verify=false` |
| Output | mode `stdout` |
| Artifacts | disabled |
| Commit author | latest pushed commit has `student@lab.example.com` |
| Pushed files | `ansible.cfg` and `ansible-navigator.yml` exist on Gitea |
| Markers | `/etc/intro_review_marker` on all four servers, owned by root, written as root |

Fix every `FAIL` and grade again until the overall result is `PASS`.

## Finish

```bash
lab finish intro_review
```

Finish removes the marker files from the managed hosts. Your project directory and the Gitea repository remain.

<!-- navfoot:start -->

---

← Previous: [Chapter 01 Quiz: How Ansible Works and How It Is Configured](03_quiz.md) | Next: [Chapter 01 Lab Solution: `intro_review`](05_lab_solution.md) →

<!-- navfoot:end -->
