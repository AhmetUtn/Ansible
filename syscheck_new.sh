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

# Yük ortalamaları (1, 5, 15 dakika)
load_averages=$(uptime | awk -F'load average:' '{print $2}' | xargs)
load_1_min=$(echo $load_averages | awk '{print $1}' | sed 's/,//g')
load_5_min=$(echo $load_averages | awk '{print $2}' | sed 's/,//g')
load_15_min=$(echo $load_averages | awk '{print $3}' | sed 's/,//g')


# Recommendations dizisini başlat
declare -a recommendations

# needrestart ile yeniden başlatma gereksinimi kontrolü (Red Hat için uygun alternatif eklenmiştir)
restart_needed=false  # Varsayılan olarak false ayarlıyoruz
needrestart_installed=true  # needrestart yüklü değilse bu false olacak

if [[ "$distro" == "Ubuntu" || "$distro" == "Debian" ]]; then
    if ! command -v needrestart &> /dev/null; then
        needrestart_installed=false
        recommendations+=("recommendation,high,package,\"needrestart yüklü değil! Kernel güncellemeleri sonrası yeniden başlatma gereksinimlerini kontrol etmek için 'sudo apt install needrestart' komutu ile yükleyin.\"")
    else
        kernel_check=$(sudo DEBIAN_FRONTEND=noninteractive needrestart -k -b -p 2>/dev/null)
        if echo "$kernel_check" | grep -q "Kernel"; then
            restart_needed=true
        fi
    fi
elif [[ "$distro" == "rhel" || "$distro" == "centos" ]]; then
    if ! command -v needs-restarting &> /dev/null; then
        recommendations+=("recommendation,high,package,\"needs-restarting komutu yüklü değil! Kernel güncellemeleri sonrası yeniden başlatma gereksinimlerini kontrol etmek için 'sudo yum install yum-utils' komutu ile yükleyin.\"")
    else
        # Kernel ve servis durumlarını kontrol et
        kernel_check=$(sudo needs-restarting -r 2>/dev/null)
        if [[ "$kernel_check" == *"Reboot is required"* ]]; then
            restart_needed=true
        fi
    fi
fi

# Ubuntu ve Debian sürümüne göre yaşam döngüsü bilgileri
check_version () {
  case $1 in
    "18.04")
      echo "Ubuntu 18.04 LTS reached end of standard support in April 2023. You are now in Extended Security Maintenance (ESM) until April 2028."
      ;;
    "20.04")
      echo "Ubuntu 20.04 LTS is supported until April 2025. No urgent upgrade required, but be aware of ESM options after 2025."
      ;;
    "22.04")
      echo "Ubuntu 22.04 LTS is fully supported until April 2027. No upgrade is necessary at this time."
      ;;
    "11")
      echo "Debian 11 (Bullseye) is supported until June 2026."
      ;;
    "12")
      echo "Debian 12 (Bookworm) is supported until June 2028."
      ;;
    "8" | "7")
      echo "Your Red Hat/CentOS version is no longer supported. Please upgrade to the latest version."
      ;;
    "9")
      echo "Red Hat 9 is fully supported. No upgrade necessary at this time."
      ;;
    *)
      echo "Your system version is no longer supported. Please upgrade to the latest version."
      ;;
  esac
}

# Sistemin yaşam döngüsü durumu
support_message=$(check_version "$version")

# Disk Kullanım Kontrolü
while IFS= read -r line; do
    line=$(echo "$line" )
    recommendations+=("$line")
done < <(df -h --output=pcent,target | grep -v "Use%" | grep -Ev '^tmpfs|^devtmpfs|/snap|^sr0' | awk '{gsub("%", "", $1); if ($1+0 > 80) print "recommendation,high,disk,\"Disk kullanım oranı "$1"% (mount point: "$2"). Disk temizliği veya kapasite artırımı önerilir.\""}')


# CPU ve Bellek için geçmişe yönelik kontrol (sar komutu varsa)
if command -v sar &> /dev/null
then
    # CPU Kullanımı (geçmiş veri)
    cpu_usage=$(sar -u 1 1 | grep "Average" | awk '{print 100 - $NF}')

    # Bellek Kullanımı (geçmiş veri)
    memory_used_percentage=$(sar -r 1 1 | grep "Average" | awk '{print $5}')

    # Swap Kullanımı (geçmiş veri)
    swap_used_percentage=$(sar -S 1 1 | grep "Average" | awk '{print $5}')
else
    # Eğer sar yüklenmemişse öneride bulun
    recommendations+=("recommendation,high,package,\"Sysstat paketi (sar komutu) yüklü değil! CPU bellek ve diğer sistem kaynaklarını izlemek için gereklidir. 'sudo apt install sysstat' komutu ile yükleyin.\"")
    # CPU ve bellek için anlık veri
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    
    # Bellek Yüzde Kullanımı (vmstat kullanarak)
    memory_used_percentage=$(vmstat -s | grep "used memory" | awk '{print $1}')
    memory_total=$(vmstat -s | grep "total memory" | awk '{print $1}')
    memory_used_percentage=$(awk "BEGIN {print ($memory_used_percentage / $memory_total) * 100}")

    # Swap Yüzde Kullanımı (vmstat kullanarak)
    swap_used=$(vmstat -s | grep "used swap" | awk '{print $1}')
    swap_total=$(vmstat -s | grep "total swap" | awk '{print $1}')
    if [[ "$swap_total" != "0" ]]; then
        swap_usage_percentage=$(awk "BEGIN {print ($swap_used / $swap_total) * 100}")
    else
        swap_usage_percentage=0
    fi
