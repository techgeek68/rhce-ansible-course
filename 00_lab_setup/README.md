<!-- nav:start -->
[Course home](../README.md) › [00 Lab Setup: Build the Complete RH294 Lab on Your Own Virtual Machines](README.md) › Lesson (1 of 3)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guide: [00 Lab Setup, Part 2: The `lab` Command (start, grade, finish)](01_lab_command.md)
3. Guide: [00 Lab Setup, Part 3: Developer Services](02_dev_services.md)
<!-- nav:end -->

# 00 Lab Setup: Build the Complete RH294 Lab on Your Own Virtual Machines

This chapter builds, from nothing, a lab that behaves like the Red Hat classroom: the same host names, the same DNS domain, the same users, the same repository and registry URLs. It runs on any hypervisor you already use, and it uses the Class C private network **192.168.250.0/24**.

Every later chapter depends only on host names such as `servera.lab.example.com`, never on IP addresses, so once this chapter passes, the whole course works unchanged.

**Files used in this chapter**

| File | Purpose |
|---|---|
| `scripts/bastion_setup.sh` | Turns a minimal RHEL install into the lab router, DNS, DHCP, NTP, and Kickstart server. It also generates the Kickstart files and the two scripts below |
| `utility_setup.sh` (published by bastion) | Content repositories, container registry, Git server |
| `workstation_setup.sh` (published by bastion) | Lab SSH key, container tools, Ansible development tools, VS Code |

---

## 1. What You Are Building

### 1.1 Topology

```
                         Internet
                            |
                 Hypervisor NAT network (DHCP from the hypervisor)
                            |
                    NIC 1 (WAN, zone external)
                  +=====================+
                  |       bastion       |   NAT, DNS, DHCP (installs only),
                  |   192.168.250.254   |   NTP, Kickstart web server
                  +=====================+
                    NIC 2 (LAB, zone internal)
                            |
   Lab network 192.168.250.0/24 (host only / internal, hypervisor DHCP OFF)
                            |
   +==========+============+==========+==========+==========+==========+
   |          |            |          |          |          |          |
 your host  utility   workstation  servera   serverb   serverc   serverd
   .1        .220         .9         .10       .11       .12       .13
            repos,     control      managed nodes, each with a spare
            registry,  node, GUI    5 GB data disk (/dev/vdb)
            Git server
```

Your physical computer gets `192.168.250.1` on the lab network, so you can SSH to every VM directly. It is not a router: all lab traffic to the internet goes through bastion, exactly as in the classroom.

### 1.2 Address plan

| Host | IP address | Role | Classroom equivalent |
|---|---|---|---|
| Your computer | 192.168.250.1 | Access to the lab | Your browser session |
| bastion.lab.example.com | 192.168.250.254 | Gateway, NAT, DNS, NTP, Kickstart server | bastion |
| utility.lab.example.com, also answers as content.example.com, materials.example.com, classroom.example.com | 192.168.250.220 | RHEL repositories, collection tarballs, container registry (port 5000), Gitea (port 3000) | utility and classroom |
| workstation.lab.example.com | 192.168.250.9 | Ansible control node with GUI | workstation |
| servera.lab.example.com | 192.168.250.10 | Managed host | servera |
| serverb.lab.example.com | 192.168.250.11 | Managed host | serverb |
| serverc.lab.example.com | 192.168.250.12 | Managed host | serverc |
| serverd.lab.example.com | 192.168.250.13 | Managed host | serverd |
| Installer DHCP pool | 192.168.250.100 to .199 | Temporary addresses during installation only | none |

`192.168.0.0/16` is the Class C private range from RFC 1918. The third octet `250` was chosen because home routers rarely use it. If your home or office network already uses `192.168.250.0/24`, follow section 15 before building anything.

### 1.3 Accounts

| User | Password | Where | Privilege |
|---|---|---|---|
| root | redhat | All VMs | Console recovery only |
| student | student | All VMs | sudo with password; your daily login |
| devops | redhat | servera to serverd | sudo without password; the Ansible remote user |
| student (Gitea) | Student@123 | http://utility.lab.example.com:3000 | Git server account |

One SSH key pair, generated on bastion, is trusted by `student` on every VM and by `devops` on every managed host.

---

## 2. Requirements

### 2.1 Supported hypervisors

Any of these works; section 4 gives exact settings for each.

