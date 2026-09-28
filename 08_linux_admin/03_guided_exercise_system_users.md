<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Guided exercise (4 of 10)
<!-- nav:end -->

# Guided Exercise: Accounts, Keys, sudo, and sshd

| | |
|---|---|
| **Exercise name** | `system_users` |
| **Time** | 35 minutes |
| **Covers** | README section 3 |
| **You will** | Create groups and users from a data file with fixed IDs and hashed passwords, deploy each user's SSH key, grant sudo to a group, harden sshd with validated edits, create a service account with its own key, and distribute host keys |

---

## Before You Begin

```bash
lab start system_users
```

Start creates `~/system_users` and generates an SSH key pair for alice, bob, and carol in `files/keys/`. It removes any earlier lab accounts from servera and serverb.

```bash
cd ~/system_users
cat vars/users.yml
ls files/keys/
```

Open the project in the dev container or a workstation terminal.

---

## Step 1: Groups from the data

Create `users.yml`:

```yaml
---
- name: Accounts, keys, and privileges
  hosts: web
  become: true
  vars_files:
    - vars/users.yml
  tasks:
    - name: Every group used by the accounts exists
      ansible.builtin.group:
        name: "{{ item }}"
        state: present
      loop: "{{ lab_users | map(attribute='groups') | flatten | unique }}"
```

The filter chain turns the per user lists into `['webadmin', 'auditors']`: no group is hard coded.

---

## Step 2: Users with fixed IDs and a hashed password

Append:

```yaml
    - name: Accounts exist with fixed UIDs and supplementary groups
      ansible.builtin.user:
        name: "{{ item['name'] }}"
        uid: "{{ item['uid'] }}"
        comment: "{{ item['comment'] }}"
        groups: "{{ item['groups'] }}"
        append: true
        shell: /bin/bash
        password: "{{ lab_user_password | password_hash('sha512', 'labsalt2026') }}"
      loop: "{{ lab_users }}"
      loop_control:
        label: "{{ item['name'] }}"
```

```bash
ansible-navigator run users.yml
ansible-navigator run users.yml      # changed=0
ansible web -m ansible.builtin.command -a 'id bob'
```

Now remove `, 'labsalt2026'` from the filter and run twice: the user task reports `changed` every time, because each run picks a new random salt. Put the fixed salt back. (`update_password: on_create` is the alternative when passwords are only set once.)

---

## Step 3: SSH keys

Append:

```yaml
    - name: Each account accepts its own SSH key
      ansible.posix.authorized_key:
        user: "{{ item['name'] }}"
        key: "{{ lookup('ansible.builtin.file', 'files/keys/' ~ item['name'] ~ '.pub') }}"
        state: present
      loop: "{{ lab_users }}"
      loop_control:
        label: "{{ item['name'] }}"
```

```bash
ansible-navigator run users.yml
ssh -i files/keys/alice alice@servera.lab.example.com id
```

The lookup runs on the control side, so the key files never need to be copied first.

---

## Step 4: sudo for a group, validated

Append:

```yaml
    - name: Members of webadmin use sudo without a password
      ansible.builtin.lineinfile:
        path: /etc/sudoers.d/webadmin
        line: "%webadmin ALL=(ALL) NOPASSWD: ALL"
        create: true
        owner: root
        group: root
        mode: "0440"
        validate: /usr/sbin/visudo -cf %s
```

```bash
ansible-navigator run users.yml
ssh -i files/keys/alice alice@servera.lab.example.com sudo -n id -un     # root
ssh -i files/keys/carol carol@servera.lab.example.com sudo -n id -un     # a password is required
```

Change the line to `%webadmin ALL=(ALL) NOPASSWD ALL` (colon missing) and run: `failed to validate`, and the existing file is untouched. Restore the colon.

---

## Step 5: sshd hardening, validated

Append the task and a handler section at the end of the play:

```yaml
    - name: Root cannot log in over SSH
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PermitRootLogin\s'
        line: PermitRootLogin no
        validate: /usr/sbin/sshd -t -f %s
      notify: Restart sshd

  handlers:
    - name: Restart sshd
      ansible.builtin.systemd_service:
        name: sshd
        state: restarted
```

```bash
ansible-navigator run users.yml
ansible web -b -m ansible.builtin.shell -a 'sshd -T | grep -i ^permitrootlogin'
```

`permitrootlogin no`: the effective value, which is what matters when drop-ins in `/etc/ssh/sshd_config.d/` might override the main file.

---

## Step 6: A service account with its own key pair

Insert before the `handlers:` line:

```yaml
    - name: Backup service account with its own key pair
      ansible.builtin.user:
        name: svc_backup
        system: true
        shell: /sbin/nologin
        create_home: true
        generate_ssh_key: true
        ssh_key_type: ed25519
        ssh_key_comment: svc_backup@{{ inventory_hostname }}
      register: svc_backup

    - name: Show the service account public key
      ansible.builtin.debug:
        msg: "{{ svc_backup['ssh_public_key'] }}"
```

```bash
ansible-navigator run users.yml
ansible web -m ansible.builtin.command -a 'id svc_backup'
```

The UID is below 1000, and the key was generated on each host; the private key never left it.

---

## Step 7: Hosts that trust each other

Append a second play at the end of the file:

```yaml
- name: Hosts trust each other's SSH host keys
  hosts: web
  become: true
  tasks:
    - name: Host key is read
      ansible.builtin.slurp:
        src: /etc/ssh/ssh_host_ed25519_key.pub
      register: host_key

    - name: Every web host key is in the global known hosts file
      ansible.builtin.known_hosts:
        path: /etc/ssh/ssh_known_hosts
        name: "{{ item }}"
        key: "{{ item }},{{ hostvars[item]['ansible_facts']['default_ipv4']['address'] }} {{ hostvars[item]['host_key']['content'] | b64decode | trim }}"
        state: present
      loop: "{{ ansible_play_hosts }}"
```

```bash
ansible-navigator run users.yml
ssh -i files/keys/alice alice@servera.lab.example.com 'ssh -o BatchMode=yes serverb.lab.example.com true; echo rc=$?'
```

The error is now about authentication (alice has no key for serverb), not about an unknown host key: host verification works without any prompt.

Close the dev container.

---

## Finish

```bash
lab finish system_users
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Group webadmin does not exist` | The group task must run before the user task |
| `Permission denied (publickey)` for alice | Use `-i files/keys/alice`; check `~alice/.ssh/authorized_keys` |
| `crypt.crypt not supported` or passlib warnings | Install `python3-passlib` on the control side, or run in the execution environment |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Signed Repositories, Packages, and Package Facts](02_guided_exercise_system_software.md) | Next: [Guided Exercise: cron, at, Timers, Boot Target, and Reboots](04_guided_exercise_system_process.md) →

<!-- navfoot:end -->