fi

cpu_usage=${cpu_usage:-0}
memory_used_percentage=${memory_used_percentage:-0}
swap_usage_percentage=${swap_usage_percentage:-0}

if [ ! -z "$cpu_usage" ] && awk "BEGIN {exit ($cpu_usage > 80 ? 0 : 1)}"; then
    recommendations+=("recommendation,medium,cpu,\"CPU kullanımı yüksek! İşlemci yükünü azaltmak veya sistem optimizasyonu yapmak önerilir.\"")
fi

if [ ! -z "$memory_used_percentage" ] && awk "BEGIN {exit ($memory_used_percentage > 80 ? 0 : 1)}"; then
    recommendations+=("recommendation,medium,memory,\"Bellek kullanımı yüksek! Bellek kullanımını optimize etmek veya daha fazla RAM eklemek önerilir.\"")
fi 

if [ ! -z "$swap_usage_percentage" ] && awk "BEGIN {exit ($swap_usage_percentage > 70 ? 0 : 1)}"; then
    recommendations+=("recommendation,medium,swap,\"Swap kullanımı yüksek! Swap kullanımını optimize edin veya daha fazla RAM eklemeyi düşünün.\"")
fi

# Paket ve güncelleme kontrolleri
updates=0
package_updates=""
security_updates_list=""
if [[ "$distro" == "Ubuntu" || "$distro" == "Debian" ]]; then
    updates=$(DEBIAN_FRONTEND=noninteractive apt list --upgradable 2>/dev/null | grep -v 'Listing...' | wc -l || echo "APT list check failed")
    package_updates=$(apt list --upgradable 2>/dev/null | grep -v 'Listing...')
    security_updates_list=$(apt list --upgradable 2>/dev/null | grep "security")
elif [[ "$distro" == "rhel" || "$distro" == "centos" ]]; then
    updates=$(yum check-update | grep -v "^$" | wc -l)
    package_updates=$(yum check-update)
    security_updates_list=$(yum list-security --security)
fi

if [ "$updates" -gt 0 ]; then
    recommendations+=("recommendation,medium,maintenance,\"$updates adet paket güncellemeye hazır. Sisteminizi güncellemek için ilgili komutları çalıştırın.\"")
fi

if [ ! -z "$security_updates_list" ]; then
    recommendations+=("recommendation,high,security,\"Güvenlik güncellemeleri mevcut! Güncellemeleri yapmanız önerilir.\"")
fi

# SSH güvenlik kontrolü
ssh_config_file="/etc/ssh/sshd_config"
permit_root_login=$(grep -Ei '^PermitRootLogin' "$ssh_config_file" | awk '{print $2}' || echo "Not set")
password_authentication=$(grep -Ei '^PasswordAuthentication' "$ssh_config_file" | awk '{print $2}' || echo "Not set")

if [ "$permit_root_login" = "yes" ]; then
    recommendations+=("recommendation,high,security,\"PermitRootLogin etkin durumda! Root erişimini devre dışı bırakmanız güvenliğiniz için önerilir.\"")
fi

if [ "$password_authentication" = "yes" ]; then
    recommendations+=("recommendation,high,security,\"PasswordAuthentication etkin! SSH anahtarı ile oturum açmayı tercih edin.\"")
fi

# NTP Senkronizasyonu Kontrolü
ntp_status=$(timedatectl show | grep "NTPSynchronized" | awk -F'=' '{print $2}' || echo "NTP check failed")

# NTP kullanımı yoksa öneri ekle
if [ "$ntp_status" != "yes" ]; then
    recommendations+=("recommendation,high,time_synchronization,\"NTP senkronizasyonu aktif değil! Sunucu zamanı doğru senkronize edilmelidir. 'timedatectl set-ntp true' komutu ile aktif edin.\"")
fi

# Kernel Versiyonu ve Güvenlik Güncellemeleri
kernel_version=$(uname -r)
security_updates=$(yum list-security --security 2>/dev/null | wc -l || echo "Security updates check failed")
if [ "$security_updates" -gt 0 ]; then
    security_update_info="Security updates available."
else
    security_update_info="No security updates available."
fi

# Log Dosyası Analizi (Son 15 Gün)
start_date=$(date --date="15 days ago" +"%Y-%m-%d")
end_date=$(date +"%Y-%m-%d")

