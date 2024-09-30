#!/bin/bash

# SSH Anahtarını oluşturma ve sunuculara dağıtma betiği

# 1. Kullanıcıdan SSH yorum bilgisini al
read -p "SSH anahtarına eklenecek yorum (örneğin: kullanici@domain.com): " SSH_COMMENT

# 2. SSH anahtarını oluştur
ssh-keygen -t rsa -b 4096 -C "$SSH_COMMENT" -f ~/.ssh/id_rsa -N ""

echo "SSH anahtarı oluşturuldu."

# 3. Kullanıcıdan sunucu IP adreslerini al (boşluk ile ayrılmış olarak)
read -p "SSH anahtarını dağıtmak istediğiniz sunucu IP adreslerini girin (örneğin: 192.168.1.100 192.168.1.101): " SERVER_IPS

# 4. Kullanıcıdan sunucuya bağlanmak için kullanılacak kullanıcı adını al
read -p "Sunuculara bağlanırken kullanılacak kullanıcı adı (örn: root, ahmet): " SSH_USER

# 5. Anahtarı sunuculara dağıtma işlemi
for server in $SERVER_IPS; do
    echo "SSH anahtarı $SSH_USER@$server adresine kopyalanıyor..."
    ssh-copy-id -i ~/.ssh/id_rsa.pub $SSH_USER@$server
done

echo "Anahtarlar başarıyla dağıtıldı!"
