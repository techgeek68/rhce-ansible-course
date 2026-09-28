#!/usr/bin/env bash
# bastion_setup.sh
# Turns a minimal RHEL installation with two network adapters into the lab
# bastion: router with NAT, DNS, DHCP for installs, NTP, and the web server
# that publishes Kickstart files and setup scripts for every other lab VM.
#
# Usage (as root on the bastion console):  bash bastion_setup.sh
# Test mode (no system changes):            bash bastion_setup.sh --render-only DIR
set -euo pipefail

# ---------------------------------------------------------------------------
# Lab addressing: Class C private network 192.168.250.0/24
# Change LAB_NET here if 192.168.250.0/24 collides with a network you use.
# ---------------------------------------------------------------------------
LAB_NET=192.168.250
LAB_PREFIX=24
LAB_MASK=255.255.255.0
BASTION_IP=${LAB_NET}.254
DHCP_START=${LAB_NET}.100
DHCP_END=${LAB_NET}.199
DOMAIN=lab.example.com

NODES=(utility workstation servera serverb serverc serverd)
declare -A NODE_IP=(
  [utility]=${LAB_NET}.220
  [workstation]=${LAB_NET}.9
  [servera]=${LAB_NET}.10
  [serverb]=${LAB_NET}.11
  [serverc]=${LAB_NET}.12
  [serverd]=${LAB_NET}.13
)

WEB=/var/www/html/lab
RENDER_ONLY=""
if [[ ${1:-} == --render-only ]]; then
  RENDER_ONLY=${2:?"--render-only needs a target directory"}
  WEB=$RENDER_ONLY
fi

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
detect_release() {
  if [[ -n $RENDER_ONLY ]]; then REL_MAJOR=${REL_MAJOR:-9}; else
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ ${ID:-} == rhel ]] || die "This script expects Red Hat Enterprise Linux"
    REL_MAJOR=${VERSION_ID%%.*}
  fi
  REL=rhel${REL_MAJOR}
}

setup_dvd_repo() {
  log "Package source"
  if dnf -q repolist --enabled 2>/dev/null | grep -q .; then
    echo "Enabled repositories found, using them."
    return
  fi
  mkdir -p /mnt/dvd
  local dev
  for dev in /dev/sr0 /dev/sr1 /dev/cdrom; do
    [[ -b $dev ]] || continue
    if mount -o ro "$dev" /mnt/dvd 2>/dev/null; then
      [[ -f /mnt/dvd/.treeinfo ]] && break
      umount /mnt/dvd
    fi
  done
  [[ -f /mnt/dvd/.treeinfo ]] || die "No repositories and no RHEL DVD found. Attach the DVD ISO to bastion."
  cat > /etc/yum.repos.d/lab-dvd.repo <<EOF
[lab-dvd-baseos]
name=RHEL DVD BaseOS
baseurl=file:///mnt/dvd/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[lab-dvd-appstream]
name=RHEL DVD AppStream
baseurl=file:///mnt/dvd/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
  echo "Using the RHEL DVD as a temporary package source."
}

install_packages() {
  log "Installing bastion packages"
  dnf -y install dnsmasq httpd chrony firewalld bind-utils tar
}

configure_network() {
  log "Network: WAN (NAT) and LAB (${LAB_NET}.0/${LAB_PREFIX})"
  hostnamectl set-hostname "bastion.${DOMAIN}"

  WAN=$(ip -4 route show default | awk '{print $5; exit}')
  [[ -n $WAN ]] || die "No default route. Adapter 1 must be attached to a NAT network with internet access."

  LAB=$(nmcli -t -f DEVICE,TYPE device | awk -F: -v w="$WAN" '$2=="ethernet" && $1!=w {print $1; exit}')
  [[ -n $LAB ]] || die "Only one ethernet adapter found. Adapter 2 must be attached to the lab network."
  echo "WAN interface: $WAN    LAB interface: $LAB"

  local uuid ifname
  for uuid in $(nmcli -g UUID connection show); do
    ifname=$(nmcli -g connection.interface-name connection show "$uuid")
    [[ $ifname == "$LAB" ]] && nmcli connection delete "$uuid" >/dev/null
  done
  nmcli connection add type ethernet ifname "$LAB" con-name lab \
    ipv4.method manual ipv4.addresses "${BASTION_IP}/${LAB_PREFIX}" \
    ipv4.never-default yes ipv6.method disabled \
    connection.zone internal connection.autoconnect yes >/dev/null
  nmcli connection up lab >/dev/null

  local wan_con
  wan_con=$(nmcli -g GENERAL.CONNECTION device show "$WAN")
  nmcli connection modify "$wan_con" connection.zone external connection.autoconnect yes
  nmcli connection up "$wan_con" >/dev/null

  cat > /etc/sysctl.d/90-lab-forward.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
  sysctl -q --system
}

