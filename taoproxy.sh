#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Hàm random password
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Random 4 block cuối
gen64() {
    printf "$1:%x:%x:%x:%x\n" $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536))
}

# Cài đặt 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Tạo file cấu hình 3proxy
gen_3proxy() {
    cat <<EOF
daemon
maxconn 4000
nserver 1.1.1.1
nserver 8.8.8.8
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Tạo danh sách proxy
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Sinh dữ liệu cho proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "user$port/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Cấu hình ifconfig
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

####### Bắt đầu chạy

echo "🔧 Installing apps..."

WORKDIR="/home/bkns"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

install_3proxy

# Lấy IPv4
IP4=$(curl -4 -s icanhazip.com)

# Prefix IPv6 – bạn đặt sẵn ở đây
IP6="2600:1900:4001:52d"

# Cổng từ 22000–22700 (tạo 701 proxy)
FIRST_PORT=22000
LAST_PORT=22700

echo "IPv4: $IP4 — IPv6 Prefix: $IP6"

# Tạo file dữ liệu
gen_data > $WORKDIR/data.txt
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.d/rc.local

# Tạo file cấu hình proxy
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# Thêm vào rc.local để tự khởi động
cat >> /etc/rc.d/rc.local <<EOF
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

# Khởi động ngay
bash /etc/rc.local

# Xuất file proxy.txt (định dạng IP:Port:User:Pass)
gen_proxy_file_for_user

# Xoá tạm
rm -rf /root/3proxy-0.8.13

echo "✅ Hoàn tất! Proxy đã chạy, file: /home/bkns/proxy.txt"