| Hypervisor | Host OS |
|---|---|
| Oracle VirtualBox 7 | Windows, Linux, Intel macOS |
| VMware Workstation Pro 17 / Fusion 13 | Windows, Linux / macOS |
| Microsoft Hyper-V | Windows 10 and 11 Pro or Enterprise, Windows Server |
| KVM with virt-manager | Linux |
| Proxmox VE 8 | Dedicated server |

Apple Silicon Macs need the **aarch64** RHEL DVD and a hypervisor that runs ARM guests (VMware Fusion or UTM). Everything else in this guide is identical.

### 2.2 Host resources

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores with VT-x or AMD-V enabled in firmware | 8 threads |
| RAM | 16 GB | 32 GB |
| Free disk | 150 GB SSD | 250 GB SSD |

### 2.3 VM specifications

| VM | vCPU | RAM | Disk 1 | Disk 2 | NIC 1 | NIC 2 |
|---|---|---|---|---|---|---|
| bastion | 1 | 1536 MB | 20 GB | none | NAT | Lab |
| utility | 2 | 3072 MB | 60 GB | none | Lab | none |
| workstation | 2 | 4096 MB | 40 GB | none | Lab | none |
| servera, serverb, serverc, serverd | 1 | 2048 MB (1536 MB after install) | 20 GB | 5 GB | Lab | none |

Settings that apply to **every** VM:

* Guest OS type: Red Hat Enterprise Linux 9 (or 10), 64 bit.
* The RHEL DVD ISO attached to the optical drive. Installations read packages from it.
* Boot order: **hard disk first, optical second**. An empty disk falls through to the DVD; after installation the VM boots from disk and never reinstalls itself.
* Disks thin provisioned (dynamically allocated).
* On bastion the adapter **order matters**: adapter 1 NAT, adapter 2 lab.

---

## 3. Downloads

1. Create a free **Red Hat Developer Subscription for Individuals** at `https://developers.redhat.com`.
2. Download the **RHEL 9 Binary DVD** ISO (x86_64, or aarch64 for Apple Silicon). Use the full DVD, not the boot ISO.
3. Verify the checksum shown on the download page:

```bash
sha256sum rhel-9.*-x86_64-dvd.iso                 # Linux
shasum -a 256 rhel-9.*-x86_64-dvd.iso             # macOS
Get-FileHash .\rhel-9.*-x86_64-dvd.iso            # Windows PowerShell
```

No subscription registration is needed inside the lab: every VM installs from the DVD, and utility then serves the DVD content as `content.example.com`.

---

## 4. Create the Lab Network

The lab network must be **isolated from your LAN**, reachable from your host at `192.168.250.1`, and have the **hypervisor DHCP server turned off** (bastion provides DHCP). The NAT network used by bastion's first adapter is the hypervisor default and needs no changes.

### 4.1 VirtualBox

1. **File, Tools, Network Manager, Host-only Networks, Create.**
2. Adapter tab: **Configure Adapter Manually**, IPv4 Address `192.168.250.1`, mask `255.255.255.0`.
3. DHCP Server tab: clear **Enable Server**.
4. Note the name (for example `vboxnet0` on Linux and macOS, `VirtualBox Host-Only Ethernet Adapter #2` on Windows).

Command line equivalent (Linux and macOS):

```bash
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.250.1 --netmask 255.255.255.0
VBoxManage dhcpserver remove --interface vboxnet0 2>/dev/null || true
```

VM network settings: bastion adapter 1 **NAT**, adapter 2 **Host-only Adapter** with that name. All other VMs: adapter 1 **Host-only Adapter**. Disk controller: keep the default SATA; the data disk appears as `sdb` and the Kickstart adds a `/dev/vdb` link for it (section 8.3).

On macOS and Linux, VirtualBox 7 only allows host only ranges listed in `/etc/vbox/networks.conf`. Add this line (create the file if needed):

```
* 192.168.250.0/24
```

### 4.2 VMware Workstation Pro and Fusion

Workstation: **Edit, Virtual Network Editor, Change Settings, Add Network** (for example `VMnet2`):

* Type **Host-only**.
* Clear **Use local DHCP service to distribute IP address to VMs**.
* Keep **Connect a host virtual adapter to this network** selected.
* Subnet IP `192.168.250.0`, mask `255.255.255.0`. The host adapter receives `192.168.250.1`.