configure_firewall() {
  log "Firewall: NAT from lab to WAN, lab services"
  systemctl enable --now firewalld
  firewall-cmd -q --permanent --zone=external --add-masquerade
  local svc
  for svc in ssh dns dhcp ntp http; do
    firewall-cmd -q --permanent --zone=internal --add-service="$svc"
  done
  if ! firewall-cmd -q --permanent --info-policy=labnat >/dev/null 2>&1; then
    firewall-cmd -q --permanent --new-policy=labnat
  fi
  firewall-cmd -q --permanent --policy=labnat --add-ingress-zone=internal
  firewall-cmd -q --permanent --policy=labnat --add-egress-zone=external
  firewall-cmd -q --permanent --policy=labnat --set-target=ACCEPT
  firewall-cmd -q --reload
  firewall-cmd -q --zone=internal --change-interface="$LAB"
  firewall-cmd -q --zone=external --change-interface="$WAN"
}

configure_dns_dhcp() {
  log "DNS and DHCP (dnsmasq on $LAB)"
  sed -i '/# rhlab begin/,/# rhlab end/d' /etc/hosts
  {
    echo "# rhlab begin"
    echo "${BASTION_IP} bastion.${DOMAIN} bastion"
    echo "${NODE_IP[utility]} utility.${DOMAIN} utility classroom.example.com content.example.com materials.example.com"
    local n
    for n in workstation servera serverb serverc serverd; do
      echo "${NODE_IP[$n]} ${n}.${DOMAIN} ${n}"
    done
    echo "# rhlab end"
  } >> /etc/hosts

  cat > /etc/dnsmasq.d/rhlab.conf <<EOF
# Lab DNS and DHCP. Names come from /etc/hosts on bastion.
interface=${LAB}
bind-dynamic
domain-needed
bogus-priv
domain=${DOMAIN}
local=/${DOMAIN}/
dhcp-range=${DHCP_START},${DHCP_END},${LAB_MASK},1h
dhcp-option=option:router,${BASTION_IP}
dhcp-option=option:dns-server,${BASTION_IP}
dhcp-option=option:ntp-server,${BASTION_IP}
dhcp-option=option:domain-search,${DOMAIN}
dhcp-authoritative
EOF
  systemctl enable dnsmasq >/dev/null 2>&1
  systemctl restart dnsmasq
}

configure_ntp() {
  log "Time service for the lab"
  sed -i '/# rhlab begin/,/# rhlab end/d' /etc/chrony.conf
  cat >> /etc/chrony.conf <<EOF
# rhlab begin
allow ${LAB_NET}.0/${LAB_PREFIX}
local stratum 10
# rhlab end
EOF
  systemctl enable chronyd >/dev/null 2>&1
  systemctl restart chronyd
}

create_lab_key() {
  log "Lab SSH key pair (student@bastion)"
  local home=/home/student
  id student >/dev/null 2>&1 || die "User student does not exist. Create it during installation."
  if [[ ! -f $home/.ssh/id_ed25519 ]]; then
    sudo -u student mkdir -p "$home/.ssh"
    chmod 700 "$home/.ssh"
    sudo -u student ssh-keygen -q -t ed25519 -N '' -C 'rh294-lab' -f "$home/.ssh/id_ed25519"
  fi
  PUBKEY=$(cat "$home/.ssh/id_ed25519.pub")
}

