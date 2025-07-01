#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Tạo random chuỗi ngắn
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Sinh 4 cụm hex IPv6 random
gen_ipv6() {
    printf "%x:%x:%x:%x" $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536))
}

# Cài đặt 3proxy
install_3proxy() {
    echo "📦 Installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd "$WORKDIR"
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

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' "$WORKDATA")

$(awk -F "/" '{print "auth strong\nallow " $1 "\nproxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\nflush\n"}' "$WORKDATA")
EOF
}

# Sinh dữ liệu user/pass, IP, port, IPv6
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        USER="user$port"
        PASS=$(random)
        IPV6="$IP6_PREFIX:$(gen_ipv6)"
        echo "$USER/$PASS/$IP4/$port/$IPV6"
    done
}

# Add IPv6 vào interface
gen_ifconfig() {
    awk -F "/" '{print "ip -6 addr add "$5"/64 dev eth0"}' "$WORKDATA"
}

# Xuất proxy ra file
gen_proxy_file_for_user() {
    awk -F "/" '{print $3":"$4":"$1":"$2}' "$WORKDATA" > proxy.txt
}

# ───── MAIN ─────
echo "📂 Working folder = /home/proxyv6"
WORKDIR="/home/proxyv6"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

IP4=$(curl -4 -s icanhazip.com)
IP6_PREFIX="2600:1900:4001:52d" # Prefix IPv6 VPS của bạn

FIRST_PORT=22000
LAST_PORT=22700

install_3proxy
gen_data > "$WORKDATA"
gen_ifconfig > "$WORKDIR/boot_ifconfig.sh"
chmod +x "$WORKDIR/boot_ifconfig.sh"

# Tạo file cấu hình 3proxy
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# Thêm khởi động 3proxy vào rc.local
cat >> /etc/rc.d/rc.local <<EOF
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

# Khởi chạy ngay
bash /etc/rc.d/rc.local

# Xuất danh sách proxy
gen_proxy_file_for_user

echo "✅ Đã tạo proxy xong! Xem file proxy.txt"