Fusion: **Settings, Network, `+`**, clear **Provide addresses on this network via DHCP**, subnet `192.168.250.0` mask `255.255.255.0`.

VM network settings: bastion NIC 1 **NAT**, NIC 2 **Custom: VMnet2**. All other VMs: NIC 1 **Custom: VMnet2**. VMware creates NVMe or SCSI disks; the data disk link is handled by the Kickstart.

### 4.3 Hyper-V

PowerShell as Administrator:

```powershell
New-VMSwitch -Name rhlab -SwitchType Internal
New-NetIPAddress -InterfaceAlias "vEthernet (rhlab)" -IPAddress 192.168.250.1 -PrefixLength 24
```

For each VM: **Generation 2**, Secure Boot template **Microsoft UEFI Certificate Authority**, dynamic memory **off**. bastion: first adapter on **Default Switch**, second adapter on **rhlab** (add them in that order). All other VMs: one adapter on **rhlab**.

Example for one managed host (repeat with the names and sizes from section 2.3):

```powershell
$iso = "C:\ISO\rhel-9-x86_64-dvd.iso"
New-VM -Name servera -Generation 2 -MemoryStartupBytes 2GB -SwitchName rhlab `
  -NewVHDPath "C:\VMs\servera.vhdx" -NewVHDSizeBytes 20GB
Set-VMMemory servera -DynamicMemoryEnabled $false
Set-VMProcessor servera -Count 1
Set-VMFirmware servera -SecureBootTemplate MicrosoftUEFICertificateAuthority
New-VHD -Path "C:\VMs\servera_data.vhdx" -SizeBytes 5GB -Dynamic
Add-VMHardDiskDrive servera -Path "C:\VMs\servera_data.vhdx"
Add-VMDvdDrive servera -Path $iso
$disk = Get-VMHardDiskDrive servera | Select-Object -First 1
$dvd  = Get-VMDvdDrive servera
Set-VMFirmware servera -BootOrder $disk, $dvd
```

### 4.4 KVM with libvirt

```bash
cat > rhlab.xml <<'EOF'
<network>
  <name>rhlab</name>
  <bridge name='virbr-rhlab' stp='on' delay='0'/>
  <ip address='192.168.250.1' netmask='255.255.255.0'/>
</network>
EOF
sudo virsh net-define rhlab.xml
sudo virsh net-start rhlab
sudo virsh net-autostart rhlab
```

No `<forward>` element makes it isolated; no `<dhcp>` element keeps libvirt DHCP off. bastion: NIC 1 on the libvirt `default` network, NIC 2 on `rhlab`. Others: one NIC on `rhlab`. Use **virtio** disks and **BIOS** firmware; BIOS keeps internal snapshots available for section 12.

Example managed host:

```bash
sudo virt-install --name servera --memory 2048 --vcpus 1 --boot hd,cdrom \
  --disk size=20,bus=virtio --disk size=5,bus=virtio \
  --cdrom /var/lib/libvirt/images/rhel9-dvd.iso \
  --network network=rhlab,model=virtio --os-variant rhel9.0 \
  --graphics spice --noautoconsole
```

### 4.5 Proxmox VE

In `/etc/network/interfaces` add a bridge without physical ports, then `ifreload -a`:

```
auto vmbr250
iface vmbr250 inet static
    address 192.168.250.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

bastion: `net0` on `vmbr0` (your uplink, which must provide DHCP or give bastion a static WAN address), `net1` on `vmbr250`. Others: `net0` on `vmbr250`. Use VirtIO SCSI single or VirtIO Block disks.

### 4.6 Check

From your host:

```bash
ping -c1 192.168.250.1          # Linux and macOS; on Windows: ping -n 1 192.168.250.1
```

Your host must answer on its own lab address. Nothing else exists yet.

---

## 5. Create the Six VMs

Create all VMs now using section 2.3 and your hypervisor's settings from section 4. Attach the DVD to each one. **Do not start them yet**; bastion must be installed first.

---

## 6. Build bastion

bastion is the only VM installed by hand, because nothing exists yet to serve a Kickstart file.

### 6.1 Interactive installation

Start bastion, choose **Install Red Hat Enterprise Linux**, then set:

| Installer screen | Setting |
|---|---|
| Language | English (United States) |
| Installation Destination | The 20 GB disk, automatic partitioning |
| Software Selection | **Minimal Install** |
| Network & Host Name | Host name `bastion.lab.example.com`. Switch **both** adapters **ON**. The NAT adapter receives an address; the lab adapter stays unconfigured, which is expected |
| Time & Date | Etc/UTC |
| Root Password | `redhat`; confirm twice because it is weak |
| User Creation | `student`, password `student`, **Make this user administrator** selected |

Click **Begin Installation**, then **Reboot System**.

### 6.2 Run `bastion_setup.sh`

Log in on the bastion **console** as `student` (the script reconfigures networking, so do not run it over SSH). Get the script in one of two ways:

From your GitHub repository (bastion already has internet through its NAT adapter):

```bash
curl -LO https://raw.githubusercontent.com/techgeek68/rhce-ansible-course/main/00_lab_setup/scripts/bastion_setup.sh
```

Or copy it from your host after giving bastion a temporary lab address on the console (`sudo nmcli device` shows the lab adapter name, for example `enp0s8`):

```bash
sudo ip addr add 192.168.250.254/24 dev enp0s8      # on bastion, temporary
scp 00_lab_setup/scripts/bastion_setup.sh student@192.168.250.254:   # on your host
```

Then run it on bastion:

```bash
sudo bash bastion_setup.sh
```

What the script does, in order:

1. Uses the DVD as a temporary package source and installs dnsmasq, httpd, chrony, and firewalld.
2. Finds the adapter holding the default route (WAN) and the other adapter (LAB), then gives LAB the static address `192.168.250.254/24`.
3. Puts WAN in firewalld zone `external` (masquerading) and LAB in zone `internal`, and adds a firewalld policy that forwards lab traffic to the internet.
4. Serves DNS for every lab name and the `*.example.com` aliases, and DHCP from `.100` to `.199` for installers.
5. Serves time to the lab with chrony, even when the internet is unreachable.
6. Creates the lab SSH key pair for `student`.
7. Writes a Kickstart file per VM and the utility and workstation setup scripts to `http://192.168.250.254/lab/`.

### 6.3 Check

On bastion:

```bash
ip -br addr                                   # LAB adapter shows 192.168.250.254/24
firewall-cmd --get-active-zones               # external: WAN, internal: LAB
dig +short @192.168.250.254 content.example.com      # 192.168.250.220
curl -s http://192.168.250.254/lab/ks/ | grep -o '[a-z]*\.ks' | sort -u
```

From your host:

```bash
ssh student@192.168.250.254 hostname          # bastion.lab.example.com
```

---

## 7. Build utility

### 7.1 Kickstart installation

Start utility. At the DVD boot menu, highlight **Install Red Hat Enterprise Linux**, then:

* **UEFI** (Hyper-V Gen 2, VMware and VirtualBox with EFI): press `e`, go to the end of the line starting with `linux` or `linuxefi`, add the text below, press `Ctrl+X`.
* **BIOS**: press `Tab`, add the text below to the end of the line, press `Enter`.

```
inst.ks=http://192.168.250.254/lab/ks/utility.ks ip=dhcp
```

The installation runs unattended. It also copies the whole DVD into `/var/www/html/rhel9` on utility, so it takes longer than the others (15 to 30 minutes).

### 7.2 Run `utility_setup.sh`

Log in to utility as `student` (from your host: `ssh student@192.168.250.220`):

```bash
curl -sO http://bastion.lab.example.com/lab/scripts/utility_setup.sh
sudo bash utility_setup.sh
```

It verifies the repository copy (copying from the DVD drive if the Kickstart could not), opens ports 80, 3000, and 5000, starts the registry and Gitea as Podman Quadlet services, and creates the Gitea `student` account.

### 7.3 Check

The script ends with three lines that must all show `200`:

```
content repo   200
registry       200
gitea          200
```

---

## 8. Build workstation and the Managed Hosts

### 8.1 Kickstart installations

Start each VM and add its line at the boot menu exactly as in 7.1:

| VM | Boot line addition |
|---|---|
| workstation | `inst.ks=http://192.168.250.254/lab/ks/workstation.ks ip=dhcp` |
| servera | `inst.ks=http://192.168.250.254/lab/ks/servera.ks ip=dhcp` |
| serverb | `inst.ks=http://192.168.250.254/lab/ks/serverb.ks ip=dhcp` |
| serverc | `inst.ks=http://192.168.250.254/lab/ks/serverc.ks ip=dhcp` |
| serverd | `inst.ks=http://192.168.250.254/lab/ks/serverd.ks ip=dhcp` |