# ---------------------------------------------------------------------------
# Kickstart templates. Placeholders @NAME@ are replaced by render_ks.
# ---------------------------------------------------------------------------
ks_header() {
cat <<'KS_EOF'
# Kickstart for @FQDN@, generated by bastion_setup.sh
text
cdrom
lang en_US.UTF-8
keyboard us
timezone Etc/UTC
timesource --ntp-server=@BASTION_IP@
network --device=link --bootproto=static --ip=@IP@ --netmask=@LAB_MASK@ --gateway=@BASTION_IP@ --nameserver=@BASTION_IP@ --hostname=@FQDN@ --activate
rootpw --plaintext redhat
user --name=student --password=student --plaintext --groups=wheel
selinux --enforcing
firewall --enabled --ssh
services --enabled=sshd,chronyd
firstboot --disable
zerombr
%include /tmp/disk.ks
autopart --type=lvm --nohome

%pre --log=/tmp/ks-pre.log
# The largest disk is the system disk. Any smaller disk stays untouched.
disk=$(lsblk -dbnpo NAME,SIZE,TYPE | awk '$3=="disk" && $1 !~ /zram|loop/ {print $2" "$1}' | sort -n | tail -n1 | awk '{print $2}')
disk=${disk#/dev/}
echo "System disk: $disk"
cat > /tmp/disk.ks <<EOF
ignoredisk --only-use=$disk
clearpart --all --initlabel --drives=$disk
bootloader --boot-drive=$disk
EOF
%end
KS_EOF
}

ks_common_post() {
cat <<'KS_EOF'

%post --log=/root/ks-post.log
cat > /etc/NetworkManager/conf.d/90-lab-dns.conf <<'EOF'
[global-dns]
searches=@DOMAIN@

[global-dns-domain-*]
servers=@BASTION_IP@
EOF

install -d -m 700 -o student -g student /home/student/.ssh
echo '@PUBKEY@' > /home/student/.ssh/authorized_keys
chown student:student /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
restorecon -R /home/student/.ssh
%end
KS_EOF
}

ks_remote_repo() {
cat <<'KS_EOF'

%post --log=/root/ks-post-repo.log
cat > /etc/yum.repos.d/lab.repo <<'EOF'
[lab-baseos]
name=Lab @REL@ BaseOS
baseurl=http://content.example.com/@REL@/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[lab-appstream]
name=Lab @REL@ AppStream
baseurl=http://content.example.com/@REL@/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
%end
KS_EOF
}

ks_utility() {
cat <<'KS_EOF'

%packages
@^minimal-environment
httpd
podman
skopeo
chrony
vim-enhanced
bash-completion
tar
%end

%post --nochroot --log=/mnt/sysimage/root/ks-post-dvd.log
# Copy the installation DVD into the web root so utility can serve it as content.example.com.
src=$(dirname "$(find /run/install -maxdepth 4 -name .treeinfo 2>/dev/null | head -n1)")
if [ -n "$src" ] && [ -f "$src/.treeinfo" ]; then
  mkdir -p /mnt/sysimage/var/www/html/@REL@
  cp -a "$src/." /mnt/sysimage/var/www/html/@REL@/
  echo "Copied installation media from $src"
else
  echo "Installation media not found; utility_setup.sh will copy it from the DVD drive."
fi
%end

%post --log=/root/ks-post-repo.log
cat > /etc/yum.repos.d/lab.repo <<'EOF'
[lab-baseos]
name=Lab @REL@ BaseOS
baseurl=file:///var/www/html/@REL@/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[lab-appstream]
name=Lab @REL@ AppStream
baseurl=file:///var/www/html/@REL@/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
restorecon -R /var/www/html
%end

reboot
KS_EOF
}

ks_workstation() {
cat <<'KS_EOF'
eula --agreed

%packages
@^graphical-server-environment
ansible-core
rhel-system-roles
git
python3
vim-enhanced
bash-completion
tar
%end

%post --log=/root/ks-post-workstation.log
systemctl set-default graphical.target
cat > /home/student/.vimrc <<'EOF'
autocmd FileType yaml setlocal autoindent expandtab tabstop=2 shiftwidth=2 softtabstop=2 cursorcolumn
EOF
chown student:student /home/student/.vimrc
%end

reboot --eject
KS_EOF
}

ks_node() {
cat <<'KS_EOF'
user --name=devops --password=redhat --plaintext

%packages
@^minimal-environment
python3
vim-enhanced
bash-completion
tar
%end

%post --log=/root/ks-post-node.log
echo 'devops ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/devops
chmod 0440 /etc/sudoers.d/devops
install -d -m 700 -o devops -g devops /home/devops/.ssh
echo '@PUBKEY@' > /home/devops/.ssh/authorized_keys
chown devops:devops /home/devops/.ssh/authorized_keys
chmod 600 /home/devops/.ssh/authorized_keys
restorecon -R /home/devops/.ssh
%end

%post --nochroot --log=/mnt/sysimage/root/ks-post-vdb.log
# The course names the spare data disk /dev/vdb. On hypervisors without
# virtio disks it appears as sdb or nvme0n2, so add a stable /dev/vdb link.
sys=$(sed -n 's/^ignoredisk --only-use=//p' /tmp/disk.ks)
for d in $(lsblk -dnpo NAME,TYPE | awk '$2=="disk"{print $1}'); do
  n=${d#/dev/}
  case "$n" in zram*|loop*) continue ;; esac
  [ "$n" = "$sys" ] && continue
  [ "$n" = "vdb" ] && break
  idp=$(udevadm info --query=property --name="$d" | sed -n 's/^ID_PATH=//p')
  if [ -n "$idp" ]; then
    echo "SUBSYSTEM==\"block\", ENV{DEVTYPE}==\"disk\", ENV{ID_PATH}==\"$idp\", SYMLINK+=\"vdb\"" \
      > /mnt/sysimage/etc/udev/rules.d/90-lab-vdb.rules
    echo "Data disk $n will also appear as /dev/vdb"
  fi
  break
done
%end

reboot --eject
KS_EOF
}

render_ks() {
  local name=$1 role=$2 out="$WEB/ks/$1.ks"
  {
    ks_header
    case $role in
      utility)     ks_common_post; ks_utility ;;
      workstation) ks_workstation; ks_common_post; ks_remote_repo ;;
      node)        ks_node; ks_common_post; ks_remote_repo ;;
    esac
  } | sed -e "s|@FQDN@|${name}.${DOMAIN}|g" \
          -e "s|@IP@|${NODE_IP[$name]}|g" \
          -e "s|@LAB_MASK@|${LAB_MASK}|g" \
          -e "s|@BASTION_IP@|${BASTION_IP}|g" \
          -e "s|@DOMAIN@|${DOMAIN}|g" \
          -e "s|@REL@|${REL}|g" \
          -e "s|@PUBKEY@|${PUBKEY}|g" > "$out"
  echo "  $out"
}

