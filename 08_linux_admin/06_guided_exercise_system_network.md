<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Guided exercise (7 of 10)
<!-- nav:end -->

# Guided Exercise: Network Connections with the Network Role

| | |
|---|---|
| **Exercise name** | `system_network` |
| **Time** | 25 minutes |
| **Covers** | README section 6 |
| **You will** | Read network facts, derive a new address from them, create a persistent connection with the network role, place it in a firewall zone, and verify through fresh facts |

The lab machines have one network adapter, which Ansible uses. Changing that connection by mistake would cut you off, so this exercise creates a **bridge without ports**, `labbr0`, on network 192.168.251.0/24. The role variables and workflow are identical to an extra Ethernet adapter.

---

## Before You Begin

```bash
lab start system_network
```

Start creates `~/system_network` with `nic_facts.yml` and the RHEL system roles in `collections/`. Open it in the dev container or a workstation terminal.

---

## Step 1: Read the network facts

```bash
ansible-navigator run nic_facts.yml
```

Note the interface that holds the default route (`default_ipv4.interface`), the primary address (`192.168.250.10` for servera), the DNS server (bastion), and the search domain.

---

## Step 2: Read the role documentation

```bash
less /usr/share/doc/rhel-system-roles/network/README.md
```

Search for `persistent_state`, `type: bridge`, and `zone`. Note the warning about the role managing each listed profile completely.

---

## Step 3: Describe the connection

```bash
mkdir -p group_vars/web
```

`group_vars/web/network.yml`:

```yaml
---
# redhat.rhel_system_roles.network
network_provider: nm
network_connections:
  - name: labbr0
    type: bridge
    state: up
    autoconnect: true
    zone: internal
    ip:
      dhcp4: false
      auto6: false
      address:
        - "192.168.251.{{ ansible_facts['default_ipv4']['address'].split('.')[-1] }}/24"
```

The last octet comes from each host's primary address, so servera gets 192.168.251.10 and any other host its own number, from one file.

---

## Step 4: Apply

`network.yml`:

```yaml
---
- name: Network configuration from the system role
  hosts: web
  become: true
  tasks:
    - name: Lab bridge is configured
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.network

    - name: Facts are refreshed to see the new interface
      ansible.builtin.setup:
        gather_subset:
          - network

    - name: Report the bridge address
      ansible.builtin.debug:
        var: ansible_facts['labbr0']['ipv4']
```

```bash
ansible-navigator run network.yml
```

The role prints `Using network provider: nm`, creates and activates the profile, and ends with `Re-test connectivity`. The refreshed facts show `address: 192.168.251.10`, `prefix: 24`.

---

## Step 5: Verify persistence and the zone

```bash
ansible web -m ansible.builtin.command -a 'nmcli -f NAME,DEVICE,TYPE connection show --active'
ansible web -m ansible.builtin.command -a 'nmcli -g ipv4.addresses,connection.zone connection show labbr0'
ansible web -b -m ansible.builtin.command -a 'firewall-cmd --get-zone-of-interface=labbr0'
ansible-navigator run network.yml     # changed=0
```

Your primary connection is untouched and still active.

---

## Step 6: Take it down, then remove it

Change `state: up` to `state: down` and run: the profile stays (`nmcli connection show` lists it) but is inactive. Then add `persistent_state: absent` and run: the profile is deleted. Restore `state: up`, remove the `persistent_state` line, and run once more.

Close the dev container.

---

## Finish

```bash
lab finish system_network
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `labbr0` stays in `connecting` | Check `nmcli device show labbr0`; with `dhcp4: false` and a static address the bridge activates without ports |
| `ansible_facts['labbr0'] is undefined` | Facts were not refreshed after the role; keep the `setup` task |
| Lost contact with the host | The primary connection was listed in `network_connections`; restore from the hypervisor console with `nmcli`, then revert the snapshot |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: LVM, File Systems, Swap, and Mounts](05_guided_exercise_system_storage.md) | Next: [Chapter 08 Quiz: Linux Administration with Ansible](07_quiz.md) →

<!-- navfoot:end -->