You can run all five installations at the same time if your host has 32 GB of RAM. Each ejects the DVD and reboots into the installed system when finished.

### 8.2 What each Kickstart configures

| Item | workstation | servera to serverd |
|---|---|---|
| Static address, gateway and DNS 192.168.250.254, search domain lab.example.com | Yes | Yes |
| Package repositories from content.example.com | Yes | Yes |
| NTP from bastion | Yes | Yes |
| Software | Server with GUI, ansible-core, rhel-system-roles, git | Minimal, python3 |
| student trusts the lab key | Yes | Yes |
| devops user with passwordless sudo and the lab key | No | Yes |
| YAML friendly `.vimrc` for student | Yes | No |
| Spare 5 GB disk left untouched, reachable as `/dev/vdb` | No | Yes |

### 8.3 How `/dev/vdb` is guaranteed

The course refers to the spare disk as `/dev/vdb`, the name virtio disks get on KVM. VirtualBox, VMware, and Hyper-V name it `sdb` or `nvme0n2`. The Kickstart always installs to the **largest** disk and leaves the smaller one empty. On non virtio hypervisors it adds a udev rule so the spare disk also appears as `/dev/vdb`. Commands such as `lsblk /dev/vdb` and Ansible tasks that use `/dev/vdb` work everywhere; `lsblk` and `ansible_facts['devices']` still list the real kernel name.

### 8.4 Run `workstation_setup.sh`

Log in to the workstation desktop as `student`, open a terminal:

```bash
curl -sO http://bastion.lab.example.com/lab/scripts/workstation_setup.sh
bash workstation_setup.sh
```

Passwords it asks for: the student password on bastion (to copy the lab key), and the student sudo password on workstation. It then installs Podman, Skopeo, Git, a Python virtual environment with `ansible-navigator`, `ansible-lint`, `ansible-builder`, and `podman-compose`, plus VS Code with the Ansible and Dev Containers extensions. It finishes by logging in as `devops` to all four managed hosts. Expected final lines include:

```
servera.lab.example.com sudo:root
serverb.lab.example.com sudo:root
serverc.lab.example.com sudo:root
serverd.lab.example.com sudo:root
```

Open a new terminal afterward so `~/.local/bin` is on your `PATH`.

---

## 9. Reach the Lab from Your Host

Add the lab names to your host's hosts file (`/etc/hosts` on Linux and macOS, `C:\Windows\System32\drivers\etc\hosts` on Windows, edited as Administrator):

```
192.168.250.254 bastion.lab.example.com bastion
192.168.250.220 utility.lab.example.com utility content.example.com materials.example.com
192.168.250.9   workstation.lab.example.com workstation
192.168.250.10  servera.lab.example.com servera
192.168.250.11  serverb.lab.example.com serverb
192.168.250.12  serverc.lab.example.com serverc
192.168.250.13  serverd.lab.example.com serverd
```

Copy the lab key so you can log in without passwords:

```bash
scp student@bastion:.ssh/id_ed25519 ~/.ssh/rhlab_key
chmod 600 ~/.ssh/rhlab_key
```

`~/.ssh/config` on your host:

```
Host bastion utility workstation servera serverb serverc serverd *.lab.example.com
    User student
    IdentityFile ~/.ssh/rhlab_key
```

Now `ssh workstation` from your host lands on the control node. Opening `http://utility.lab.example.com:3000` in your host browser shows Gitea.

---

## 10. Developer Services and the `lab` Command

Continue in this order, because each step uses the previous one:

1. [`02_dev_services.md`](02_dev_services.md) sections 1 to 4: execution environment images in the lab registry and collection tarballs on materials.example.com.
2. [`01_lab_command.md`](01_lab_command.md): the local `lab start | grade | finish` framework. If you use the ready made `lab_framework` directory from this repository, read it to understand the framework and run its section 6 and 7 tests.
3. [`02_dev_services.md`](02_dev_services.md) sections 5 and 6: install the chapter exercises and verify.

Then come back for section 11.

---

## 11. Verify the Whole Lab

On workstation as `student`:

