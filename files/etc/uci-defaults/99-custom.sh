#!/bin/sh
# 仅首次运行 Wrt 时执行以下脚本，重启后消失

LOGFILE="/tmp/uci-defaults-log.txt"

echo "========================================" >> "$LOGFILE"
echo "Starting 99-custom.sh at $(date)" >> "$LOGFILE"
echo "========================================" >> "$LOGFILE"

# =========================================================
# 基础设置
# =========================================================

# 通用匹配 name='wan' 的防火墙区域 (兼容匿名 zone[x] 与具名 zone)
wan_zone=$(uci show firewall | awk -F '[.=]' '/^firewall\.[^.]+\.name=.wan.$/ {print $2; exit}')
if [ -n "$wan_zone" ]; then
    uci -q set "firewall.$wan_zone.input=ACCEPT"
else
    # 兜底：如果找不到 name='wan' 的 zone，退回索引 1
    uci -q set firewall.@zone[1].input='ACCEPT'
fi

uci -q add dhcp domain
uci -q set "dhcp.@domain[-1].name=time.android.com"
uci -q set "dhcp.@domain[-1].ip=203.107.6.88"
uci -q set system.@system[0].hostname='WRTVERSIONINFO'
uci -q set system.@system[0].timezone='CST-8'
uci -q set system.@system[0].zonename='Asia/Taipei'

uci -q set luci.main.lang='zh_cn'


# =========================================================
# 计算物理以太网接口数量
# =========================================================

ifnames=""

for iface in /sys/class/net/*; do
    [ -e "$iface" ] || continue

    iface_name="${iface##*/}"

    # 必须存在 device，且排除 lo/bridge/wireless
    if [ -e "$iface/device" ] && \
       [ "$iface_name" != "lo" ] && \
       ! echo "$iface_name" | grep -qE '^br-' && \
       [ ! -d "$iface/wireless" ] && \
       [ ! -d "$iface/phy80211" ]; then

        ifnames="${ifnames:+$ifnames }$iface_name"
    fi
done

# 将接口列表转换成位置参数
set -- $ifnames
count=$#


# =========================================================
# 网卡检测日志
# =========================================================

echo "Detected physical Ethernet interfaces: $ifnames" >> "$LOGFILE"
echo "Ethernet interface count: $count" >> "$LOGFILE"


# =========================================================
# 网络设置
# =========================================================

if [ "$count" -eq 0 ]; then

    # -----------------------------------------------------
    # 未检测到物理网卡
    # -----------------------------------------------------

    echo "ERROR: No physical Ethernet interface detected!" >> "$LOGFILE"

elif [ "$count" -eq 1 ]; then

    # -----------------------------------------------------
    # 单网口设备 (旁路由 / NAS 模式)
    # -----------------------------------------------------

    echo "Single Ethernet interface detected. Configuring LAN as DHCP." >> "$LOGFILE"
    uci -q set network.lan.proto='dhcp'
    uci -q delete network.lan.ipaddr
    uci -q delete network.lan.netmask
    uci -q delete network.lan.gateway
    uci -q delete network.lan.dns

elif [ "$count" -gt 1 ]; then

    # -----------------------------------------------------
    # 多网口设备 (主路由模式)
    # -----------------------------------------------------

    wan_ifname="$1"
    shift
    lan_ifnames="$*"

    echo "Multiple Ethernet interfaces detected." >> "$LOGFILE"
    echo "WAN interface: $wan_ifname" >> "$LOGFILE"
    echo "LAN interfaces: $lan_ifnames" >> "$LOGFILE"

    # WAN / WAN6 配置
    uci -q set network.wan=interface
    uci -q set network.wan.device="$wan_ifname"
    uci -q set network.wan.proto='dhcp'
    uci -q set network.wan6=interface
    uci -q set network.wan6.device="$wan_ifname"
    uci -q set network.wan6.proto='dhcpv6'

    # -----------------------------------------------------
    # 通用型 br-lan device 查找 (兼容匿名/具名 section)
    # 匹配 network.<section>.name='br-lan'
    # -----------------------------------------------------

    section=$(uci show network | awk -F '[.=]' '/^network\.[^.]+\.name=['"'"'"]br-lan['"'"'"]$/ {print $2; exit}')

    if [ -n "$section" ]; then

        uci -q delete "network.$section.ports"
        for port in $lan_ifnames; do
            uci -q add_list "network.$section.ports"="$port"
        done
        echo "br-lan ports updated: $lan_ifnames" >> "$LOGFILE"

    else

        first_lan_port=$(echo "$lan_ifnames" | awk '{print $1}')
        uci -q set network.lan.device="$first_lan_port"
        echo "WARNING: Cannot find 'br-lan' device. Fallback to setting network.lan.device='$first_lan_port'." >> "$LOGFILE"

    fi

    # LAN 配置静态 IP
    uci -q set network.lan.proto='static'
    uci -q set network.lan.ipaddr='__IPADDR__'
    uci -q set network.lan.netmask='255.255.255.0'

fi


# =========================================================
# SSH / Web 管理
# =========================================================

uci -q delete ttyd.@ttyd[0].interface
uci -q set dropbear.@dropbear[0].Interface=''


# =========================================================
# 保存配置
# =========================================================

uci commit system
uci commit luci
uci commit firewall
uci commit dhcp
uci commit network
uci commit dropbear
uci -q commit ttyd


# =========================================================
# 清理并还原 Banner 与描述信息
# =========================================================

if [ -f /etc/banner1/banner ]; then
    cp -f /etc/banner1/banner /etc/
fi

if [ -d /etc/banner1 ]; then
    rm -rf /etc/banner1
fi

FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="WRTVERSIONINFO VERXXXX"

if [ -f "$FILE_PATH" ]; then
    sed -i \
        "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" \
        "$FILE_PATH"
fi


# =========================================================
# 完成
# =========================================================

echo "========================================" >> "$LOGFILE"
echo "99-custom.sh completed at $(date)" >> "$LOGFILE"
echo "========================================" >> "$LOGFILE"

exit 0
