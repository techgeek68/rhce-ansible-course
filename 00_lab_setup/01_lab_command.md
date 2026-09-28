<!-- nav:start -->
[Course home](../README.md) › [00 Lab Setup: Build the Complete Lab, Step 1 to Step 6](README.md) › Guide (2 of 2)
<!-- nav:end -->

# 00 Lab Setup Reference: How the `lab` Command Works

The Red Hat classroom prepares, grades, and cleans every activity with one command:

```
[student@workstation ~]$ lab action exercise
```

That command is proprietary and is not available in the local lab. This course ships a replacement with **the same syntax, the same three actions, the same PASS/FAIL grading output, and the same tab completion**, written entirely in Bash and Ansible. Every chapter in this repository ships its exercises for this framework, so your daily routine is identical to the official course.

**This page is optional reading.** You do not need it to build the lab: Step 6 of the [lab build guide](README.md) installs and tests the framework from the course repository. Read it when you want to understand how exercises are prepared and graded, when a `lab` command fails, or when you write exercises of your own.

---

## 1. How Course Activity Types Map to This Repository

| Official activity | What it is | Where it lives in this repository | `lab` actions |
|---|---|---|---|
| Guided exercise | Procedure walked through step by step after a lesson section | `NN_chapter/NN_guided_exercise_NAME.md` | `start`, `finish` |
| Quiz | Knowledge check | `NN_chapter/NN_quiz.md`, answers hidden in collapsible blocks | none |
| End of chapter lab | High level requirements, no commands given, graded | `NN_chapter/NN_lab.md`, solution in `NN_chapter/NN_lab_solution.md` | `start`, `grade`, `finish` |

Exercise names use underscores (for example `sample_webserver`) instead of the hyphenated names used in the official course.

---

## 2. How the Framework Works

```
lab start sample_webserver
  |
  +==> reads /opt/rh294lab/exercises/sample_webserver/info    (HOSTS, DESCRIPTION)
  +==> ansible-playbook lib/precheck.yml                       (every host in HOSTS answers)
  +==> ansible-playbook exercises/sample_webserver/start.yml   (creates ~/sample_webserver, resets hosts)
  +==> prints SUCCESS or FAIL, full output saved in ~/.lab/logs/sample_webserver_start.log

lab grade sample_webserver
  +==> grade.yml runs read only checks on the managed hosts
  +==> each check appends "PASS|text" or "FAIL|text" to a temporary results file on workstation
  +==> lab prints one PASS/FAIL line per criterion and the overall grade (exit code 0 only when all pass)
```

Design decisions that matter for you as a student:

1. **The framework uses its own `ansible.cfg`** (`/opt/rh294lab/ansible.cfg`, forced through `ANSIBLE_CONFIG`). Whatever you break in your project `ansible.cfg` never breaks `lab` itself, and `lab` never touches your configuration.
2. **Framework playbooks use only `ansible.builtin` modules**, so they work before you have installed any collection. Your own solutions are expected to use collections like `ansible.posix`, exactly as the exam expects.
3. **`start` never overwrites your files.** It copies `ansible.cfg` and `inventory` into the exercise directory with `force: false`, so running `lab start` again keeps your edits.
4. **Every exercise is independent.** `start` puts its hosts into the required state on its own, so you can run any exercise in any order, just like the official course.
5. **Grading only reads.** `grade.yml` never changes a managed host, so you can grade, fix, and grade again as many times as you want.

---

## 3. Framework Layout

```
rhce_ansible_course/lab_framework/
    install.sh                  installs everything below onto workstation
    ansible.cfg                 framework configuration (not yours)
    inventory                   framework inventory: workstation (local) + servera..serverd
    bin/lab                     the lab command
    completion/lab              bash tab completion
    lib/precheck.yml            reachability check run before every action
    lib/record.yml              records one PASS/FAIL grading result
    exercises/
        sample_webserver/       template exercise used to test the framework
            info                DESCRIPTION and HOSTS
            start.yml
            grade.yml           present only for gradable activities
            finish.yml
            files/              files that start.yml hands to the student
```

Installed locations on workstation:

| Source | Installed to |
|---|---|
| `bin/lab` | `/usr/local/bin/lab` |
| `completion/lab` | `/etc/bash_completion.d/lab` |
| `ansible.cfg`, `inventory`, `lib/`, `exercises/` | `/opt/rh294lab/` |
| Logs | `~/.lab/logs/EXERCISE_ACTION.log` |