```bash
mkdir -p ~/lab_check && cd ~/lab_check

cat > ansible.cfg <<'EOF'
[defaults]
inventory = ./inventory
remote_user = devops

[privilege_escalation]
become = true
EOF

cat > inventory <<'EOF'
[webservers]
servera.lab.example.com
serverb.lab.example.com

[dbservers]
serverc.lab.example.com
serverd.lab.example.com
EOF

cat > check.yml <<'EOF'
---
- name: Validate the local RH294 lab
  hosts: all
  gather_facts: true
  tasks:
    - name: Check the spare disk
      ansible.builtin.stat:
        path: /dev/vdb
        follow: true
      register: vdb

    - name: Confirm /dev/vdb is a block device
      ansible.builtin.assert:
        that: vdb.stat.exists and vdb.stat.isblk
        fail_msg: "/dev/vdb missing on {{ inventory_hostname }}"

    - name: Confirm the address is in the lab network
      ansible.builtin.assert:
        that: ansible_facts['default_ipv4']['address'] is match('192\.168\.250\.')

    - name: Confirm content.example.com serves AppStream
      ansible.builtin.uri:
        url: "http://content.example.com/rhel{{ ansible_facts['distribution_major_version'] }}/AppStream/repodata/repomd.xml"

    - name: Confirm internet access through bastion
      ansible.builtin.uri:
        url: https://galaxy.ansible.com
        status_code: [200, 301, 302]

    - name: Read the time source
      ansible.builtin.command: chronyc -n sources
      register: chrony
      changed_when: false

    - name: Confirm bastion is the time source
      ansible.builtin.assert:
        that: "'192.168.250.254' in chrony.stdout"

    - name: Install a package from the lab repositories
      ansible.builtin.dnf:
        name: tree
        state: present
EOF

ansible all -m ansible.builtin.ping
ansible-playbook check.yml
ansible all -m ansible.builtin.dnf -a 'name=tree state=absent'
```

Pass criteria: four `pong` replies, and `failed=0` for all four hosts in `check.yml`.

---

## 12. Baseline Snapshots and Reset

The cloud classroom lets you delete and recreate the lab. Locally, you take one snapshot of the clean state and revert to it.

**When:** after section 11 passes and `02_dev_services.md` is complete. Shut down workstation and servera to serverd, then take a snapshot named `baseline` of each. bastion and utility need no baseline; utility keeps your Gitea repositories and registry images across resets.

| Hypervisor | Take baseline | Revert one VM |
|---|---|---|
| VirtualBox | `VBoxManage snapshot servera take baseline` | `VBoxManage controlvm servera poweroff; VBoxManage snapshot servera restore baseline; VBoxManage startvm servera --type headless` |
| VMware Workstation | `vmrun -T ws snapshot PATH/servera.vmx baseline` | `vmrun -T ws revertToSnapshot PATH/servera.vmx baseline; vmrun -T ws start PATH/servera.vmx nogui` |
| VMware Fusion | same with `-T fusion` | same with `-T fusion` |
| Hyper-V | `Checkpoint-VM -Name servera -SnapshotName baseline` | `Stop-VM servera -TurnOff; Restore-VMCheckpoint -VMName servera -Name baseline -Confirm:$false; Start-VM servera` |
| KVM | `sudo virsh snapshot-create-as servera baseline` | `sudo virsh snapshot-revert servera baseline --running` |
| Proxmox | `qm snapshot VMID baseline` | `qm rollback VMID baseline && qm start VMID` |

Reset all four managed hosts at once:

```bash
# VirtualBox on Linux or macOS
for vm in servera serverb serverc serverd; do
  VBoxManage controlvm $vm poweroff 2>/dev/null
  VBoxManage snapshot $vm restore baseline
  VBoxManage startvm $vm --type headless
done
```

```powershell
# Hyper-V
foreach ($vm in "servera","serverb","serverc","serverd") {
  Stop-VM $vm -TurnOff -ErrorAction SilentlyContinue
  Restore-VMCheckpoint -VMName $vm -Name baseline -Confirm:$false
  Start-VM $vm
}
```

To lower managed host memory to 1536 MB, change it while the VMs are off, **before** taking the baseline.

Keep your playbooks in Git and push them to Gitea or GitHub, so reverting workstation never costs you work.

---

## 13. Daily Workflow

1. Start bastion, then utility, then workstation and the managed hosts.
2. Revert servera to serverd to `baseline` when a chapter or mock exam needs clean hosts.
3. Work on workstation: `lab start EXERCISE`, do the work, `lab grade EXERCISE`, `lab finish EXERCISE`.
4. Shut down in reverse order.

