<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Guided exercise (6 of 10)
<!-- nav:end -->

# Guided Exercise: LVM, File Systems, Swap, and Mounts

| | |
|---|---|
| **Exercise name** | `system_storage` |
| **Time** | 40 minutes |
| **Covers** | README section 5 |
| **You will** | Identify the spare disk from facts, build a volume group with two XFS volumes and a swap volume using the storage role, grow a volume online, mount a file system with the mount module, and report free space from facts |

---

## Before You Begin

```bash
lab start system_storage
```

Start creates `~/system_storage`, copies the RHEL system roles into `collections/`, and wipes the spare disk on servera. The project contains `disk_list.yml` and `get_storage.yml`. Open it in the dev container or a workstation terminal.

---

## Step 1: Find the right disk

```bash
ansible-navigator run disk_list.yml
```

```
/dev/sda: 20.0 GiB, 3 partitions, no holders
/dev/sdb: 5.0 GiB, 0 partitions, no holders
```

Your names depend on the hypervisor (`vda`/`vdb` on KVM, `sda`/`sdb` on VirtualBox and VMware, `nvme0n1`/`nvme0n2` with NVMe). Write down the name of the **5 GiB disk with no partitions**. Everything below uses `sdb`; substitute yours.

Getting this wrong is how automation destroys data. Always look first.

---

## Step 2: Describe the storage as data

```bash
mkdir -p group_vars/web
```

`group_vars/web/storage.yml`:

```yaml
---
# redhat.rhel_system_roles.storage
storage_pools:
  - name: data_vg
    type: lvm
    disks:
      - sdb
    volumes:
      - name: web_lv
        size: 512m
        fs_type: xfs
        mount_point: /srv/web
        state: present
      - name: logs_lv
        size: 1g
        fs_type: xfs
        mount_point: /srv/logs
        state: present
      - name: swap_lv
        size: 256m
        fs_type: swap
        state: present
```

`storage.yml`:

```yaml
---
- name: Storage from the system role
  hosts: web
  become: true
  tasks:
    - name: Volume group, logical volumes, file systems, mounts, and swap
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.storage
```

---

## Step 3: Apply and inspect

```bash
ansible-navigator run storage.yml
ansible-navigator run get_storage.yml
```

| Section | Expected |
|---|---|
| `lvs` | `data_vg web_lv 512.00m`, `logs_lv 1024.00m`, `swap_lv 256.00m` |
| `mounts` | `/srv/web` and `/srv/logs`, type xfs |
| `swap` | `/dev/dm-N 256M` |
| `fstab` | Three `UUID=` lines added under `# system_role:storage` |

```bash
ansible-navigator run storage.yml     # changed=0
```

---

## Step 4: Grow a volume

Change `web_lv` to `size: 768m` and run again:

```bash
ansible-navigator run storage.yml
ansible web -m ansible.builtin.command -a 'df -h /srv/web'
```

The logical volume and the XFS file system grew while mounted. Now try `size: 256m`: the role refuses, because XFS cannot shrink and safe mode protects the data. Put `768m` back.

---

## Step 5: Mount with the mount module

`scratch.yml`:

```yaml
---
- name: Mount a file system with the mount module
  hosts: web
  become: true
  tasks:
    - name: Scratch space is mounted now and at boot
      ansible.posix.mount:
        path: /mnt/scratch
        src: tmpfs
        fstype: tmpfs
        opts: size=64m,mode=1777
        state: mounted
```

```bash
ansible-navigator run scratch.yml
ansible web -m ansible.builtin.command -a 'findmnt /mnt/scratch'
ansible web -m ansible.builtin.command -a 'grep scratch /etc/fstab'
```

Change `state: mounted` to `state: unmounted`, run, and check both commands: the fstab line stays, the mount is gone. Change it to `present`: fstab only, still not mounted. Return to `mounted`.

---

## Step 6: Free space from facts

`free_space.yml`:

```yaml
---
- name: Free space from mount facts
  hosts: web
  tasks:
    - name: Report free space on the lab file systems
      ansible.builtin.debug:
        msg: >-
          {{ item['mount'] }} on {{ item['device'] }}:
          {{ (item['size_available'] / 1048576) | round(1) }} MiB free of
          {{ (item['size_total'] / 1048576) | round(1) }} MiB
      loop: "{{ ansible_facts['mounts'] }}"
      loop_control:
        label: "{{ item['mount'] }}"
      when: item['mount'] is match('/srv/|/mnt/scratch')
```

```bash
ansible-navigator run free_space.yml
ansible-navigator run disk_list.yml
```

`disk_list.yml` now reports the spare disk with holders (the device mapper volumes): a disk in use is visible in facts, which is how a playbook can refuse to touch it.

Close the dev container.

---

## Finish

```bash
lab finish system_storage
```

Finish unmounts everything, removes the fstab entries, the volume group, and the disk signatures.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `unable to resolve disk` or `device not found` | Use the kernel name from `disk_list.yml` |
| `cannot remove existing formatting ... in safe mode` | The disk holds data; you picked the wrong disk, or a previous exercise left it; run `lab finish` then `lab start` |
| Size rejected | Lower case units: `512m`, `1g` |
| Swap missing after reboot | Check the swap line in fstab; it is written by UUID |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: cron, at, Timers, Boot Target, and Reboots](04_guided_exercise_system_process.md) | Next: [Guided Exercise: Network Connections with the Network Role](06_guided_exercise_system_network.md) →

<!-- navfoot:end -->
