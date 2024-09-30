#!/bin/bash

# Zaman damgası
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

# Sunucu bilgileri
hostname=$(hostname)  # Sunucu ismi
fqdn=$(hostname -f)   # Tam nitelikli DNS ismi (FQDN)
ip_address=$(hostname -I | xargs)  # IP adresi (xargs boşlukları temizler)

# Sistemin dağıtımını öğren (Ubuntu mu Debian mı Red Hat mı?)
distro=$(cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '"' || echo "Unknown")

# Sürüm bilgisini al
if [[ "$distro" == "Ubuntu" ]]; then
    version=$(lsb_release -rs)
elif [[ "$distro" == "Debian" ]]; then
    version=$(cat /etc/debian_version | cut -d '.' -f1)
elif [[ "$distro" == "rhel" || "$distro" == "centos" ]]; then
    version=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\..*/\1/')
else
    version="Unknown"
fi

# Sunucu ne zamandır ayakta (uptime)
uptime_info=$(uptime -p)
uptime_since=$(uptime -s)