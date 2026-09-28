<!-- nav:start -->
[Course home](../README.md) › [00 Lab Setup: Build the Complete Lab, Step 1 to Step 6](README.md) › Lesson (1 of 2)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guide: [00 Lab Setup Reference: How the `lab` Command Works](01_lab_command.md)
<!-- nav:end -->

# 00 Lab Setup: Build the Complete Lab, Step 1 to Step 6

This page is the **only** document you need to build the lab. Follow it from top to bottom. Every step says why it exists, what it needs from the previous step, what to do, and how to check the result before you move on. Do not start a step until the checkpoint of the previous step passes.

| Step | What you do | Where you work | Time |
|---|---|---|---|
| [Step 1](#step-1-prepare-your-computer) | Check your computer, pick a hypervisor, download RHEL and the course files | Your computer | 1 to 2 hours (mostly downloads) |
| [Step 2](#step-2-create-the-lab-network-and-the-seven-vms) | Create the private lab network and seven empty VMs | Hypervisor | 30 to 45 minutes |
| [Step 3](#step-3-build-bastion) | Install bastion by hand and turn it into the lab's router, DNS, time, and install server | bastion console, then your computer | 45 minutes |
| [Step 4](#step-4-build-utility) | Install utility automatically and start the repositories, registry, and Git server | utility | 45 to 60 minutes |
| [Step 5](#step-5-build-workstation-and-the-four-managed-hosts) | Install workstation and servera to serverd automatically, then set up the control node tools | All five VMs, then workstation desktop | 60 to 90 minutes |
| [Step 6](#step-6-load-the-course-verify-everything-and-take-snapshots) | Load images, collections, and the course exercises; verify the whole lab; take snapshots | workstation | 45 to 60 minutes |

After Step 6 you never build again: you revert snapshots. [Using the lab every day](#using-the-lab-every-day) at the end explains the daily routine.

---

## How the Pieces Fit Together

Read this once before Step 1. It explains why the steps are in this order.

```
                         Internet
                            |
              Hypervisor NAT network (your hypervisor's default)
                            |
                     bastion NIC 1 (WAN)
                  +=====================+
                  |       bastion       |  router with NAT, DNS, DHCP for installs,
                  |   192.168.250.254   |  time server, web server with install files
                  +=====================+
                     bastion NIC 2 (LAB)
                            |
     Lab network 192.168.250.0/24: private, no hypervisor DHCP
                            |
   +----------+-----------+-----------+----------+----------+----------+
   |          |           |           |          |          |          |
 your       utility   workstation  servera    serverb    serverc    serverd
 computer    .220        .9          .10        .11        .12        .13
   .1       repos,     Ansible      managed hosts, each with an empty
            registry,  control      5 GB second disk
            Git        node (GUI)
```

| Component | Provides | Needed by | Therefore built in |
|---|---|---|---|
| Lab network | A private network all VMs share | Everything | Step 2 |
| bastion | Internet access (NAT), host names (DNS), temporary addresses for installers (DHCP), time (NTP), and the automatic install files | Every other VM, from its very first boot | Step 3, first VM |
| utility | RHEL package repositories (`content.example.com`), collection files (`materials.example.com`), container registry (port 5000), Git server Gitea (port 3000) | workstation and servers install packages from it; the course stores images, collections, and Git repositories on it | Step 4, second VM |
| workstation | The machine you work on: Ansible, VS Code, containers, and the `lab` command | You, in every chapter | Step 5 |
| servera to serverd | Managed hosts that your playbooks configure | Every exercise | Step 5 |
| Course files and snapshots | Exercises, graded labs, and a clean state to return to | Every chapter | Step 6 |

**Address plan**

| Host | IP address | Also answers as |
|---|---|---|
| Your computer | 192.168.250.1 | |
| bastion.lab.example.com | 192.168.250.254 | |
| utility.lab.example.com | 192.168.250.220 | content.example.com, materials.example.com, classroom.example.com |
| workstation.lab.example.com | 192.168.250.9 | |
| servera to serverd.lab.example.com | 192.168.250.10 to .13 | |
| Temporary installer addresses | 192.168.250.100 to .199 | |

**Accounts** (identical on every VM; the passwords are deliberately simple because the lab is private)

| User | Password | Where | Used for |
|---|---|---|---|
| root | redhat | All VMs | Console recovery only |
| student | student | All VMs | Your login; sudo asks for the password |
| devops | redhat | servera to serverd | Ansible logs in as this user; sudo without a password |
| student (Gitea) | Student@123 | http://utility.lab.example.com:3000 | Git server account |

One SSH key pair, created on bastion in Step 3, lets `student` log in everywhere and `devops` on every managed host without passwords.

---

## Step 1: Prepare Your Computer

**Why:** everything later runs on your computer. A missing resource, a clashing network, or the wrong DVD only shows up hours later, so check them now.

### 1.1 Check your hardware

| Resource | Minimum that works | Recommended |
|---|---|---|
| CPU | 4 cores, virtualization (VT-x or AMD-V) enabled in the firmware | 8 threads |
| RAM | 24 GB | 32 GB |
| Free disk | 150 GB on an SSD | 250 GB on an SSD |

The seven VMs need about 16.5 GB of RAM while they install and 14.5 GB afterward, plus what your own operating system uses. With 16 GB you can build the lab, but you must not run all VMs at once: most exercises use only workstation, servera, and serverb, and each exercise page lists the hosts it needs.

### 1.2 Check that the lab network is free

The lab uses `192.168.250.0/24`. Look at your computer's addresses:

```bash
ip -4 addr | grep 192.168.250.        # Linux
ifconfig | grep 192.168.250.          # macOS
ipconfig | findstr 192.168.250.       # Windows
```

No output: continue with 1.3.

Output: your home or office network already uses that range. Choose another free `192.168.X.0/24` now and use it **everywhere this guide says 192.168.250**: in the hypervisor network (Step 2), in the first lines of `bastion_setup.sh` (Step 3.2 tells you where), on the installer boot lines (Steps 4 and 5), and in your hosts file (Step 3.5). Nothing in the chapters uses IP addresses, so no other change is needed.

### 1.3 Install one hypervisor

| Hypervisor | Runs on | Notes |
|---|---|---|
| Oracle VirtualBox 7 | Windows, Linux, Intel Mac | Free |
| VMware Workstation Pro 17 / Fusion 13 | Windows, Linux / Mac | Free for personal use |
| Microsoft Hyper-V | Windows 10 or 11 Pro or Enterprise | Built in; enable it in Windows Features |
| KVM with virt-manager | Linux | Fastest on Linux |
| Proxmox VE 8 | A separate server | Access it from your computer's browser |

On an **Apple Silicon Mac** use VMware Fusion or UTM and the **aarch64** RHEL DVD. That combination follows the same steps but has not been tested with this course.

Use one hypervisor for the whole lab. Step 2 has instructions for each.

### 1.4 Download RHEL

1. Create a free **Red Hat Developer Subscription for Individuals** at `https://developers.redhat.com`. You also need this account in Step 6 to copy container images.
2. Download the **RHEL 9 Binary DVD** ISO (x86_64; aarch64 for Apple Silicon). Take the full **DVD** image, about 10 GB, not the small boot ISO: every VM installs its packages from it.
3. Compare its checksum with the value on the download page:

```bash
sha256sum rhel-9.*-dvd.iso                 # Linux
shasum -a 256 rhel-9.*-dvd.iso             # macOS
Get-FileHash .\rhel-9.*-dvd.iso            # Windows PowerShell
```

### 1.5 Get the course files on your computer

You need `00_lab_setup/scripts/bastion_setup.sh` from this repository in Step 3. Either clone the repository:

```bash
git clone https://github.com/techgeek68/rhce-ansible-course.git rhce_ansible_course
```

or download it from GitHub with **Code, Download ZIP** and unpack it.

### Checkpoint 1

* [ ] Enough RAM and disk, virtualization enabled.
* [ ] Lab network range free (or your replacement range written down).
* [ ] Hypervisor installed and starting.
* [ ] RHEL DVD ISO downloaded, checksum matches.
* [ ] `rhce_ansible_course/00_lab_setup/scripts/bastion_setup.sh` exists on your computer.

---

## Step 2: Create the Lab Network and the Seven VMs

**Why:** the VMs must talk to each other on a network that is private (so the lab never interferes with your home network), reachable from your computer (so you can log in), and **without the hypervisor's own DHCP server** (bastion hands out installer addresses; two DHCP servers on one network break installations). Only bastion also connects to the hypervisor's NAT network to reach the internet.

### 2.1 Create the lab network

Follow **only** the part for your hypervisor.

**VirtualBox**

1. **File, Tools, Network Manager, Host-only Networks, Create.**
2. Adapter tab: **Configure Adapter Manually**, IPv4 address `192.168.250.1`, mask `255.255.255.0`.
3. DHCP Server tab: clear **Enable Server**.
4. Write down the network name (for example `vboxnet0`, or `VirtualBox Host-Only Ethernet Adapter #2` on Windows).
5. On Linux and macOS only: VirtualBox allows only listed ranges. Create or edit `/etc/vbox/networks.conf` and add the line `* 192.168.250.0/24`.

Command line alternative on Linux and macOS:

```bash
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.250.1 --netmask 255.255.255.0
VBoxManage dhcpserver remove --interface vboxnet0 2>/dev/null || true
```

**VMware Workstation Pro**: **Edit, Virtual Network Editor, Change Settings, Add Network** (for example `VMnet2`). Type **Host-only**; clear **Use local DHCP service**; keep **Connect a host virtual adapter**; subnet `192.168.250.0`, mask `255.255.255.0`.

**VMware Fusion**: **Settings, Network, `+`**; clear **Provide addresses on this network via DHCP**; subnet `192.168.250.0`, mask `255.255.255.0`.

**Hyper-V** (PowerShell as Administrator):

```powershell
New-VMSwitch -Name rhlab -SwitchType Internal
New-NetIPAddress -InterfaceAlias "vEthernet (rhlab)" -IPAddress 192.168.250.1 -PrefixLength 24
```

**KVM**:

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

No `<forward>` element keeps it private; no `<dhcp>` element keeps libvirt's DHCP off.

**Proxmox VE**: add to `/etc/network/interfaces`, then run `ifreload -a`:

```
auto vmbr250
iface vmbr250 inet static
    address 192.168.250.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

### 2.2 Create the seven VMs

Create every VM now, attach the RHEL DVD to each, and **leave them all powered off**.

| VM | vCPU | RAM | Disk 1 | Disk 2 | Network adapter 1 | Network adapter 2 |
|---|---|---|---|---|---|---|
| bastion | 1 | 1536 MB | 20 GB | none | **NAT** | **Lab network** |
| utility | 2 | 3072 MB | 60 GB | none | Lab network | none |
| workstation | 2 | 4096 MB | 40 GB | none | Lab network | none |
| servera | 1 | 2048 MB | 20 GB | **5 GB** | Lab network | none |
| serverb | 1 | 2048 MB | 20 GB | **5 GB** | Lab network | none |
| serverc | 1 | 2048 MB | 20 GB | **5 GB** | Lab network | none |
| serverd | 1 | 2048 MB | 20 GB | **5 GB** | Lab network | none |

Settings for **every** VM:

* Guest type Red Hat Enterprise Linux 9, 64 bit.
* RHEL DVD ISO in the optical drive. It stays attached: the automatic installs read packages from it.
* Boot order **hard disk first, then optical drive**. A new, empty disk cannot boot, so the VM starts the DVD; once installed, it boots from disk and never reinstalls by accident.
* Disks dynamically allocated (thin provisioned).
* For bastion, adapter 1 must be NAT and adapter 2 the lab network, in that order: the setup script uses the adapter with internet access as the outside and the other one as the lab side.
* The servers' 5 GB second disk is the empty disk that the storage chapters use. It must exist **before** installation.

Hypervisor specifics:

| Hypervisor | Lab network in the VM settings | Other settings |
|---|---|---|
| VirtualBox | **Host-only Adapter**, the network from 2.1 | Keep the default SATA disk controller |
| VMware | **Custom: VMnet2** (Workstation) or your new network (Fusion) | Defaults |
| Hyper-V | Switch **rhlab**; bastion adapter 1 on **Default Switch**, adapter 2 on **rhlab**, added in that order | **Generation 2**, Secure Boot template **Microsoft UEFI Certificate Authority**, dynamic memory **off** |
| KVM | Network **rhlab**; bastion adapter 1 on network **default** | **virtio** disks and network, **BIOS** firmware (keeps snapshots simple) |
| Proxmox | Bridge **vmbr250**; bastion `net0` on your uplink bridge (for example `vmbr0`), `net1` on `vmbr250` | VirtIO disks |

Example for one managed host, **Hyper-V** (repeat with the names and sizes from the table):

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

Example for one managed host, **KVM**:

```bash
sudo virt-install --name servera --memory 2048 --vcpus 1 --boot hd,cdrom \
  --disk size=20,bus=virtio --disk size=5,bus=virtio \
  --disk path=/var/lib/libvirt/images/rhel9-dvd.iso,device=cdrom,readonly=on \
  --network network=rhlab,model=virtio --os-variant rhel9.0 \
  --graphics spice --import --print-xml > servera.xml
sudo virsh define servera.xml          # defined, not started
```

`--print-xml` only writes the definition, so the VM stays off until Step 5. For bastion use two `--network` options, `network=default` first and `network=rhlab` second.

### Checkpoint 2

From your computer:

```bash
ping -c1 192.168.250.1          # Linux, macOS; Windows: ping -n 1 192.168.250.1
```

* [ ] Your computer answers on 192.168.250.1 (its own lab address).
* [ ] Seven VMs exist, all powered off, each with the DVD attached and disk before optical drive.
* [ ] bastion has two adapters: NAT first, lab network second.
* [ ] servera to serverd each have a 5 GB second disk.
* [ ] The hypervisor's DHCP is off on the lab network.

---

## Step 3: Build bastion

**Why:** bastion is the only VM installed by hand, because nothing exists yet to automate an install. Once its setup script has run, bastion gives every other VM a network address, names, internet access, and an automatic installation file. That is why it must be complete before any other VM starts.

### 3.1 Install RHEL on bastion

Start bastion, choose **Install Red Hat Enterprise Linux 9**, and set:

| Installer screen | Setting |
|---|---|
| Language | English (United States) |
| Installation Destination | The 20 GB disk, automatic partitioning |
| Software Selection | **Minimal Install** |
| Network & Host Name | Host name `bastion.lab.example.com`, click **Apply**. Switch **both** adapters **ON**. The NAT adapter gets an address; the lab adapter stays without one, which is correct |
| Time & Date | Region Etc, city UTC |
| Root Password | `redhat` (click **Done** twice, because it is weak) |
| User Creation | Name `student`, password `student`, **Make this user administrator** selected |

Click **Begin Installation**, then **Reboot System**. Keep the DVD attached: the setup script uses it as its package source.

### 3.2 Copy the setup script to bastion

Log in on bastion's **console** window as `student`. Choose one way:

**A. Download it from GitHub** (bastion already has internet through its NAT adapter):

```bash
curl -LO https://raw.githubusercontent.com/techgeek68/rhce-ansible-course/main/00_lab_setup/scripts/bastion_setup.sh
```

**B. Copy it from your computer.** First give bastion a temporary lab address. Find the lab adapter name (the one **without** an IP address):

```bash
ip -br addr                                         # for example enp0s8 has no address
sudo ip addr add 192.168.250.254/24 dev enp0s8      # temporary, lost at reboot
```

Then, on your computer, in the folder where you unpacked the course:

```bash
scp 00_lab_setup/scripts/bastion_setup.sh student@192.168.250.254:
```

If you chose a different lab range in Step 1.2, edit the first lines of the script on bastion now: `vi bastion_setup.sh`, change `LAB_NET=192.168.250` to your range, save.

### 3.3 Run the setup script

Still on the bastion console (not over SSH: the script changes networking and would cut an SSH session):

```bash
sudo bash bastion_setup.sh
```

It takes 2 to 5 minutes and, in this order:

1. uses the DVD as a temporary package source and installs dnsmasq, httpd, chrony, and firewalld;
2. finds the adapter with internet access (WAN) and the other one (LAB), and gives LAB the fixed address `192.168.250.254/24`;
3. puts WAN in firewall zone `external` with NAT, LAB in zone `internal`, and forwards lab traffic to the internet;
4. answers DNS for every lab name and the `*.example.com` aliases, and runs DHCP from `.100` to `.199` for installers only;
5. serves time to the lab, even when the internet is unreachable;
6. creates the lab SSH key pair for `student`;
7. writes an automatic installation file (Kickstart) for each VM and the utility and workstation setup scripts to `http://192.168.250.254/lab/`;
8. switches bastion's own package source to `content.example.com`, which utility provides from Step 4 on.

It ends with a summary that repeats the build order: utility, then workstation and the servers.

### 3.4 Check bastion

On bastion:

```bash
ip -br addr                                          # LAB adapter shows 192.168.250.254/24
sudo firewall-cmd --get-active-zones                 # external: WAN adapter; internal: LAB adapter
dig +short @192.168.250.254 content.example.com      # 192.168.250.220
curl -s http://192.168.250.254/lab/ks/ | grep -o '[a-z]*\.ks' | sort -u
```

The last command lists six files: `servera.ks` to `serverd.ks`, `utility.ks`, `workstation.ks`.

`dnf` does not work on bastion until utility exists; that is expected.

### 3.5 Reach the lab from your computer

From now on you work over SSH from your own computer, which is more comfortable than VM console windows.

1. Add the lab names to your computer's hosts file (`/etc/hosts` on Linux and macOS with `sudo`; `C:\Windows\System32\drivers\etc\hosts` on Windows, editor started as Administrator):

```
192.168.250.254 bastion.lab.example.com bastion
192.168.250.220 utility.lab.example.com utility content.example.com materials.example.com
192.168.250.9   workstation.lab.example.com workstation
192.168.250.10  servera.lab.example.com servera
192.168.250.11  serverb.lab.example.com serverb
192.168.250.12  serverc.lab.example.com serverc
192.168.250.13  serverd.lab.example.com serverd
```

2. Copy the lab key to your computer (password `student`):

```bash
scp student@bastion:.ssh/id_ed25519 ~/.ssh/rhlab_key
chmod 600 ~/.ssh/rhlab_key
```

3. Add to `~/.ssh/config` on your computer (create the file if needed):

```
Host bastion utility workstation servera serverb serverc serverd *.lab.example.com
    User student
    IdentityFile ~/.ssh/rhlab_key
```

### Checkpoint 3

From your computer:

```bash
ssh bastion hostname                                  # bastion.lab.example.com, no password asked
curl -s http://bastion.lab.example.com/lab/scripts/ | grep -o '[a-z_]*setup\.sh' | sort -u
```

* [ ] SSH to bastion works without a password.
* [ ] `utility_setup.sh` and `workstation_setup.sh` are listed.

| If this fails | Cause | Fix |
|---|---|---|
| Script stops: "No default route" | Adapter 1 not NAT, or disconnected | Fix adapter 1 in the hypervisor; `sudo nmcli device connect ADAPTER`; run the script again |
| Script stops: "Only one ethernet adapter" | Adapter 2 missing | Power off bastion, add the lab adapter, start, run the script again |
| Script stops: "No repositories and no RHEL DVD found" | DVD not attached | Attach the ISO, run the script again |
| Wrong adapter gets 192.168.250.254 | Both adapters had internet | Only adapter 1 may be on a NAT network with DHCP |
| `ssh bastion` asks for a password | Key or config not in place | Repeat 3.5 steps 2 and 3; check `ls -l ~/.ssh/rhlab_key` |

Running the script again is always safe.

---

## Step 4: Build utility

**Why:** utility is the lab's content server. From here on, every VM installs its packages from utility (`content.example.com`) instead of the internet, exactly as in a classroom or exam. Later steps also store container images, collection files, and Git repositories on it. It must exist before workstation and the servers, because their installations point to it.

### 4.1 Start the automatic installation

The installation is automatic once the installer knows where its Kickstart file is. You type that location once, at the DVD boot menu.

1. Start utility. The DVD boot menu appears.
2. Highlight **Install Red Hat Enterprise Linux 9** (do not press Enter yet).
3. Open the boot line:
   * **UEFI** (Hyper-V Generation 2, VMware, VirtualBox with EFI): press `e`, move to the end of the line starting with `linux` or `linuxefi`.
   * **BIOS** (KVM and VirtualBox defaults): press `Tab`; the cursor is at the end of the line.
4. Type a space and then:

```
inst.ks=http://192.168.250.254/lab/ks/utility.ks ip=dhcp
```

5. Start: `Ctrl+X` (UEFI) or `Enter` (BIOS).

The installer gets a temporary address from bastion, downloads `utility.ks`, and installs without questions. utility also copies the whole DVD to its disk to serve it as a repository, so this install takes 15 to 30 minutes. It reboots into the installed system on its own.

### 4.2 Run the utility setup script

From your computer:

```bash
ssh utility
curl -sO http://bastion.lab.example.com/lab/scripts/utility_setup.sh
sudo bash utility_setup.sh
```

It checks the repository copy (and copies from the DVD drive if the installer could not), opens ports 80, 3000, and 5000, starts the container registry and the Gitea Git server as services, and creates the Gitea account `student`.

### Checkpoint 4

The script ends with three lines; all must show `200`:

```
content repo   200
registry       200
gitea          200
```

Also confirm that bastion can now install packages from utility, which proves the content server works for everyone:

```bash
ssh bastion 'sudo dnf -q repolist'          # lab-baseos and lab-appstream
```

Open `http://utility.lab.example.com:3000` in your computer's browser: the Gitea start page appears.

| If this fails | Cause | Fix |
|---|---|---|
| Installer: `dracut-initqueue timeout`, or it cannot fetch the Kickstart | Hypervisor DHCP still on, VM not on the lab network, or a typo in the boot line | Fix Step 2.1 or the VM adapter; reboot utility and type the line again |
| utility has a `.100` to `.199` address after installation | The boot line was not applied | Reinstall; check the `inst.ks=` text |
| VM shows the DVD menu again after installation | Optical drive first in boot order | Put the hard disk first |
| Script stops asking for the DVD | The installer could not copy it | Attach the ISO to utility, run the script again |
| `registry` or `gitea` not 200 right after a reboot | Containers still starting | Wait one minute; `sudo systemctl status gitea registry` |

---

## Step 5: Build workstation and the Four Managed Hosts

**Why:** workstation is where you work in every chapter, and servera to serverd are the machines your playbooks configure. Their automatic installations give them fixed addresses, lab repositories, bastion as time source, the lab SSH key, and (on the servers) the `devops` user Ansible logs in as. The setup script then installs the control node tools on workstation and proves it can manage all four servers.

### 5.1 Start the five automatic installations

For each VM, start it and add its line at the DVD boot menu exactly as in Step 4.1 (highlight the install entry, `e` or `Tab`, append, `Ctrl+X` or `Enter`):

| VM | Text to append to the boot line |
|---|---|
| workstation | `inst.ks=http://192.168.250.254/lab/ks/workstation.ks ip=dhcp` |
| servera | `inst.ks=http://192.168.250.254/lab/ks/servera.ks ip=dhcp` |
| serverb | `inst.ks=http://192.168.250.254/lab/ks/serverb.ks ip=dhcp` |
| serverc | `inst.ks=http://192.168.250.254/lab/ks/serverc.ks ip=dhcp` |
| serverd | `inst.ks=http://192.168.250.254/lab/ks/serverd.ks ip=dhcp` |

With 32 GB of RAM you can run all five at once; otherwise install them one or two at a time. Each reboots into the installed system when finished (workstation takes longest because it installs a desktop).

What the installations configure:

| Item | workstation | servera to serverd |
|---|---|---|
| Fixed address; gateway and DNS 192.168.250.254; search domain lab.example.com | Yes | Yes |
| Package repositories from content.example.com | Yes | Yes |
| Time from bastion | Yes | Yes |
| Software | Desktop (Server with GUI), ansible-core, rhel-system-roles, git | Minimal, python3 |
| `student` trusts the lab key | Yes | Yes |
| `devops` with sudo without password and the lab key | No | Yes |
| Spare 5 GB disk left empty, also reachable as `/dev/vdb` | No | Yes |

About `/dev/vdb`: chapters call the spare disk `/dev/vdb`, the name it gets on KVM. On VirtualBox, VMware, and Hyper-V it is really `sdb` or `nvme0n2`. The installation always uses the **largest** disk for the system and, on those hypervisors, adds a link so the spare disk also answers as `/dev/vdb`. Facts and `lsblk` still show the real name; the storage chapter explains how to find it.

### 5.2 Check the managed hosts

From your computer:

```bash
for h in servera serverb serverc serverd; do ssh $h 'hostname; lsblk -dno NAME,SIZE | sort'; done
```

Each prints its full name and two disks, one of them 5G.

### 5.3 Run the workstation setup script

This script must run **on the workstation desktop**, because it installs VS Code into your graphical session. In the workstation VM window, log in as `student` (password `student`), open **Activities, Terminal**, and run:

```bash
curl -sO http://bastion.lab.example.com/lab/scripts/workstation_setup.sh
bash workstation_setup.sh
```

Passwords it asks for: `student` twice, first for bastion (to copy the lab key), then for sudo on workstation. It needs internet access through bastion, because it downloads Python packages and VS Code. It installs Podman, Skopeo, Git, `ansible-navigator`, `ansible-lint`, `ansible-builder`, `podman-compose`, and VS Code with the Ansible and Dev Containers extensions, then logs in as `devops` to every managed host.

### Checkpoint 5

The script's last lines must include:

```
servera.lab.example.com sudo:root
serverb.lab.example.com sudo:root
serverc.lab.example.com sudo:root
serverd.lab.example.com sudo:root
```

Close the terminal and open a new one (so `~/.local/bin` is on your `PATH`), then:

```bash
ansible --version | head -1
ansible-navigator --version
code --list-extensions               # redhat.ansible and ms-vscode-remote.remote-containers
```

From now on you can also work on workstation from your computer with `ssh workstation`.

| If this fails | Cause | Fix |
|---|---|---|
| `scp: Permission denied` for the key | Wrong bastion password | The student password is `student`; run the script again |
| `pip` or VS Code download fails | No internet from the lab | On bastion: `sudo firewall-cmd --info-policy=labnat` must show `target: ACCEPT`; `ping -c1 8.8.8.8` from workstation |
| A server missing from the `sudo:root` lines | That installation did not use its Kickstart | Check its address with `ssh SERVER ip -br addr`; reinstall it with the right boot line |
| Server has only one disk | Second disk added after installation | Add the 5 GB disk, reinstall that server |
| `ansible-navigator: command not found` | Old terminal | Open a new terminal |

---

## Step 6: Load the Course, Verify Everything, and Take Snapshots

**Why:** the machines exist, but the course also needs content on them: the container images that run your playbooks, the collection files that the exam style exercises install, and the course's own exercises with the `lab` command. Then one playbook tests the whole lab, and snapshots freeze this clean state so you can return to it in seconds.

Work on workstation as `student` for the whole step (`ssh workstation` from your computer, or a terminal on its desktop).

### 6.1 Copy the execution environment images into the lab registry

`ansible-navigator` runs playbooks inside container images. The course expects them in the lab registry on utility, so every exercise works even offline:

```bash
skopeo login registry.redhat.io          # your Red Hat Developer account from Step 1.4

for img in ee-supported-rhel9 ansible-dev-tools-rhel9; do
  skopeo copy --dest-tls-verify=false \
    docker://registry.redhat.io/ansible-automation-platform-26/$img:latest \
    docker://utility.lab.example.com:5000/ansible-automation-platform-26/$img:latest
done
```

The download is several gigabytes. If the copy fails with `unauthorized`, your account cannot pull Ansible Automation Platform images. Use the free community images under the same lab names instead, so every course file still works:

```bash
skopeo copy --dest-tls-verify=false \
  docker://ghcr.io/ansible-community/community-ee-base:latest \
  docker://utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest

skopeo copy --dest-tls-verify=false \
  docker://ghcr.io/ansible/community-ansible-dev-tools:latest \
  docker://utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest
```

The community execution environment contains fewer collections; the course copies the ones it needs into each exercise project, so it works with either image.

Download both images to workstation now, so the first exercise does not wait:

```bash
podman pull utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest
podman pull utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest
curl -s http://utility.lab.example.com:5000/v2/_catalog
```

The catalog lists both image names.

### 6.2 Publish collection files on materials.example.com

Like the exam, exercises install collections from files on an internal web server:

```bash
mkdir -p ~/collection_mirror
ansible-galaxy collection download -p ~/collection_mirror \
  ansible.posix community.general containers.podman
scp ~/collection_mirror/*.tar.gz utility:/tmp/
ssh -t utility 'sudo mv /tmp/*.tar.gz /var/www/html/materials/collections/ && sudo restorecon -R /var/www/html/materials'
curl -s http://materials.example.com/collections/ | grep -o '[a-z_]*-[a-z_]*-[0-9.]*\.tar\.gz' | sort -u
```

The last command lists three files: `ansible-posix-*`, `community-general-*`, `containers-podman-*`. (`ssh -t utility` asks for the student sudo password on utility.)

The RHEL system roles need no download: the `rhel-system-roles` package is already on workstation.

### 6.3 Put the course on workstation and install the `lab` command

```bash
git clone https://github.com/techgeek68/rhce-ansible-course.git ~/rhce_ansible_course
cd ~/rhce_ansible_course/lab_framework
./install.sh
exec bash
lab list
```

`install.sh` asks for the student sudo password, installs the framework in `/opt/rh294lab`, and puts `lab` on your `PATH` with tab completion. `lab list` shows every exercise of the course:

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

Your own work in exercises goes to `/home/student/EXERCISE`, outside the clone, so updating the course later never touches it.

### 6.4 Test the `lab` command once

This proves that start, grade, and finish work against real hosts before you rely on them in Chapter 1.

```bash
lab start sample_webserver
lab grade sample_webserver
```

Every check shows `FAIL`, because nothing is configured yet: the grader works. Now solve it:

```bash
cd ~/sample_webserver
POSIX=$(curl -s http://materials.example.com/collections/ | grep -o 'ansible-posix-[0-9.]*\.tar\.gz' | head -1)
ansible-galaxy collection install -p collections "http://materials.example.com/collections/$POSIX"

cat > site.yml <<'EOF'
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
EOF

ansible-playbook site.yml
lab grade sample_webserver
```

Every check now shows `PASS` and the last line is `Overall lab grade: PASS`. Clean up:

```bash
cd ~
lab finish sample_webserver
```

Details of the output, and how the framework works inside, are in the optional reference [How the `lab` Command Works](01_lab_command.md).

### 6.5 Verify the whole lab

One playbook tests every connection the course depends on: SSH and sudo, the spare disk, addresses, repositories, internet, time, and package installation.

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
- name: Validate the local lab
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

Pass: four `pong` replies, then `failed=0` for all four hosts. (If you use another lab range, change `192\.168\.250\.` in the address check.)

### 6.6 Take the baseline snapshots

Snapshots are your reset button. Shut down workstation and servera to serverd (`sudo systemctl poweroff` on each, or from the hypervisor), then take a snapshot named `baseline` of each of those five VMs. bastion and utility need none: utility keeps your Gitea repositories and images across resets.

If you have 16 to 24 GB of RAM, lower the managed hosts to 1536 MB **now**, while they are off and before the snapshot.

| Hypervisor | Take the snapshot |
|---|---|
| VirtualBox | `VBoxManage snapshot servera take baseline` |
| VMware Workstation | `vmrun -T ws snapshot PATH/servera.vmx baseline` |
| VMware Fusion | `vmrun -T fusion snapshot PATH/servera.vmx baseline` |
| Hyper-V | `Checkpoint-VM -Name servera -SnapshotName baseline` |
| KVM | `sudo virsh snapshot-create-as servera baseline` |
| Proxmox | `qm snapshot VMID baseline` |

Repeat for workstation, serverb, serverc, and serverd.

### Checkpoint 6: the lab is complete

* [ ] Both images are in the lab registry and on workstation.
* [ ] Three collection files are listed on materials.example.com.
* [ ] `lab list` shows every exercise.
* [ ] `sample_webserver` went from all FAIL to all PASS, then `lab finish` ran.
* [ ] `check.yml` finished with `failed=0` on four hosts.
* [ ] Five `baseline` snapshots exist.

| If this fails | Cause | Fix |
|---|---|---|
| `skopeo copy` very slow or times out | Internet path through bastion | On workstation `curl -I https://registry.redhat.io`; on bastion `sudo firewall-cmd --info-policy=labnat` |
| `lab: command not found` | Old shell | `exec bash`, or open a new terminal |
| `lab start` stops at "Checking that lab systems are reachable" | A host is off or SSH as devops fails | Start the host; `ssh devops@servera.lab.example.com true` |
| Precheck fails for `utility` (Chapter 8 exercises) | Key not accepted by student on utility | `ssh utility true` from workstation must work without a password |
| `lab grade` shows FAIL after the solution | Playbook not run, or run in another directory | Run `ansible-playbook site.yml` inside `~/sample_webserver` |
| `check.yml` fails on internet access | bastion NAT | See the first row |
| `check.yml` fails on the time source | chrony not synced yet | Wait two minutes; `chronyc -n sources` on the host |

You are ready for [Chapter 1](../01_introduction/README.md).

---

## Using the Lab Every Day

### Start and stop

1. Start bastion, then utility, then workstation and the managed hosts you need.
2. Work on workstation: `lab start EXERCISE`, do the work, `lab grade EXERCISE` for graded labs, `lab finish EXERCISE`.
3. Shut down in reverse order: managed hosts and workstation, then utility, then bastion.

### Reset to the clean state

`lab finish` cleans up after each exercise. When something is broken beyond that, or before a timed practice run, revert to the baseline snapshots:

| Hypervisor | Revert one VM |
|---|---|
| VirtualBox | `VBoxManage controlvm servera poweroff; VBoxManage snapshot servera restore baseline; VBoxManage startvm servera --type headless` |
| VMware Workstation | `vmrun -T ws revertToSnapshot PATH/servera.vmx baseline; vmrun -T ws start PATH/servera.vmx nogui` |
| VMware Fusion | same with `-T fusion` |
| Hyper-V | `Stop-VM servera -TurnOff; Restore-VMCheckpoint -VMName servera -Name baseline -Confirm:$false; Start-VM servera` |
| KVM | `sudo virsh snapshot-revert servera baseline --running` |
| Proxmox | `qm rollback VMID baseline && qm start VMID` |

All four managed hosts at once:

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

Reverting workstation deletes the course clone and your projects there. Push your work to Gitea or GitHub first, and after a workstation revert run `cd ~/rhce_ansible_course && git pull && cd lab_framework && ./install.sh`.

### Get new chapters

```bash
cd ~/rhce_ansible_course
git pull
cd lab_framework && ./install.sh
```

### Work offline, like the exam

After Step 6 the lab needs no internet. Disconnect bastion's NAT adapter in the hypervisor (VirtualBox: clear **Cable Connected**; VMware: clear **Connected**; Hyper-V: set the adapter to **Not connected**; KVM: `virsh domif-setlink bastion MAC down`). DNS, time, repositories, registry, and Gitea keep working. Reconnect it to download something.

### Differences from a Red Hat classroom

| Area | Classroom | This lab | Effect |
|---|---|---|---|
| Network | 172.25.250.0/24 | 192.168.250.0/24 | None; the course uses host names |
| classroom, content, materials | A separate server | Names of utility | None |
| `lab` command | Red Hat's | This course's framework, same syntax | Exercise names use underscores |
| Reset | Web page | Snapshots | Faster |
| Spare disk | `vdb` | Real `vdb` on KVM and Proxmox, a `/dev/vdb` link elsewhere | Facts show the real name |

<!-- navfoot:start -->

---

Next: [00 Lab Setup Reference: How the `lab` Command Works](01_lab_command.md) →

<!-- navfoot:end -->