publish_kickstarts() {
  log "Kickstart files"
  mkdir -p "$WEB/ks" "$WEB/scripts"
  render_ks utility utility
  render_ks workstation workstation
  local s
  for s in servera serverb serverc serverd; do render_ks "$s" node; done
}

# ---------------------------------------------------------------------------
# Setup scripts that other VMs download from bastion after installation.
# ---------------------------------------------------------------------------
publish_utility_script() {
cat > "$WEB/scripts/utility_setup.sh" <<'SCRIPT_EOF'
#!/usr/bin/env bash
# utility_setup.sh: content repositories, container registry, Git server.
# Run on utility:
#   curl -sO http://bastion.lab.example.com/lab/scripts/utility_setup.sh && sudo bash utility_setup.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
. /etc/os-release
REL=rhel${VERSION_ID%%.*}
WEBROOT=/var/www/html
log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

log "Content repositories at http://content.example.com/$REL"
if [[ ! -f $WEBROOT/$REL/.treeinfo ]]; then
  mkdir -p /mnt/dvd "$WEBROOT/$REL"
  for dev in /dev/sr0 /dev/sr1 /dev/cdrom; do
    [[ -b $dev ]] || continue
    mount -o ro "$dev" /mnt/dvd 2>/dev/null || continue
    if [[ -f /mnt/dvd/.treeinfo ]]; then
      cp -a /mnt/dvd/. "$WEBROOT/$REL/"
      umount /mnt/dvd
      break
    fi
    umount /mnt/dvd
  done
fi
[[ -f $WEBROOT/$REL/.treeinfo ]] || { echo "Attach the RHEL DVD ISO to utility, then run this script again."; exit 1; }
mkdir -p "$WEBROOT/materials/collections"
restorecon -R "$WEBROOT"

log "Packages and firewall"
dnf -y install httpd podman skopeo
systemctl enable --now httpd
firewall-cmd -q --permanent --add-service=http
firewall-cmd -q --permanent --add-port=5000/tcp
firewall-cmd -q --permanent --add-port=3000/tcp
firewall-cmd -q --reload

log "Container registry on port 5000"
mkdir -p /srv/registry /etc/containers/systemd
cat > /etc/containers/systemd/registry.container <<'EOF'
[Unit]
Description=Lab container registry on port 5000

[Container]
Image=docker.io/library/registry:2
ContainerName=registry
PublishPort=5000:5000
Volume=/srv/registry:/var/lib/registry:Z

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
EOF

log "Gitea Git server on port 3000"
mkdir -p /srv/gitea
cat > /etc/containers/systemd/gitea.container <<'EOF'
[Unit]
Description=Lab Gitea server on port 3000

[Container]
Image=docker.io/gitea/gitea:latest
ContainerName=gitea
PublishPort=3000:3000
Volume=/srv/gitea:/data:Z
Environment=USER_UID=1000
Environment=USER_GID=1000
Environment=GITEA__database__DB_TYPE=sqlite3
Environment=GITEA__server__DOMAIN=utility.lab.example.com
Environment=GITEA__server__HTTP_PORT=3000
Environment=GITEA__server__ROOT_URL=http://utility.lab.example.com:3000/
Environment=GITEA__security__INSTALL_LOCK=true
Environment=GITEA__service__DISABLE_REGISTRATION=true

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

podman pull -q docker.io/library/registry:2 >/dev/null
podman pull -q docker.io/gitea/gitea:latest >/dev/null
systemctl daemon-reload
systemctl restart registry gitea

for _ in $(seq 1 30); do
  curl -sf http://localhost:3000/api/v1/version >/dev/null && break
  sleep 5
done
if ! podman exec -u git gitea gitea admin user list | awk '{print $2}' | grep -qx student; then
  podman exec -u git gitea gitea admin user create --username student \
    --password 'Student@123' --email student@lab.example.com --admin --must-change-password=false
fi

log "Checks"
curl -s -o /dev/null -w 'content repo   %{http_code}\n' "http://localhost/$REL/.treeinfo"
curl -s -o /dev/null -w 'registry       %{http_code}\n' http://localhost:5000/v2/_catalog
curl -s -o /dev/null -w 'gitea          %{http_code}\n' http://localhost:3000/api/v1/version
echo "All three must show 200."
SCRIPT_EOF
chmod 0644 "$WEB/scripts/utility_setup.sh"
echo "  $WEB/scripts/utility_setup.sh"
}