log_files=(
    "/var/log/messages"         # Genel sistem mesajları
    "/var/log/secure"           # Güvenlik ve kimlik doğrulama ile ilgili kayıtlar
    "/var/log/maillog"          # E-posta sunucusu logları
    "/var/log/cron"             # Cron işlerinin logları
    "/var/log/boot.log"         # Sistem başlangıç logları
    "/var/log/dmesg"            # Donanım bilgileri ve kernel mesajları
    "/var/log/audit/audit.log"  # Audit kayıtları (güvenlik için)
    "/var/log/httpd/access_log" # Apache erişim logları
    "/var/log/httpd/error_log"  # Apache hata logları
    "/var/log/yum.log"          # Yum paket yöneticisi logları
    "/var/log/syslog"
    "/var/log/auth.log"
    "/var/log/kern.log"
    "/var/log/dmesg"
    "/tmp/fake_syslog"
)

declare -A categories
categories=(
    ["Kritik"]="critical|kernel panic|out of memory"
    ["Hata"]="error|fail|denied"
    ["Uyarı"]="warning|deprecated"
    ["Disk Dolu"]="disk full|no space left on device"
    ["Bağımlılık Hataları"]="dependency|unmet dependencies"
    ["SSH Bağlantı Hataları"]="connection refused|permission denied|failed password"
)

declare -A suggestions
suggestions=(
    ["out of memory"]="Bellek yetersizliği sorunu. Daha fazla bellek ekleyin veya bellek kullanımını optimize edin."
    ["denied"]="İzin hatası. Dosya veya dizin izinlerini kontrol edin."
    ["fail"]="Başarısız işlem. Sistem bileşenlerini kontrol edin veya yeniden başlatmayı deneyin."
    ["kernel panic"]="Kernel çökmesi. Donanım uyumsuzluklarını kontrol edin, kernel güncellemelerini inceleyin."
    ["disk full"]="Disk dolu hatası. Disk temizliği yapın, gereksiz dosyaları silin veya disk alanını artırın."
    ["dependency"]="Paket bağımlılık hatası. Eksik bağımlılıkları çözmek için 'sudo apt-get install -f' komutunu kullanın."
    ["connection refused"]="SSH bağlantı hatası. SSH servisini kontrol edin, güvenlik duvarı ve izin ayarlarını gözden geçirin."
)

log_issues=()
log_lines=1000

for log_file in "${log_files[@]}"; do
    if [[ -f "$log_file" ]]; then
        log_content=$(tail -n "$log_lines" "$log_file")
        log_line_num=0

        while IFS= read -r line; do
            ((log_line_num++))

            line=$(echo "$line" | sed 's/,//g')

            # Log satırlarını kategorilere göre analiz edin
            for category in "${!categories[@]}"; do
                if echo "$line" | grep -Ei "${categories[$category]}" > /dev/null; then
                    count=$(echo "$log_content" | grep -Ei "${categories[$category]}" | wc -l)

                    # Öneriler ekleniyor
                    log_issues+=("log,$log_file,$category,$log_line_num,$line,$count,${suggestions[${categories[$category]}]}")
                fi
            done
        done <<< "$log_content"
    fi
done

load_1_min=${load_1_min:-0}
load_5_min=${load_5_min:-0}
load_15_min=${load_15_min:-0}
restart_needed=${restart_needed:-false}  # Boşsa false
needrestart_installed=${needrestart_installed:-false}  # Boşsa false
updates=${updates:-0}  # Boşsa 0

# Öneriler için ayrı bir dosyaya yazdırma
recommendations_output=$(cat <<EOF
$(IFS=$'\n'; echo "${recommendations[*]}")
EOF
)
echo "recommendation,priority,category,message" > /tmp/$(hostname -s)_recommendations.csv
echo "$recommendations_output" >> /tmp/$(hostname -s)_recommendations.csv

# Loglar için ayrı bir dosyaya yazdırma
log_issues_output=$(cat <<EOF
$(IFS=$'\n'; echo "${log_issues[*]}" | sed 's/,$//') 
EOF
)
echo "log,log_file,category,line_number,message,count" > /tmp/$(hostname -s)_log_issues.csv
echo "$log_issues_output" >> /tmp/$(hostname -s)_log_issues.csv

# JSON yapısı oluştur (Kategorilere göre yapılandırılmış)
csv_output=$(cat <<EOF
timestamp,hostname,fqdn,ip_address,distro,version,support_message,uptime_pretty,uptime_since,restart_needed,needrestart_installed,load_1_min,load_5_min,load_15_min,cpu_usage_percentage,memory_usage_percentage,swap_usage_percentage,packages_upgradable,package_details,security_updates,kernel_version,security_update_info,ntp_status
"$timestamp","$hostname","$fqdn","$ip_address","$distro","$version","$support_message","$uptime_info","$uptime_since",$restart_needed,$needrestart_installed,$load_1_min,$load_5_min,$load_15_min,"$cpu_usage","$memory_used_percentage","$swap_usage_percentage",$updates,"$(echo "$package_updates" | tr -d '\n')","$(echo "$security_updates_list" | tr -d '\n')","$kernel_version","$security_update_info","$ntp_status"
EOF
)

# CSV çıktıyı ekrana veya dosyaya yazdır
echo "$csv_output" > /tmp/$(hostname -s)_system_info.csv
