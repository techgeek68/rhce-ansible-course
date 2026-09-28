<!-- nav:start -->
[Course home](../README.md) › [00 Lab Setup: Build the Complete RH294 Lab on Your Own Virtual Machines](README.md) › Guide (3 of 3)
<!-- nav:end -->

# 00 Lab Setup, Part 3: Developer Services

From Chapter 1 onward the course works the way a real automation team does: playbooks live in a Git server, run inside execution environment images, and are written in VS Code. `utility_setup.sh` and `workstation_setup.sh` (README sections 7 and 8) already installed the services and tools. This part fills them with content and connects the `lab` framework to them.

Prerequisites: `README.md` sections 1 to 9 are complete. Sections 5 and 6 of this page also need the framework from `01_lab_command.md`.

---

## 1. What Is Already in Place

| Component | Installed by | Address | Check from workstation |
|---|---|---|---|
| Container registry (plain HTTP) | `utility_setup.sh` | `utility.lab.example.com:5000` | `curl -s http://utility.lab.example.com:5000/v2/_catalog` |
| Gitea Git server, user `student` / `Student@123` | `utility_setup.sh` | `http://utility.lab.example.com:3000` | `curl -s http://utility.lab.example.com:3000/api/v1/version` |
| Collection tarball directory | `utility_setup.sh` | `http://materials.example.com/collections/` | `curl -s -o /dev/null -w '%{http_code}' http://materials.example.com/collections/` |
| Podman, Skopeo, Git, registry trust | `workstation_setup.sh` | local | `podman --version` |
| `ansible-navigator`, `ansible-lint`, `ansible-builder`, `podman-compose` | `workstation_setup.sh` | `~/.local/bin` | `ansible-navigator --version` |
| VS Code with Ansible and Dev Containers extensions | `workstation_setup.sh` | Activities overview | `code --list-extensions` |

What remains: put the two course images into the registry, mirror the collections, and install the framework exercises.

---

## 2. Mirror the Execution Environment Images

The course uses these image paths:

```
utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest
utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest
```

On workstation, log in with your Red Hat account and copy both images:

```bash
skopeo login registry.redhat.io

for img in ee-supported-rhel9 ansible-dev-tools-rhel9; do
  skopeo copy --dest-tls-verify=false \
    docker://registry.redhat.io/ansible-automation-platform-26/$img:latest \
    docker://utility.lab.example.com:5000/ansible-automation-platform-26/$img:latest
done
```

If the copy fails with `unauthorized`, your account cannot pull Ansible Automation Platform images. Store the community equivalents under the same lab paths so every course file keeps working:

```bash
skopeo copy --dest-tls-verify=false \
  docker://ghcr.io/ansible-community/community-ee-base:latest \
  docker://utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest

skopeo copy --dest-tls-verify=false \
  docker://ghcr.io/ansible/community-ansible-dev-tools:latest \
  docker://utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest
```

The community execution environment contains ansible-core and a small set of collections instead of the Red Hat certified set. When a later chapter needs a collection the community image lacks, that chapter installs it into the project.

Pre pull both images on workstation so the first exercise does not wait:

```bash
podman pull utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest
podman pull utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest
```

Apple Silicon: the Red Hat images are published for both architectures; `skopeo copy` picks the one matching workstation automatically.

---

## 3. Mirror Ansible Collections on materials.example.com

The exam hands you collections as tarballs on an internal web server. On workstation:

```bash
mkdir -p ~/collection_mirror
ansible-galaxy collection download -p ~/collection_mirror \
  ansible.posix community.general containers.podman
scp ~/collection_mirror/*.tar.gz utility:/tmp/
ssh -t utility 'sudo mv /tmp/*.tar.gz /var/www/html/materials/collections/ && sudo restorecon -R /var/www/html/materials'
curl -s http://materials.example.com/collections/ | grep -o '[a-z_]*-[a-z_]*-[0-9.]*\.tar\.gz' | sort -u
```

`redhat.rhel_system_roles` is already on workstation from the `rhel-system-roles` RPM.

---

## 4. Optional: Ansible Development Tools from the Subscription

`workstation_setup.sh` installed the tools from PyPI into a virtual environment, which needs no subscription. To use Red Hat's RPMs instead:

```bash
sudo subscription-manager register
sudo subscription-manager repos --list | grep -i 'ansible-automation-platform-2.6-for-rhel-9'
sudo subscription-manager repos --enable ansible-automation-platform-2.6-for-rhel-9-x86_64-rpms
sudo dnf install -y ansible-dev-tools || sudo dnf install -y ansible-navigator ansible-lint ansible-builder
rm -f ~/.local/bin/ansible-navigator ~/.local/bin/ansible-lint ~/.local/bin/ansible-builder
sudo subscription-manager repos --disable 'rhel-9-for-*'
```

The last line keeps operating system packages coming from the lab repositories, like every other VM.

---

