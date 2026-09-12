#!/bin/bash
# 25.12.x 第三方插件配置 (APK 格式) - aarch64_cortex-a53 专用
# 启用第三方插件时取消对应注释

#Others - DO NOT REMOVE
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-cpufreq luci-i18n-cpufreq-zh-cn"

# Adguardhome广告拦截 (adguardhome)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES adguardhome luci-app-adguardhome luci-i18n-adguardhome-zh-cn"

# Amlogic晶晨宝盒 (amlogic)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# Argon主题 (argon)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn"

# Aurora主题 (aurora)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-aurora-config luci-theme-aurora luci-i18n-aurora-config-zh-cn"

# Bandix-plus网络流量监控 (bandix-plus)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES bandix-plus luci-app-bandix-plus luci-i18n-bandix-plus-zh-cn"

# Bandix网络流量监控 (bandix)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES bandix luci-app-bandix luci-i18n-bandix-zh-cn"

# Clashoo代理面板 (clashoo)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES clashoo luci-app-clashoo luci-i18n-clashoo-zh-cn"

# Cpu状态 (cpu-status)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-cpu-status"

# Daede代理面板 (daede)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES dae daed luci-app-daede"

# Ddns 动态DNS (ddns)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES ddns-scripts-cloudflare luci-app-ddns luci-i18n-ddns-zh-cn"

# Easymesh无线组网(easymesh)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-easymesh luci-i18n-easymesh-zh-cn"

# Lucky内网穿透 (lucky)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES lucky luci-app-lucky luci-i18n-lucky-zh-cn"

# MosDNS转发器 (mosDNS)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES mosdns luci-app-mosdns luci-i18n-mosdns-zh-cn"

# Netspeedtest网速测试 (netspeedtest)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-netspeedtest luci-i18n-netspeedtest-zh-cn"

# Netwizard网络设置向导 (netwizard)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-netwizard luci-i18n-netwizard-zh-cn"

# Nikki代理面板 (nikki)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES nikki luci-app-nikki luci-i18n-nikki-zh-cn"

# Openclash代理面板 (openclash)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-openclash"

# Partexp分区扩容 (partexp)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-partexp luci-i18n-partexp-zh-cn"

# Passwall代理面板 (passwall)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn"
CUSTOM_PACKAGES="$CUSTOM_PACKAGES sing-box chinadns-ng geoview shadowsocksr-libev-ssr-local shadowsocksr-libev-ssr-redir"

# Poweroffdevice关机 (poweroffdevice)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-poweroffdevice luci-i18n-poweroffdevice-zh-cn"

# Rtp2httpd流媒体转发 (rtp2httpd)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES rtp2httpd luci-app-rtp2httpd luci-i18n-rtp2httpd-zh-cn"

# Run插件安装工具 (run)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-run"

# Samb文件共享 (samba4)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-samba4 luci-i18n-samba4-zh-cn"

# TailscaleVPN代理 (tailscale)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES tailscale luci-app-tailscale luci-i18n-tailscale-zh-cn"

# Turboacc网络加速(turboacc)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-turboacc luci-i18n-turboacc-zh-cn"

# Taskplan定时任务 (taskplan)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-taskplan luci-i18n-taskplan-zh-cn"

# Timecontrol上网时间控制 (timecontrol)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-timecontrol luci-i18n-timecontrol-zh-cn"

# Watchdog看门狗 (watchdog)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES watchdog luci-app-watchdog luci-i18n-watchdog-zh-cn"

# Wireguard VPN控制面板 (wireguard)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-proto-wireguard qrencode"