---

## 4. The Framework Files, Explained

The course repository already contains every file below in `lab_framework/`, and Step 6.3 of the [build guide](README.md#63-put-the-course-on-workstation-and-install-the-lab-command) installs them. The commands show how each file was created, which is useful only if you rebuild the framework from scratch.

Log in to workstation as `student` and create the directory tree inside your course repository:

```bash
mkdir -p ~/rhce_ansible_course/lab_framework/{bin,completion,lib,exercises/sample_webserver/files}
cd ~/rhce_ansible_course/lab_framework
```

### 4.1 The `lab` command

```bash
cat > bin/lab <<'LAB_EOF'
#!/usr/bin/env bash
# lab: local replacement for the RH294 classroom lab command.
# Usage: lab start|grade|finish EXERCISE    or    lab list
set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/opt/rh294lab}"
EX_DIR="$LAB_ROOT/exercises"
LIB_DIR="$LAB_ROOT/lib"
LOG_DIR="$HOME/.lab/logs"
export ANSIBLE_CONFIG="$LAB_ROOT/ansible.cfg"

if [[ -t 1 ]]; then
  GREEN=$'\e[1;32m'; RED=$'\e[1;31m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  GREEN=''; RED=''; BOLD=''; RESET=''
fi

usage() {
  echo "Usage: lab start|grade|finish EXERCISE"
  echo "       lab list"
  exit 1
}

list_exercises() {
  local d name kind desc
  for d in "$EX_DIR"/*/; do
    [[ -d $d ]] || continue
    name=$(basename "$d")
    kind="exercise"
    [[ -f $d/grade.yml ]] && kind="gradable"
    desc=$(DESCRIPTION=''; source "$d/info" 2>/dev/null; echo "$DESCRIPTION")
    printf '%-32s %-9s %s\n' "$name" "$kind" "$desc"
  done
}

play() {
  local playbook=$1; shift
  ansible-playbook "$playbook" \
    -e "lab_exercise=$EXERCISE" \
    -e "lab_lib=$LIB_DIR" \
    -e "lab_files=$EX_DIR/$EXERCISE/files" \
    -e "lab_hosts=$LAB_HOSTS" \
    "$@" >>"$LOG" 2>&1
}

step() {
  local msg=$1; shift
  printf ' · %-58s' "$msg"
  if "$@"; then
    printf '%sSUCCESS%s\n' "$GREEN" "$RESET"
  else
    printf '%sFAIL%s\n' "$RED" "$RESET"
    echo
    echo "Details are in $LOG"
    exit 1
  fi
}

[[ $# -eq 1 && $1 == list ]] && { list_exercises; exit 0; }
[[ $# -eq 2 ]] || usage

ACTION=$1
EXERCISE=$2
[[ -d $EX_DIR/$EXERCISE ]] || { echo "Unknown exercise: $EXERCISE. Run: lab list"; exit 1; }

HOSTS="workstation"
DESCRIPTION=""
source "$EX_DIR/$EXERCISE/info"
LAB_HOSTS="${HOSTS// /,}"

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/${EXERCISE}_${ACTION}.log"
: > "$LOG"

case $ACTION in
  start)
    echo
    echo "${BOLD}Starting lab: $EXERCISE${RESET}"
    echo
    step "Checking that lab systems are reachable" play "$LIB_DIR/precheck.yml"
    step "Preparing the environment for $EXERCISE" play "$EX_DIR/$EXERCISE/start.yml"
    echo
    ;;
  grade)
    [[ -f $EX_DIR/$EXERCISE/grade.yml ]] || { echo "$EXERCISE is not a gradable activity."; exit 1; }
    RESULTS=$(mktemp)
    trap 'rm -f "$RESULTS"' EXIT
    echo
    echo "${BOLD}Grading lab: $EXERCISE${RESET}"
    echo
    step "Checking that lab systems are reachable" play "$LIB_DIR/precheck.yml"
    play "$EX_DIR/$EXERCISE/grade.yml" -e "lab_results_file=$RESULTS"
    grade_rc=$?
    fails=0
    while IFS='|' read -r status text; do
      if [[ $status == PASS ]]; then
        printf ' · %-58s%sPASS%s\n' "$text" "$GREEN" "$RESET"
      else
        printf ' · %-58s%sFAIL%s\n' "$text" "$RED" "$RESET"
        fails=$((fails + 1))
      fi
    done < "$RESULTS"
    if [[ $grade_rc -ne 0 || ! -s $RESULTS ]]; then
      printf ' · %-58s%sFAIL%s\n' "Grading completed on every host" "$RED" "$RESET"
      echo "   Details are in $LOG"
      fails=$((fails + 1))
    fi
    echo
    if [[ $fails -eq 0 ]]; then
      echo "Overall lab grade: ${GREEN}PASS${RESET}"
    else
      echo "Overall lab grade: ${RED}FAIL${RESET}"
    fi
    echo
    [[ $fails -eq 0 ]]
    ;;
  finish)
    echo
    echo "${BOLD}Finishing lab: $EXERCISE${RESET}"
    echo
    step "Checking that lab systems are reachable" play "$LIB_DIR/precheck.yml"
    step "Cleaning up $EXERCISE" play "$EX_DIR/$EXERCISE/finish.yml"
    echo
    ;;
  *)
    usage
    ;;
esac
LAB_EOF
```

### 4.2 Tab completion

`lab start` followed by Tab twice lists every exercise; `lab grade` followed by Tab twice lists only gradable ones.

```bash
cat > completion/lab <<'LAB_EOF'
# Bash completion for the local lab command
_lab() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local root=${LAB_ROOT:-/opt/rh294lab}/exercises
  local names d
  if (( COMP_CWORD == 1 )); then
    COMPREPLY=( $(compgen -W "start grade finish list" -- "$cur") )
  elif (( COMP_CWORD == 2 )); then
    names=""
    if [[ ${COMP_WORDS[1]} == grade ]]; then
      for d in "$root"/*/grade.yml; do [[ -e $d ]] && names+=" $(basename "$(dirname "$d")")"; done
    else
      for d in "$root"/*/; do [[ -d $d ]] && names+=" $(basename "$d")"; done
    fi
    COMPREPLY=( $(compgen -W "$names" -- "$cur") )
  fi
}
complete -F _lab lab
LAB_EOF
```

### 4.3 Framework configuration and inventory

```bash
cat > ansible.cfg <<'LAB_EOF'
[defaults]
inventory = /opt/rh294lab/inventory
remote_user = devops
host_key_checking = false
interpreter_python = auto_silent
retry_files_enabled = false
forks = 10

[privilege_escalation]
become = false
become_method = sudo
become_user = root
LAB_EOF
```

`host_key_checking = false` applies to the framework only. It keeps `lab` working after you rebuild a VM and its SSH host key changes. Keep host key checking on in your own projects.

```bash
cat > inventory <<'LAB_EOF'
workstation ansible_connection=local ansible_python_interpreter=/usr/bin/python3 ansible_become_password=student

# Content server; only used to publish lab repositories
utility ansible_host=utility.lab.example.com ansible_user=student ansible_become_password=student

[managed]
servera ansible_host=servera.lab.example.com
serverb ansible_host=serverb.lab.example.com
serverc ansible_host=serverc.lab.example.com
serverd ansible_host=serverd.lab.example.com

[all:vars]
gitea_url=http://utility.lab.example.com:3000
gitea_user=student
gitea_password=Student@123
lab_registry=utility.lab.example.com:5000
LAB_EOF
```

`workstation` is managed through a local connection, so exercises can prepare files in your home directory. The sudo password is stored here only so a `start.yml` can install packages on workstation when an exercise needs it; `install.sh` makes this file readable only by root and the `student` group.

### 4.4 Shared playbooks

```bash
cat > lib/precheck.yml <<'LAB_EOF'
---
- name: Verify that the lab systems for this exercise respond
  hosts: "{{ lab_hosts }}"
  gather_facts: false
  tasks:
    - name: Reach each host through SSH and Python
      ansible.builtin.ping:
LAB_EOF
```

```bash
cat > lib/record.yml <<'LAB_EOF'
---
# Appends one grading result to the results file on workstation.
# Required variables: lab_check (text), lab_pass (boolean expression)
- name: "Record result: {{ lab_check }}"
  ansible.builtin.lineinfile:
    path: "{{ lab_results_file }}"
    line: "{{ 'PASS' if (lab_pass | bool) else 'FAIL' }}|{{ lab_check }}"
    create: true
    mode: "0600"
  delegate_to: workstation
  become: false
  throttle: 1
LAB_EOF
```

`throttle: 1` serializes writes, so four hosts grading in parallel never corrupt the results file. `delegate_to: workstation` with `become: false` writes the file as `student`.

### 4.5 Installer

```bash
cat > install.sh <<'LAB_EOF'
#!/usr/bin/env bash
# Installs the lab framework on workstation. Run as student from this directory.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST=/opt/rh294lab

sudo mkdir -p "$DEST"
sudo rm -rf "$DEST/lib" "$DEST/exercises"
sudo cp -r "$SRC/lib" "$SRC/exercises" "$SRC/ansible.cfg" "$SRC/inventory" "$DEST/"
sudo chmod -R a+rX "$DEST"
sudo chmod 0640 "$DEST/inventory"
sudo chgrp student "$DEST/inventory"
sudo install -m 0755 "$SRC/bin/lab" /usr/local/bin/lab
sudo install -m 0644 "$SRC/completion/lab" /etc/bash_completion.d/lab
echo "Installed. Open a new terminal, then run: lab list"
LAB_EOF
```

```bash
chmod +x bin/lab install.sh
```

---

## 5. The Template Exercise: `sample_webserver`

This exercise proves the framework end to end and is the pattern every chapter follows. The task it grades: install httpd on servera, serve a page that says `Welcome to servera`, start and enable the service, and open http permanently in firewalld.

```bash
cat > exercises/sample_webserver/info <<'LAB_EOF'
DESCRIPTION="Framework template: web server on servera"
HOSTS="workstation servera"
LAB_EOF
```

```bash
cat > exercises/sample_webserver/files/ansible.cfg <<'LAB_EOF'
[defaults]
inventory = ./inventory
remote_user = devops
collections_path = ./collections:/usr/share/ansible/collections

[privilege_escalation]
become = true
become_method = sudo
become_user = root
become_ask_pass = false
LAB_EOF
```

```bash
cat > exercises/sample_webserver/files/inventory <<'LAB_EOF'
[webservers]
servera.lab.example.com
LAB_EOF
```

```bash
cat > exercises/sample_webserver/start.yml <<'LAB_EOF'
---
- name: Prepare the working directory on workstation
  hosts: workstation
  gather_facts: false
  vars:
    workdir: "/home/student/{{ lab_exercise }}"
  tasks:
    - name: Create the exercise directory
      ansible.builtin.file:
        path: "{{ workdir }}"
        state: directory
        mode: "0755"

    - name: Provide ansible.cfg and inventory without overwriting student edits
      ansible.builtin.copy:
        src: "{{ lab_files }}/{{ item }}"
        dest: "{{ workdir }}/{{ item }}"
        mode: "0644"
        force: false
      loop:
        - ansible.cfg
        - inventory

- name: Put servera into a known starting state
  hosts: servera
  become: true
  gather_facts: false
  tasks:
    - name: Remove httpd left over from an earlier attempt
      ansible.builtin.dnf:
        name: httpd
        state: absent

    - name: Remove leftover web content
      ansible.builtin.file:
        path: /var/www/html/index.html
        state: absent

    - name: Close the http service in the permanent firewall configuration
      ansible.builtin.command: firewall-cmd --permanent --remove-service=http
      register: fw
      changed_when: "'success' in fw.stdout"
      failed_when: false

    - name: Reload the firewall
      ansible.builtin.command: firewall-cmd --reload
      changed_when: false
LAB_EOF
```

```bash
cat > exercises/sample_webserver/grade.yml <<'LAB_EOF'
---
- name: Grade the web server on servera
  hosts: servera
  become: true
  gather_facts: false
  tasks:
    - name: Query the httpd package
      ansible.builtin.command: rpm -q httpd
      register: pkg
      changed_when: false
      failed_when: false

    - name: Grade package installation
      ansible.builtin.include_tasks: "{{ lab_lib }}/record.yml"
      vars:
        lab_check: "httpd is installed on servera"
        lab_pass: "{{ pkg.rc == 0 }}"

    - name: Query the httpd service state
      ansible.builtin.command: systemctl is-active httpd
      register: active
      changed_when: false
      failed_when: false

    - name: Grade service state
      ansible.builtin.include_tasks: "{{ lab_lib }}/record.yml"
      vars:
        lab_check: "httpd is running on servera"
        lab_pass: "{{ active.stdout == 'active' }}"

    - name: Query the httpd service boot setting
      ansible.builtin.command: systemctl is-enabled httpd
      register: enabled
      changed_when: false
      failed_when: false

    - name: Grade boot setting
      ansible.builtin.include_tasks: "{{ lab_lib }}/record.yml"
      vars:
        lab_check: "httpd starts at boot on servera"
        lab_pass: "{{ enabled.stdout == 'enabled' }}"

    - name: Query the permanent firewall configuration
      ansible.builtin.command: firewall-cmd --permanent --query-service=http
      register: fw
      changed_when: false
      failed_when: false

    - name: Grade firewall configuration
      ansible.builtin.include_tasks: "{{ lab_lib }}/record.yml"
      vars:
        lab_check: "http is permanently allowed in firewalld on servera"
        lab_pass: "{{ fw.rc == 0 }}"

    - name: Fetch the home page from workstation
      ansible.builtin.uri:
        url: http://servera.lab.example.com/
        return_content: true
      register: page
      delegate_to: workstation
      become: false
      failed_when: false

    - name: Grade web content
      ansible.builtin.include_tasks: "{{ lab_lib }}/record.yml"
      vars:
        lab_check: "Home page shows 'Welcome to servera'"
        lab_pass: "{{ page.status | default(0) == 200 and 'Welcome to servera' in page.content | default('') }}"
LAB_EOF
```

```bash
cat > exercises/sample_webserver/finish.yml <<'LAB_EOF'
---
- name: Return servera to its clean state
  hosts: servera
  become: true
  gather_facts: false
  tasks:
    - name: Remove httpd
      ansible.builtin.dnf:
        name: httpd
        state: absent

    - name: Remove web content
      ansible.builtin.file:
        path: /var/www/html/index.html
        state: absent

    - name: Close the http service in the permanent firewall configuration
      ansible.builtin.command: firewall-cmd --permanent --remove-service=http
      register: fw
      changed_when: "'success' in fw.stdout"
      failed_when: false

    - name: Reload the firewall
      ansible.builtin.command: firewall-cmd --reload
      changed_when: false
LAB_EOF
```

Every check in `grade.yml` follows the same two task pattern: a read only probe with `changed_when: false` and `failed_when: false`, then `record.yml` with a sentence and a boolean. A probe must never fail the play, otherwise the remaining criteria are not graded.

---

## 6. Install and Verify

```bash
cd ~/rhce_ansible_course/lab_framework
./install.sh
exec bash
lab list
```

Expected:

```
sample_webserver                 gradable  Framework template: web server on servera
```

Check completion: type `lab gr`, press Tab (completes to `grade`), then press Tab twice more (lists `sample_webserver`).

---

## 7. Full Test Cycle

### 7.1 Start

```
[student@workstation ~]$ lab start sample_webserver

Starting lab: sample_webserver

 · Checking that lab systems are reachable                   SUCCESS
 · Preparing the environment for sample_webserver            SUCCESS
```

### 7.2 Grade before doing any work

```
[student@workstation ~]$ lab grade sample_webserver

Grading lab: sample_webserver

 · Checking that lab systems are reachable                   SUCCESS
 · httpd is installed on servera                             FAIL
 · httpd is running on servera                               FAIL
 · httpd starts at boot on servera                           FAIL
 · http is permanently allowed in firewalld on servera       FAIL
 · Home page shows 'Welcome to servera'                      FAIL

Overall lab grade: FAIL
```

### 7.3 Solve it

Install `ansible.posix` from the materials server into the project:

```bash
cd ~/sample_webserver
POSIX=$(curl -s http://materials.example.com/collections/ | grep -o 'ansible-posix-[0-9.]*\.tar\.gz' | head -1)
ansible-galaxy collection install -p collections "http://materials.example.com/collections/$POSIX"
ansible-galaxy collection list ansible.posix
```

Create `site.yml`:

```yaml
---
- name: Deploy a web server on servera
  hosts: webservers
  tasks:
    - name: Install httpd
      ansible.builtin.dnf:
        name: httpd
        state: present

    - name: Publish the home page
      ansible.builtin.copy:
        content: "Welcome to servera\n"
        dest: /var/www/html/index.html
        mode: "0644"

    - name: Start httpd now and at boot
      ansible.builtin.service:
        name: httpd
        state: started
        enabled: true

    - name: Allow http now and after reboot
      ansible.posix.firewalld:
        service: http
        permanent: true
        immediate: true
        state: enabled
```

```bash
ansible-playbook site.yml
```

### 7.4 Grade again

```
 · Checking that lab systems are reachable                   SUCCESS
 · httpd is installed on servera                             PASS
 · httpd is running on servera                               PASS
 · httpd starts at boot on servera                           PASS
 · http is permanently allowed in firewalld on servera       PASS
 · Home page shows 'Welcome to servera'                      PASS

Overall lab grade: PASS
```

`echo $?` prints `0`.

### 7.5 Finish, then prove the cleanup

```bash
lab finish sample_webserver
lab grade sample_webserver     # every criterion is FAIL again
```

When 7.1 to 7.5 behave as shown, the framework is ready for every chapter.

---

## 8. Contract for Chapter Exercises

Every exercise added in later chapters follows these rules. Use them also if you write your own practice tasks.

| File | Required | Rules |
|---|---|---|
| `info` | Yes | Bash syntax. `DESCRIPTION` is one line. `HOSTS` lists every host the exercise touches, space separated, including `workstation` when `start.yml` creates files there |
| `start.yml` | Yes | Creates `/home/student/EXERCISE`, copies `files/` into it with `force: false`, and drives each host into the starting state regardless of what earlier exercises left behind. Must be idempotent |
| `grade.yml` | Only for end of chapter labs and comprehensive reviews | Read only probes plus `record.yml`. One criterion per `record.yml` call. Wording states the expected outcome, not the command |
| `finish.yml` | Yes | Removes everything `start.yml` created and everything the solution creates on managed hosts. Never deletes `/home/student/EXERCISE`, so your work stays available for review |
| `files/` | When needed | Starter `ansible.cfg`, `inventory`, broken playbooks to debug, templates, variable files |

Framework playbooks may use only `ansible.builtin` modules. Where a module from a collection would normally be used (for example firewalld), use `ansible.builtin.command` with explicit `changed_when` and `failed_when`, as `start.yml` above does.

---

## 9. `lab finish` Versus a Snapshot Revert

| Situation | Use |
|---|---|
| Finished an exercise normally | `lab finish EXERCISE` on workstation |
| `lab finish` fails, or you broke a managed host badly (sudoers, SSH, networking, bootloader) | Revert servera to serverd to the `baseline` snapshot ([Reset to the clean state](README.md#reset-to-the-clean-state)) |
| Starting a timed mock exam | Revert the managed hosts to `baseline`, then `lab start` for the exam |
| `lab` itself stops working after you edited the framework | `cd ~/rhce_ansible_course/lab_framework && git checkout . && ./install.sh` |

---

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `lab: command not found` | Installer not run or new shell not opened | Run `./install.sh`, then `exec bash` |
| Tab completion does nothing | `bash-completion` package missing | `sudo dnf install -y bash-completion`, then open a new terminal |
| `Checking that lab systems are reachable ... FAIL` | A VM is off, or SSH as devops fails | Check the VM is running in your hypervisor; on workstation `ssh devops@servera hostname`; read `~/.lab/logs/*_start.log` |
| `Grading completed on every host ... FAIL` | A probe failed the play instead of being recorded | Read `~/.lab/logs/EXERCISE_grade.log`; every probe needs `failed_when: false` |
| All criteria FAIL right after a correct solution | Solution ran against the wrong inventory | Run `ansible-inventory --graph` inside `~/EXERCISE` and confirm `ansible --version` shows `config file = /home/student/EXERCISE/ansible.cfg` |
| `Unknown exercise` | Exercise folder not installed | Pull the latest repository and run `./install.sh` again |
| Start fails on workstation tasks with a sudo error | Wrong password in `/opt/rh294lab/inventory` | It must match the student password (`student`) |

---

## 11. Commit the Framework

Only if you built the framework yourself, record it in your own repository:

```bash
cd ~/rhce_ansible_course
git add lab_framework
git commit -m "Add local lab framework with start, grade, finish"
```

Each following chapter adds its exercises under `lab_framework/exercises/` and tells you to run `./install.sh` again before starting.

<!-- navfoot:start -->

---

← Previous: [00 Lab Setup: Build the Complete Lab, Step 1 to Step 6](README.md) | Next: [Chapter 01: Introduction to Ansible](../01_introduction/README.md) →

<!-- navfoot:end -->