publish_workstation_script() {
cat > "$WEB/scripts/workstation_setup.sh" <<'SCRIPT_EOF'
#!/usr/bin/env bash
# workstation_setup.sh: lab key, container tools, Ansible development tools, VS Code.
# Run on workstation as student:
#   curl -sO http://bastion.lab.example.com/lab/scripts/workstation_setup.sh && bash workstation_setup.sh
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as student, not as root"; exit 1; }
log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
HOSTS="bastion utility servera serverb serverc serverd"

log "Lab SSH key from bastion (enter the student password on bastion if asked: student)"
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  scp -o StrictHostKeyChecking=accept-new "student@bastion.lab.example.com:.ssh/id_ed25519*" ~/.ssh/
fi
chmod 600 ~/.ssh/id_ed25519
touch ~/.ssh/known_hosts
for h in $HOSTS; do
  ssh-keygen -R "$h" >/dev/null 2>&1 || true
  ssh-keygen -R "$h.lab.example.com" >/dev/null 2>&1 || true
done
for h in $HOSTS; do ssh-keyscan -t ed25519 "$h" "$h.lab.example.com" 2>/dev/null; done >> ~/.ssh/known_hosts

log "Container tools and registry trust (sudo password: student)"
sudo dnf -y install podman skopeo git
sudo dnf -y install python3.11 python3.11-pip || true
sudo tee /etc/containers/registries.conf.d/50-lab-registry.conf >/dev/null <<'EOF'
[[registry]]
location = "utility.lab.example.com:5000"
insecure = true
EOF

log "Ansible development tools in ~/.local/share/ansible-dev-tools"
PY=$(command -v python3.11 || command -v python3)
if [[ ! -x ~/.local/share/ansible-dev-tools/bin/ansible-navigator ]]; then
  "$PY" -m venv ~/.local/share/ansible-dev-tools
  ~/.local/share/ansible-dev-tools/bin/pip install -q --upgrade pip
  ~/.local/share/ansible-dev-tools/bin/pip install -q ansible-navigator ansible-lint ansible-builder podman-compose
fi
mkdir -p ~/.local/bin
for t in ansible-navigator ansible-lint ansible-builder podman-compose; do
  ln -sf ~/.local/share/ansible-dev-tools/bin/$t ~/.local/bin/$t
done

log "Visual Studio Code and extensions"
if ! command -v code >/dev/null; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  sudo dnf -y install code
fi
code --install-extension redhat.ansible >/dev/null
code --install-extension ms-vscode-remote.remote-containers >/dev/null

log "Checks"
for h in servera serverb serverc serverd; do
  ssh -n -o BatchMode=yes devops@$h.lab.example.com 'echo "$(hostname) sudo:$(sudo -n id -un)"'
done
~/.local/bin/ansible-navigator --version
ansible --version | head -1
code --list-extensions
echo
echo "Open a new terminal so ~/.local/bin is on your PATH."
SCRIPT_EOF
chmod 0644 "$WEB/scripts/workstation_setup.sh"
echo "  $WEB/scripts/workstation_setup.sh"
}

