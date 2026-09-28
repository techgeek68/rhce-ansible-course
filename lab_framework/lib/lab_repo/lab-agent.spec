Name:           lab-agent
Version:        1.0
Release:        1
Summary:        Reporting agent for the RH294 local lab
License:        MIT
BuildArch:      noarch

%description
Writes the time of its last run to /var/lib/lab-agent/last_run.
A systemd timer runs it every five minutes.

%install
mkdir -p %{buildroot}/usr/bin %{buildroot}/usr/lib/systemd/system %{buildroot}/var/lib/lab-agent
cat > %{buildroot}/usr/bin/lab-agent <<'EOS'
#!/bin/bash
date --iso-8601=seconds > /var/lib/lab-agent/last_run
EOS
chmod 0755 %{buildroot}/usr/bin/lab-agent
cat > %{buildroot}/usr/lib/systemd/system/lab-agent.service <<'EOS'
[Unit]
Description=Lab reporting agent

[Service]
Type=oneshot
ExecStart=/usr/bin/lab-agent
EOS
cat > %{buildroot}/usr/lib/systemd/system/lab-agent.timer <<'EOS'
[Unit]
Description=Run the lab reporting agent every five minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOS

%files
/usr/bin/lab-agent
/usr/lib/systemd/system/lab-agent.service
/usr/lib/systemd/system/lab-agent.timer
%dir /var/lib/lab-agent
