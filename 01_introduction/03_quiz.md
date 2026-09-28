<!-- nav:start -->
[Course home](../README.md) › [Chapter 01: Introduction to Ansible](README.md) › Quiz (4 of 6)
<!-- nav:end -->

# Chapter 01 Quiz: How Ansible Works and How It Is Configured

Answer every question before opening any answer. Target: 11 of 12 correct. If you score lower, reread the section named in the explanation.

---

**1.** You run a playbook against servera, serverb, serverc, and serverd. The third task fails on serverb. What happens next?

* A. The play stops for all four hosts.
* B. serverb stops running tasks; servera, serverc, and serverd continue.
* C. serverb retries the task three times, then continues with the next task.
* D. Ansible rolls back the first two tasks on serverb.

<details><summary>Answer</summary>

**B.** A task failure removes only the failing host from the rest of the play. There is no automatic retry and no rollback. (README section 1.4)
</details>

---

**2.** Which of these must be present on a Linux managed host for ordinary modules to work?

* A. The `ansible-core` package
* B. A running Ansible agent service
* C. Python 3 and an SSH server
* D. Podman

<details><summary>Answer</summary>

**C.** Ansible is agentless. It copies each module over SSH and runs it with the host's Python. Only `ansible.builtin.raw` works without Python. (Section 1.3)
</details>

---

**3.** A playbook runs twice in a row against a correctly configured host. The second recap shows `changed=3`. What does this most likely indicate?

* A. Three tasks are not idempotent, for example `command` tasks without `changed_when`.
* B. The host drifted between runs.
* C. Normal behavior; every run reports changes.
* D. Privilege escalation is disabled.

<details><summary>Answer</summary>

**A.** A second run against an unchanged, correct host should report `changed=0`. Repeated changes usually come from `command` or `shell` tasks, or modules used in a way that rewrites content every time. B is possible but unlikely seconds apart. (Section 1.1)
</details>

---

**4.** You need `ansible.posix.firewalld` on a control node that has only the `ansible-core` RPM. What is true?

* A. It is already included, because ansible-core ships all modules.
* B. You must install the `ansible.posix` collection.
* C. You must switch to the community `ansible` package; collections cannot be installed separately.
* D. You must write it as `firewalld:` so Ansible finds it automatically.

<details><summary>Answer</summary>

**B.** ansible-core contains only `ansible.builtin`. Everything else comes from collections, installed with `ansible-galaxy collection install` or provided by an execution environment. (Section 1.5)
</details>

---

**5.** In `/home/student/project` you run `ansible --version`. The project directory contains `ansible.cfg`, and `~/.ansible.cfg` also exists with `forks = 20`. The project file does not mention forks. How many forks does Ansible use?

* A. 20, because unmentioned settings fall through to `~/.ansible.cfg`.
* B. 5, the default, because only the project file is read.
* C. 20, because the home file has higher precedence.
* D. It depends on the order of the sections.

<details><summary>Answer</summary>

**B.** Ansible uses exactly one configuration file, the first found. It does not merge files, so the home file is ignored completely. (Section 3.2)
</details>

---

**6.** A colleague keeps a project in `/tmp/shared` with permissions `drwxrwxrwx`. Their `ansible.cfg` there seems to be ignored. Why?

* A. Ansible never reads files under `/tmp`.
* B. Ansible refuses to load `ansible.cfg` from a world writable current directory.
* C. The file must be named `.ansible.cfg` in shared directories.
* D. SELinux blocks reading it.

<details><summary>Answer</summary>

**B.** Loading configuration from a directory anyone can write to would let any user control your Ansible runs, so Ansible warns and skips it. Fix the directory permissions or point `ANSIBLE_CONFIG` at the file. (Section 3.2)
</details>

---

**7.** `ansible.cfg` contains `remote_user = devops`. The play contains `remote_user: student`. You run `ansible-playbook site.yml -u admin`. Which user connects?

* A. devops
* B. admin
* C. student
* D. root

<details><summary>Answer</summary>

**C.** Playbook keywords outrank command line options, which outrank the configuration file. Only a variable such as `ansible_user` would outrank the play keyword. (Section 3.1)
</details>

---

**8.** Your project has no `remote_user` setting. `ansible-playbook` works, but `ansible-navigator run` fails with `Permission denied (publickey)`. What is the cause?

* A. The execution environment has no SSH client.
* B. Inside the execution environment the default login user is `root`, which has no authorized key on the servers.
* C. ansible-navigator does not read `ansible.cfg`.
* D. Host key checking is enabled.

<details><summary>Answer</summary>

**B.** Locally, the default remote user is the account running Ansible (student). Inside the container, it is root. Always set `remote_user` in the project file. (Section 3.3)
</details>

---

**9.** Which line in `ansible.cfg` sets the remote user to exactly `devops`?

* A. `remote_user = devops # automation account`
* B. `remote_user = devops ; automation account`
* C. `remote_user: devops`
* D. `remote_user = "devops" # automation account`

<details><summary>Answer</summary>

**B.** A semicolon starts an inline comment in `ansible.cfg`. A number sign only starts a comment at the beginning of a line, so A and D include the comment in the value. C is YAML syntax, not INI. (Section 3.7)
</details>

---

**10.** You want `ansible-navigator run site.yml --ask-vault-pass` to prompt you for a password. Which combination is required?

* A. `mode: interactive` and artifacts enabled
* B. `mode: stdout` and artifacts disabled
* C. `mode: stdout` and artifacts enabled
* D. Any mode, as long as `container-engine: podman`

<details><summary>Answer</summary>

**B.** The interactive TUI cannot display a prompt, and playbook artifacts must be disabled for runs that prompt for passwords. (Section 3.8)
</details>

---

**11.** Which `ansible-navigator.yml` fragment matches the command line option `--pp missing`?

* A. `execution-environment: {pull: {policy: missing}}`
* B. `execution-environment: {policy: missing}`
* C. `playbook-artifact: {policy: missing}`
* D. `mode: missing`

<details><summary>Answer</summary>

**A.** `--pp` is the pull policy, nested under `execution-environment.pull.policy`. (Section 3.8)
</details>

---

**12.** You configured the Ansible extension in VS Code to use image X, and `ansible-navigator.yml` uses image Y. You then type `ansible-navigator run site.yml` in the VS Code terminal. Which image runs?

* A. X, because VS Code settings override project files.
* B. Y, because the terminal command reads `ansible-navigator.yml`.
* C. Both, one after the other.
* D. Neither; navigator refuses to run with conflicting settings.

<details><summary>Answer</summary>

**B.** Extension settings apply only to the **Run playbook via ansible-navigator** menu. The terminal command uses the navigator settings file. Keep both identical. (Section 2.3)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Configure Ansible and Automation Content Navigator](02_guided_exercise_intro_configure.md) | Next: [Chapter 01 Lab: Configure a Project, Run It Through an Execution Environment, Publish It](04_lab.md) →

<!-- navfoot:end -->