configure_web() {
  log "Web server for Kickstart files and scripts"
  systemctl enable --now httpd >/dev/null 2>&1
  restorecon -R /var/www/html
}

finalize_repos() {
  # When the DVD was the temporary package source, switch bastion to
  # content.example.com (served by utility) like every other lab VM.
  [[ -f /etc/yum.repos.d/lab-dvd.repo ]] || return 0
  rm -f /etc/yum.repos.d/lab-dvd.repo
  umount /mnt/dvd 2>/dev/null || true
  cat > /etc/yum.repos.d/lab.repo <<EOF
[lab-baseos]
name=Lab ${REL} BaseOS
baseurl=http://content.example.com/${REL}/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[lab-appstream]
name=Lab ${REL} AppStream
baseurl=http://content.example.com/${REL}/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
}

summary() {
  log "Bastion ready"
  cat <<EOF
Lab network     : ${LAB_NET}.0/${LAB_PREFIX}   gateway, DNS, NTP: ${BASTION_IP}
Install DHCP    : ${DHCP_START} to ${DHCP_END} (installer only; installed VMs use static addresses)
Kickstart files : http://${BASTION_IP}/lab/ks/NAME.ks
Setup scripts   : http://${BASTION_IP}/lab/scripts/

Boot each VM from the RHEL DVD and add to the kernel command line:
    inst.ks=http://${BASTION_IP}/lab/ks/NAME.ks ip=dhcp

Build order: utility, then workstation, servera, serverb, serverc, serverd.
EOF
}

# ---------------------------------------------------------------------------
main() {
  detect_release
  if [[ -n $RENDER_ONLY ]]; then
    PUBKEY="ssh-ed25519 AAAATESTKEY rh294-lab"
    mkdir -p "$WEB/ks" "$WEB/scripts"
    publish_kickstarts
    publish_utility_script
    publish_workstation_script
    return
  fi
  [[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"
  setup_dvd_repo
  install_packages
  configure_network
  configure_firewall
  configure_dns_dhcp
  configure_ntp
  create_lab_key
  configure_web
  publish_kickstarts
  publish_utility_script
  publish_workstation_script
  restorecon -R /var/www/html
  finalize_repos
  summary
}

main "$@"