## 5. Install the Framework Exercises

Clone the course onto workstation (workstation reaches the internet through bastion), then install the framework:

```bash
git clone https://github.com/techgeek68/rhce-ansible-course.git ~/rhce_ansible_course
cd ~/rhce_ansible_course/lab_framework
./install.sh
exec bash
lab list
```

Expected:

```
control_errors                   exercise  Guided: ignore_errors, force_handlers, failed_when, block
control_flow                     exercise  Guided: loops, loop_control, dict2items, conditions
control_handlers                 exercise  Guided: notify, listen, handler order, flush_handlers
control_review                   gradable  Chapter 4 lab: central logging with loops, handlers, blocks
develop_inventory                exercise  Guided: static inventory, groups, ranges, patterns
develop_multiplay                exercise  Guided: several plays, remote users, become_user
develop_review                   gradable  Chapter 2 lab: inventory, lint, multi play, idempotency
develop_singleplay               exercise  Guided: write, check, run, and replay one play
develop_troubleshoot             exercise  Guided: fix YAML, lint, runtime, and connection faults
files_manage                     exercise  Guided: copy, file, lineinfile, blockinfile, stat, find, fetch
files_review                     gradable  Chapter 5 lab: templates, links, line and block edits, find, fetch
files_templates                  exercise  Guided: Jinja2 templates, loops, conditions, filters
intro_configure                  exercise  Guided: ansible.cfg, ansible-navigator.yml, precedence
intro_devenv                     exercise  Guided: VS Code, dev container, Git workflow
intro_review                     gradable  Chapter 1 lab: configure, run, commit, push
roles_collections                exercise  Guided: install collections, shadowing, RHEL system roles
roles_create                     exercise  Guided: role skeleton, defaults, vars, handlers, argument specs
roles_external                   exercise  Guided: roles from an archive and from Git, versions, requirements
roles_review                     gradable  Chapter 7 lab: own role, Git dependency, collections, system role
sample_webserver                 gradable  Framework template: web server on servera
scale_files                      exercise  Guided: import_tasks, include_tasks, include_vars, import_playbook
scale_hosts                      exercise  Guided: host patterns, --limit, ansible_host, subscripts
scale_review                     gradable  Chapter 6 lab: refactor with patterns, imports, parameters
system_network                   exercise  Guided: network role, network facts, firewall zone
system_process                   exercise  Guided: cron, at, systemd timers, boot target, reboot
system_review                    gradable  Chapter 8 lab: repository, users, storage, cron, network, timer
system_roles                     exercise  Guided: timesync and selinux system roles, post_tasks, reboot handler
system_software                  exercise  Guided: yum_repository, rpm_key, dnf, package_facts, timers
system_storage                   exercise  Guided: storage role, LVM, swap, resize, mount, storage facts
system_users                     exercise  Guided: users, groups, keys, sudo, sshd, known_hosts
variables_facts                  exercise  Guided: facts, custom facts, set_fact, magic variables
variables_review                 gradable  Chapter 3 lab: group_vars, vault IDs, facts, custom facts
variables_vars                   exercise  Guided: play vars, group_vars, host_vars, precedence
variables_vault                  exercise  Guided: encrypt files and strings, vault IDs, no_log
```

The framework reads the Gitea and registry locations from these inventory variables, already present in `lab_framework/inventory`:

```ini
[all:vars]
gitea_url=http://utility.lab.example.com:3000
gitea_user=student
gitea_password=Student@123
lab_registry=utility.lab.example.com:5000
```

If you built the framework by hand from `01_lab_command.md`, add that block to `inventory` and create the two shared task files the Chapter 1 exercises use:

```bash
cat > lib/gitea_repo.yml <<'LAB_EOF'

When new chapters are published, update your copy and reinstall the exercises:

```bash
cd ~/rhce_ansible_course
git pull
cd lab_framework && ./install.sh
```

Your own exercise projects live in `/home/student/EXERCISE`, outside the clone, so `git pull` never touches your work.
---
# Recreates a repository on the lab Gitea server (utility:3000).
# Required variable: repo_name
# Optional variable: repo_src (directory whose contents become the first commit on main)
- name: "Delete repository {{ repo_name }} if it exists"
  ansible.builtin.uri:
    url: "{{ gitea_url }}/api/v1/repos/{{ gitea_user }}/{{ repo_name }}"
    method: DELETE
    url_username: "{{ gitea_user }}"
    url_password: "{{ gitea_password }}"
    force_basic_auth: true
    status_code: [204, 404]

- name: "Create empty repository {{ repo_name }}"
  ansible.builtin.uri:
    url: "{{ gitea_url }}/api/v1/user/repos"
    method: POST
    url_username: "{{ gitea_user }}"
    url_password: "{{ gitea_password }}"
    force_basic_auth: true
    body_format: json
    body:
      name: "{{ repo_name }}"
      private: false
      auto_init: false
      default_branch: main
    status_code: 201

- name: Publish starter content
  when: repo_src is defined
  block:
    - name: Create a temporary working copy
      ansible.builtin.tempfile:
        state: directory
      register: repo_tmp

    - name: Copy starter content into the working copy
      ansible.builtin.copy:
        src: "{{ repo_src }}/"
        dest: "{{ repo_tmp.path }}/"
        mode: preserve

    - name: Commit and push starter content
      ansible.builtin.shell: |
        set -e
        git init -q -b main
        git add -A
        git -c user.name='Lab Setup' -c user.email='lab@lab.example.com' commit -q -m 'Starter content'
        git -c http.extraHeader="Authorization: Basic {{ (gitea_user ~ ':' ~ gitea_password) | b64encode }}" \
            push -q "{{ gitea_url }}/{{ gitea_user }}/{{ repo_name }}.git" main
      args:
        chdir: "{{ repo_tmp.path }}"
      changed_when: true

  always:
    - name: Remove the temporary working copy
      ansible.builtin.file:
        path: "{{ repo_tmp.path }}"
        state: absent
      when: repo_tmp.path is defined
LAB_EOF

cat > lib/require_devtools.yml <<'LAB_EOF'
---
# Verifies that the Chapter 1 developer services exist before an exercise starts.
- name: Confirm VS Code, podman, git, and ansible-navigator are installed on workstation
  ansible.builtin.command: "bash -lc 'command -v {{ item }}'"
  loop:
    - code
    - podman
    - git
    - ansible-navigator
  changed_when: false

- name: Confirm the lab registry holds the execution environment image
  ansible.builtin.uri:
    url: "http://{{ lab_registry }}/v2/ansible-automation-platform-26/ee-supported-rhel9/tags/list"
    status_code: 200

- name: Confirm the lab registry holds the development tools image
  ansible.builtin.uri:
    url: "http://{{ lab_registry }}/v2/ansible-automation-platform-26/ansible-dev-tools-rhel9/tags/list"
    status_code: 200

- name: Confirm the Gitea server answers
  ansible.builtin.uri:
    url: "{{ gitea_url }}/api/v1/version"
    status_code: 200
LAB_EOF
```

---

## 6. The Lab Package Repository

Chapter 8 needs a signed RPM repository. The first `lab start` of `system_software` or `system_review` builds it on workstation (`rpm-build`, `rpm-sign`, `createrepo_c`, and a signing key generated in `~/.lab/repo_build/work/gnupg`) and publishes it on utility:

| Item | Location |
|---|---|
| Repository | `http://materials.example.com/yum/labrepo/` |
| Signing key | `http://materials.example.com/yum/labrepo/RPM-GPG-KEY-labexample` |
| Package | `lab-agent-1.0-1.noarch.rpm` (a script, a service, and a timer) |

Publishing uses the framework inventory entry `utility` (user `student`, sudo password `student`). To rebuild from scratch: `rm -rf ~/.lab/repo_build` and run `lab start system_software` again.

```bash
curl -s http://materials.example.com/yum/labrepo/repodata/repomd.xml | head -3
```

## 7. Final Verification

| Check | Command on workstation | Expected |
|---|---|---|
| Registry holds both images | `curl -s http://utility.lab.example.com:5000/v2/_catalog` | Both `ansible-automation-platform-26/...` paths |
| Execution environment runs | `ansible-navigator exec --eei utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest --pp missing -m stdout -- ansible --version` | `ansible [core 2.x]` printed from inside the container |
| Collections published | `curl -s http://materials.example.com/collections/` | Three tarballs |
| Framework reaches the services | `lab start intro_devenv` then `lab finish intro_devenv` | Every step `SUCCESS` |

Now return to `README.md` section 11, then take the baseline snapshots in section 12.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `http: server gave HTTP response to HTTPS client` | Client does not trust the plain HTTP registry | Check `/etc/containers/registries.conf.d/50-lab-registry.conf` on workstation, or add `--tls-verify=false` |
| `skopeo copy` very slow or times out | Internet path through bastion NAT | On bastion `sudo firewall-cmd --info-policy=labnat`; test `curl -I https://registry.redhat.io` on workstation |
| `ansible-galaxy collection download` fails | No internet, or proxy needed | Same check as above |
| `lab start` fails at the developer services step | A tool or service is missing | Read `~/.lab/logs/*_start.log`; it names the missing command or URL |
| `git push` rejected with 401 | Wrong credentials | `student` / `Student@123`; run `lab start` again to recreate the repository |
| Workstation disk full | Images pulled repeatedly | `podman system df`, then `podman image prune -a` |

<!-- navfoot:start -->

---

← Previous: [00 Lab Setup, Part 2: The `lab` Command (start, grade, finish)](01_lab_command.md) | Next: [Chapter 01: Introduction to Ansible](../01_introduction/README.md) →

<!-- navfoot:end -->