---

## 14. Offline Mode

The real exam has no internet. After `02_dev_services.md` is complete, the lab needs none either. Disconnect bastion's NAT adapter in the hypervisor (VirtualBox: clear **Cable Connected**; VMware: clear **Connected**; Hyper-V: set the adapter to **Not connected**; KVM: `virsh domif-setlink bastion NIC_MAC down`). DNS, NTP, repositories, registry, and Gitea keep working. Reconnect it when you need to download something.

---

## 15. Using a Different Class C Subnet

If `192.168.250.0/24` is already used on your network, pick another unused `192.168.X.0/24` and change it in exactly three places **before** building:

1. The lab network in your hypervisor (section 4): host address `192.168.X.1`.
2. `LAB_NET=192.168.250` at the top of `scripts/bastion_setup.sh`.
3. Your host's hosts file (section 9) and the boot lines (sections 7 and 8), which use bastion's address `192.168.X.254`.

Nothing else in the course uses IP addresses. The check in section 11 tests for `192.168.250.`; adjust that one line too.

---

## 16. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `bastion_setup.sh`: "No default route" | Adapter 1 not on NAT, or NAT disconnected | Fix adapter 1 in the hypervisor, `sudo nmcli device connect IFACE`, run the script again |
| `bastion_setup.sh`: "Only one ethernet adapter" | Adapter 2 missing | Add the lab adapter with bastion powered off |
| LAB and WAN detected the wrong way round | Both adapters had a default route | Make sure only adapter 1 is on a NAT network with DHCP, then run the script again |
| Installer stops with `dracut-initqueue timeout` or cannot fetch the Kickstart | Hypervisor DHCP still on, or VM not on the lab network, or bastion firewall | Disable hypervisor DHCP on the lab network; on bastion `sudo firewall-cmd --zone=internal --list-services` must include dhcp and http |
| VM gets a `.100` to `.199` address after installation | Kickstart not used | The boot line was not applied; reinstall and check the `inst.ks=` text |
| VM reinstalls itself or shows the DVD menu after installation | Optical drive before disk in boot order | Put the hard disk first |
| Hyper-V VM does not boot the DVD | Secure Boot template | Use **Microsoft UEFI Certificate Authority** |
| VirtualBox on macOS or Linux refuses the host only range | `networks.conf` restriction | Add `* 192.168.250.0/24` to `/etc/vbox/networks.conf` |
| VMs cannot reach the internet | Missing forwarding policy | On bastion: `sudo firewall-cmd --info-policy=labnat` must show `target: ACCEPT`, ingress `internal`, egress `external` |
| Names do not resolve inside VMs | DNS not bastion | `cat /etc/resolv.conf` must show `nameserver 192.168.250.254`; on bastion `sudo systemctl status dnsmasq` |
| `utility_setup.sh` stops asking for the DVD | Kickstart copy failed | Attach the ISO to utility and run the script again |
| `/dev/vdb` missing on a managed host | Data disk added after installation | `ls /etc/udev/rules.d/90-lab-vdb.rules`; reinstall the host with both disks attached |
| Gitea or registry not answering after a reboot | Containers still pulling or starting | On utility: `sudo systemctl status gitea registry`; wait one minute |
| Clock differences between VMs | bastion time service | On bastion `chronyc tracking`; on a VM `chronyc -n sources` must list 192.168.250.254 |

---

## 17. Differences from the Official Classroom

| Area | Cloud classroom | This lab | Effect on study |
|---|---|---|---|
| Network | 172.25.250.0/24 | 192.168.250.0/24 (Class C private) | None; the course uses host names only |
| classroom, content, materials | Separate server | Aliases of utility | None |
| `lab` command | Red Hat scripts | Local framework (`01_lab_command.md`) with the same syntax | Exercises in this repository ship for the local framework |
| Environment reset | Web UI | Hypervisor snapshots (section 12) | Faster |
| Spare disk | virtio `vdb` | Real `vdb` on KVM and Proxmox, `/dev/vdb` link elsewhere | Facts show the real name on non virtio hypervisors |
| Lab hours | Limited | Unlimited | Repeat mock exams as often as needed |

<!-- navfoot:start -->

---

Next: [00 Lab Setup, Part 2: The `lab` Command (start, grade, finish)](01_lab_command.md) →

<!-- navfoot:end -->
