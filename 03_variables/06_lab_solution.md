<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Lab solution (7 of 7)
<!-- nav:end -->

# Chapter 03 Lab Solution: `variables_review`

---

## 1. Plain variables

```bash
cd ~/variables_review
mkdir -p group_vars/all group_vars/web

cat > group_vars/all/vars.yml <<'EOF'
---
portal_user: ops
EOF

cat > group_vars/web/vars.yml <<'EOF'
---
web_pkgs:
  - httpd
  - mod_ssl
  - firewalld
auth_dir: /etc/httpd/auth
portal_owner: ops-team
EOF
```

`portal_user` goes to `all` because both the web hosts (for the password file) and the probe host (for the login test) need it. The web specific values stay in `web`.

---

## 2. and 3. Secrets without prompts

```bash
printf 'P0rtalVault\n' > .portal_pass
chmod 0600 .portal_pass
echo '.portal_pass' >> .gitignore

cat > group_vars/all/vault.yml <<'EOF'
---
portal_password: Ops2026
portal_htpasswd_hash: $apr1$PortaL26$2.RiV9gzOPgV7tK4ekV3s1
EOF
ansible-vault encrypt --vault-id portal@.portal_pass group_vars/all/vault.yml
head -n1 group_vars/all/vault.yml          # $ANSIBLE_VAULT;1.2;AES256;portal
```

Add to `[defaults]` in `ansible.cfg`:

```ini
vault_identity_list = portal@.portal_pass
```

Prove it before writing the playbook:

```bash
ansible-inventory --host serverb.lab.example.com
```

The output lists all six variables, including the decrypted password, without a prompt.

Encrypting before editing `ansible.cfg` avoids one trap: once `vault_identity_list` names several IDs, `ansible-vault encrypt` and `create` need `--encrypt-vault-id LABEL` to know which one to use.

The `$apr1$` hash is an Apache MD5 password hash; it was produced with `openssl passwd -apr1 -salt PortaL26 Ops2026`. Storing it in the vault keeps it out of plain view, like any credential.

---

## 4. `portal.yml`

```yaml
---
- name: Operations portal is served over https with a login
  hosts: web
  become: true
  tasks:
    - name: Web packages are installed
      ansible.builtin.dnf:
        name: "{{ web_pkgs }}"
        state: present

    - name: Firewalld is running and starts at boot
      ansible.builtin.systemd_service:
        name: firewalld
        state: started
        enabled: true

    - name: Firewall allows https now and after reboot
      ansible.posix.firewalld:
        service: https
        permanent: true
        immediate: true
        state: enabled

    - name: Authentication directory exists
      ansible.builtin.file:
        path: "{{ auth_dir }}"
        state: directory
        owner: root
        group: apache
        mode: "0750"

    - name: Password file holds the portal account
      ansible.builtin.copy:
        content: "{{ portal_user }}:{{ portal_htpasswd_hash }}\n"
        dest: "{{ auth_dir }}/htpasswd"
        owner: root
        group: apache
        mode: "0640"
      no_log: true

    - name: Portal access rules are installed
      ansible.builtin.copy:
        src: files/portal.conf
        dest: /etc/httpd/conf.d/portal.conf
        owner: root
        group: root
        mode: "0644"

    - name: Custom facts directory exists
      ansible.builtin.file:
        path: /etc/ansible/facts.d
        state: directory
        mode: "0755"

    - name: Portal owner is recorded as a custom fact
      ansible.builtin.copy:
        content: |
          [portal]
          owner = {{ portal_owner }}
        dest: /etc/ansible/facts.d/portal.fact
        mode: "0644"

    - name: Local facts are reloaded after the change
      ansible.builtin.setup:
        filter: ansible_local

    - name: Home page names host, address, and owner
      ansible.builtin.copy:
        content: >-
          {{ ansible_facts['fqdn'] }}
          ({{ ansible_facts['default_ipv4']['address'] }})
          is run by {{ ansible_facts['ansible_local']['portal']['portal']['owner'] }}
        dest: /var/www/html/index.html
        mode: "0644"

    - name: Httpd is running and starts at boot
      ansible.builtin.systemd_service:
        name: httpd
        state: started
        enabled: true

- name: Facts of the portal hosts are exported to the project
  hosts: web
  become: false
  tasks:
    - name: Facts directory exists
      ansible.builtin.file:
        path: "{{ playbook_dir }}/facts"
        state: directory
        mode: "0755"
      delegate_to: localhost

    - name: One JSON file per host
      ansible.builtin.copy:
        content: "{{ ansible_facts | to_nice_json }}\n"
        dest: "{{ playbook_dir }}/facts/{{ inventory_hostname }}.json"
        mode: "0644"
      delegate_to: localhost

- name: Probe host confirms the login works
  hosts: probe
  become: false
  tasks:
    - name: Anonymous request to serverb is refused
      ansible.builtin.uri:
        url: https://serverb.lab.example.com
        validate_certs: false
        status_code: 401

    - name: Serverb answers after login
      ansible.builtin.uri:
        url: https://serverb.lab.example.com
        validate_certs: false
        force_basic_auth: true
        url_username: "{{ portal_user }}"
        url_password: "{{ portal_password }}"
        return_content: true
      register: serverb_page

    - name: Serverc answers after login
      ansible.builtin.uri:
        url: https://serverc.lab.example.com
        validate_certs: false
        force_basic_auth: true
        url_username: "{{ portal_user }}"
        url_password: "{{ portal_password }}"
        return_content: true
      register: serverc_page

    - name: Show both pages
      ansible.builtin.debug:
        msg:
          - "{{ serverb_page['content'] }}"
          - "{{ serverc_page['content'] }}"
```

| Requirement | How the solution meets it |
|---|---|
| Values only through variables | `web_pkgs`, `auth_dir`, `portal_user`, `portal_htpasswd_hash`, `portal_owner`, `portal_password` |
| htpasswd output hidden | `no_log: true` on that task |
| Page uses the owner **from the custom fact** | The fact file is written, then `setup` with `filter: ansible_local` reloads local facts, then the page reads `ansible_facts['ansible_local']['portal']['portal']['owner']`. Without the reload, the first run fails with an undefined variable |
| One line page | `>-` folds the three lines into one with spaces and no trailing newline |
| Facts export | `delegate_to: localhost` with `become: false`, writing under `playbook_dir` so it works inside the execution environment too |
| Self signed certificate | `validate_certs: false` on every `uri` task |
| Anonymous access refused | `status_code: 401` turns the expected refusal into success |

Loops would shorten Play 3; they arrive in the next chapter.

---

## 5. Run and verify

```bash
ansible-lint portal.yml
ansible-navigator run portal.yml
curl -k -s -o /dev/null -w '%{http_code}\n' https://serverb.lab.example.com/          # 401
curl -k -s -u ops:Ops2026 https://serverc.lab.example.com/                             # page text
ls facts/
lab grade variables_review
lab finish variables_review
```

A second run reports `changed` only for the facts export tasks: exported facts contain values such as uptime that differ on every run. Everything on the managed hosts stays `ok`.

## Time Check

Target: 30 minutes. Variables and vault 8, playbook 15, run and debug 7.

<!-- navfoot:start -->

---

← Previous: [Chapter 03 Lab: A Login Protected Portal Built from Variables, Facts, and Vault](05_lab.md) | Next: [Chapter 04: Task Control](../04_task_control/README.md) →

<!-- navfoot:end -->
