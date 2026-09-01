#!/bin/bash
# Wrt 25.12.x Airoha 构建脚本 (APK 格式)
# 在 imagebuilder 目录下运行

# --- 接收外部参数 ---
# 与 build25.sh 约定一致:$1=PROFILE, $2=ROOTFS_PARTSIZE
PROFILE=${1:-"gemtek_w1700k-ubi"}
INCLUDE_DOCKER=${INCLUDE_DOCKER:-"no"}

echo "Target Profile: $PROFILE"
echo "Include Docker: $INCLUDE_DOCKER"

# ============================================
# 步骤1: 加载第三方插件配置
# ============================================
CUSTOM_PACKAGES=""
source apk-custom-packages.sh

HAS_CUSTOM_PACKAGES="no"
if [ -n "$CUSTOM_PACKAGES" ]; then
    HAS_CUSTOM_PACKAGES="yes"
    echo "✅ 检测到第三方插件: $CUSTOM_PACKAGES"
fi

# 定义所需安装的包列表
PACKAGES=""

# [核心系统]
PACKAGES="$PACKAGES base-files uci ubus dropbear logd mtd bash htop curl wget ca-bundle ca-certificates"
PACKAGES="$PACKAGES -dnsmasq dnsmasq-full firewall4 nftables kmod-nft-offload fitblk"
PACKAGES="$PACKAGES ip-full ipset iw ppp ppp-mod-pppoe luci-proto-ppp luci-proto-ipv6"
PACKAGES="$PACKAGES -odhcpd odhcpd-ipv6only odhcp6c"
PACKAGES="$PACKAGES -wpad-basic-mbedtls -wpad-mbedtls wpad-openssl -libustream-mbedtls -libustream-wolfssl libustream-openssl"
# [无线驱动]
PACKAGES="$PACKAGES kmod-cfg80211 kmod-mac80211 kmod-mt76-connac kmod-mt76-core kmod-hwmon-nct7802 rtl826x-firmware"
PACKAGES="$PACKAGES airoha-en7581-mt7996-npu-firmware"
PACKAGES="$PACKAGES wireless-regdb"
PACKAGES="$PACKAGES kmod-mt7996-firmware kmod-mt7996-firmware-common kmod-mt7996e"

#[其它驱动]
PACKAGES="$PACKAGES kmod-phy-aquantia kmod-phy-realtek kmod-phylink kmod-sfp ethtool iperf3 kmod-thermal lm-sensors kmod-tcp-bbr kmod-nft-offload"

# [Web 界面]
PACKAGES="$PACKAGES luci luci-base luci-i18n-base-zh-cn luci-mod-admin-full luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-app-ttyd luci-i18n-ttyd-zh-cn"

# [功能插件]
PACKAGES="$PACKAGES luci-app-upnp luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-app-wol luci-i18n-wol-zh-cn"
PACKAGES="$PACKAGES luci-app-package-manager luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-app-irqbalance luci-i18n-irqbalance-zh-cn"

# [gemtek_w1700k-ubi插件]
if [ "$PROFILE" = "gemtek_w1700k-ubi" ]; then
    echo "🐳 Install gemtek_w1700k-ubi Luci"
    PACKAGES="$PACKAGES luci-app-airoha-npu luci-i18n-airoha-npu-zh-cn"
    PACKAGES="$PACKAGES luci-app-mlo luci-i18n-mlo-zh-cn"
    PACKAGES="$PACKAGES luci-app-airoha-fancontrol luci-i18n-airoha-fancontrol-zh-cn"
    PACKAGES="$PACKAGES luci-app-airoha-flowsense luci-i18n-airoha-flowsense-zh-cn"
fi

# ============================================
# 步骤2: 处理第三方插件(最佳努力,失败不阻断构建)
# ============================================
THIRD_PARTY_OK=0
if [ "$HAS_CUSTOM_PACKAGES" = "yes" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始处理第三方APK..."

    # 克隆 OpenWrt-App 仓库 (best-effort)
    echo "克隆 OpenWrt-App 仓库..."
    rm -rf /tmp/store-repo
    if git clone --depth=1 https://github.com/Arthur97172/OpenWrt-App.git /tmp/store-repo 2>/tmp/git-clone.log; then
        THIRD_PARTY_OK=1
    else
        echo "⚠️ git clone 失败(继续构建,不含第三方插件):"
        sed 's/^/    /' /tmp/git-clone.log
    fi
fi

if [ "$THIRD_PARTY_OK" = "1" ]; then
    # 创建临时目录存放第三方 APK
    mkdir -p thirdparty

    echo "复制第三方 APK 到 thirdparty/ 目录..."
    mkdir -p apk-merged thirdparty

    if [ -d /tmp/store-repo/apk/aarch64_cortex-a53 ]; then
        find /tmp/store-repo/apk/aarch64_cortex-a53 -name '*.apk' -exec cp -t apk-merged {} + 2>/dev/null || true
    fi

    # 2. 【新增】直接把本地 apps 目录下的 APK 复制到第三方合并目录
    if [ "$PROFILE" = "gemtek_w1700k-ubi" ]; then
        if [ -d "apps" ]; then
            cp -f apps/*.apk apk-merged/ 2>/dev/null || true
        elif [ -d "../apps" ]; then
            cp -f ../apps/*.apk apk-merged/ 2>/dev/null || true
        fi
    fi
    
    if [ -d apk-merged ] && [ -n "$(ls apk-merged/*.apk 2>/dev/null)" ]; then
        cp apk-merged/*.apk thirdparty/ 2>/dev/null
    else
        echo "⚠️ 未在仓库中找到 aarch64*/.apk,跳过第三方"
        THIRD_PARTY_OK=0
    fi

    APK_COUNT=$(find thirdparty -name '*.apk' 2>/dev/null | wc -l)
    echo "✅ 第三方目录现有 $APK_COUNT 个APK文件"
    if [ "$APK_COUNT" -eq 0 ]; then
        echo "⚪️ 未获取到任何第三方 apk,继续构建"
        THIRD_PARTY_OK=0
    fi
fi

# 若构建 cpufreq，则只复制 cpufreq 相关插件
if echo "$PACKAGES" | grep -q "luci-app-cpufreq"; then
    if [ -d "apps" ]; then
        cp -f apps/cpufreq*.apk apk-merged/ 2>/dev/null || true
        cp -f apps/luci-app-cpufreq*.apk apk-merged/ 2>/dev/null || true
        cp -f apps/luci-i18n-cpufreq-zh-cn*.apk apk-merged/ 2>/dev/null || true
    elif [ -d "../apps" ]; then
        cp -f ../apps/cpufreq*.apk apk-merged/ 2>/dev/null || true
        cp -f ../apps/luci-app-cpufreq*.apk apk-merged/ 2>/dev/null || true
        cp -f ../apps/luci-i18n-cpufreq-zh-cn*.apk apk-merged/ 2>/dev/null || true
    fi
    echo "✅ cpufreq 相关插件已复制完成！"
else
    echo "⚪️ 未选择 luci-app-cpufreq"
fi

if [ "$THIRD_PARTY_OK" = "1" ]; then
    echo "复制第三方 APK 到 imagebuilder/packages/ ..."
    mkdir -p packages

    # 排除已知不可用的 APK(glob),空就是不过滤
    SKIP_APKS=""

    APK_BIN="staging_dir/host/bin/apk"
    APK_KEYS_DIR="keys"
    APK_SIGN_KEY="$APK_KEYS_DIR/local-private-key.pem"
    if [ ! -s "$APK_SIGN_KEY" ]; then
        APK_SIGN_KEY="$APK_KEYS_DIR/build_key.apk.sec"
    fi

    echo "🔖 重命名 apk 为 canonical 名称(name-version.apk)..."
    canoned=0
    cached=0
    skipped=0
    for f in thirdparty/*.apk; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        skip=0
        for s in $SKIP_APKS; do
            case "$base" in $s) skip=1 ;; esac
        done
        if [ "$skip" = "1" ]; then
            echo "  ↷ 跳过: $base"
            continue
        fi
        canon_name=$("$APK_BIN" adbdump "$f" 2>/dev/null \
            | awk '/^  name:/ {name=$2} /^  version:/ {ver=$2; print name; print ver}' | head -2)
        canon_pkg=$(echo "$canon_name" | head -1)
        canon_ver=$(echo "$canon_name" | sed -n '2p')
        if [ -z "$canon_pkg" ] || [ -z "$canon_ver" ]; then
            echo "  ⚠️ 无法读 metadata(可能是损坏的 apk):$base — 跳过"
            continue
        fi
        target="$canon_pkg-$canon_ver.apk"
        if [ -f "packages/$target" ] && [ "packages/$target" -nt "$f" ]; then
            cached=$((cached+1))
            continue
        fi
        cp -f "$f" "packages/$target"
        canoned=$((canoned+1))
    done
    echo "📦 重命名 $canoned 新 apk,缓存 $cached 个,跳过 $skipped 个"
    PKG_IN_POOL=$(ls packages/*.apk 2>/dev/null | wc -l)
    echo "✅ 第三方 APK 已合并到 packages/ (池中现共 $PKG_IN_POOL 个文件)"

    OPENSSL_BIN="staging_dir/host/bin/openssl"
    NE_KEY="$APK_KEYS_DIR/local-private-key.pem"
    NEED_KEY_GEN=0
    if [ ! -s "$NE_KEY" ] && [ ! -s "$APK_KEYS_DIR/build_key.apk.sec" ]; then
        NEED_KEY_GEN=1
    fi
    if [ "$NEED_KEY_GEN" = "1" ] && [ -x "$OPENSSL_BIN" ]; then
        echo "🔑 预生成 EC 签名 key(与 IB _check_keys 一致)..."
        mkdir -p "$APK_KEYS_DIR"
        if ! "$OPENSSL_BIN" ecparam -name prime256v1 -genkey -noout -out "$NE_KEY" 2>/dev/null; then
            echo "⚠️ ecparam 生成私钥失败,继续依赖 IB 的 _check_keys"
        else
            # IB sed: '1s/^/untrusted comment: Local build key\n/'
            sed -i '1s/^/untrusted comment: Local build key\n/' "$NE_KEY" 2>/dev/null
            if "$OPENSSL_BIN" ec -in "$NE_KEY" -pubout > "$APK_KEYS_DIR/local-public-key.pem" 2>/dev/null; then
                sed -i '1s/^/untrusted comment: Local build key\n/' "$APK_KEYS_DIR/local-public-key.pem" 2>/dev/null
                ls -la "$APK_KEYS_DIR/"
                echo "✅ EC key 就绪:$NE_KEY"
            else
                echo "⚠️ 导出公钥失败,继续依赖 IB 的 _check_keys"
            fi
        fi
    fi

    # 在 IB 子目录内运行 ../staging_dir/host/bin/apk mkndx。
    run_mkndx() {
        local args=("$@")
        local cmd=(../"$APK_BIN" mkndx)
        if [ -s "$APK_SIGN_KEY" ]; then
            cmd+=(--keys-dir "$(pwd)/$APK_KEYS_DIR")
            cmd+=(--sign "$(pwd)/$APK_SIGN_KEY")
        fi
        cmd+=(--allow-untrusted --output packages.adb "${args[@]}")
        "${cmd[@]}"
    }

    if [ -x "$APK_BIN" ]; then
        # IB 25.12.x 默认 CONFIG_SIGNATURE_CHECK=y,所有 packages.adb 必
        # 须用 local-private-key.pem 签名,否则 apk 读到时 UNTRUSTED。
        APK_FILES=()
        for f in packages/*.apk; do
            [ -e "$f" ] || continue
            APK_FILES+=("$(basename "$f")")
        done
        PKG_COUNT="${#APK_FILES[@]}"
        echo "🔧 显式重建 SIGNED packages.adb 索引(待索引 apk 数量: $PKG_COUNT)..."
        if [ "$PKG_COUNT" -eq 0 ]; then
            echo "⚠️ packages/ 是空的,没有 apk 可索引,跳过"
        elif (cd packages && run_mkndx "${APK_FILES[@]}"); then
            echo "✅ SIGNED packages.adb 已就绪 ($PKG_COUNT 个 apk)"
        else
            echo "⚠️ mkndx 整体失败,逐个诊断损坏的 apk ..."
            BAD=()
            for entry in "${APK_FILES[@]}"; do
                if ! (cd packages && run_mkndx "$entry"); then
                    echo "  ✗ 损坏: packages/$entry"
                    BAD+=("$entry")
                fi
            done
            if [ "${#BAD[@]}" -gt 0 ]; then
                echo "🚮 暂时移出损坏的 apk ..."
                mkdir -p packages/.bad
                for entry in "${BAD[@]}"; do
                    mv "packages/$entry" "packages/.bad/$entry"
                done
                APK_FILES=()
                for f in packages/*.apk; do
                    [ -e "$f" ] || continue
                    APK_FILES+=("$(basename "$f")")
                done
                if [ "${#APK_FILES[@]}" -eq 0 ]; then
                    echo "⚠️ 没有健康的 apk 留下来,跳过重建"
                elif (cd packages && run_mkndx "${APK_FILES[@]}"); then
                    echo "✅ 已用剩余的健康 apk 重建 SIGNED 索引(损坏 apk 的功能将不可用)"
                else
                    echo "⚠️ 即便移出损坏 apk 后仍无法生成索引,继续依赖 IB 自动重建"
                fi
            fi
        fi

        # 把 packages.adb 的 mtime 设到所有 *.apk 之后,避免 IB 因
        # mkndx 旧而重建产生未签名索引。
        if [ -f packages/packages.adb ]; then
            touch -d "@$(($(date +%s) + 60))" packages/packages.adb 2>/dev/null || \
                touch packages/packages.adb
            echo "🔒 packages.adb mtime 已更新,IB 不会重建"
        fi
    else
        echo "⚠️ 找不到 $APK_BIN,继续依赖 IB 自动重建(不推荐)"
    fi
fi

# ============================================
# 步骤3: 合并第三方插件到包列表
# ============================================
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译包列表:"
echo "$PACKAGES"

# ============================================
# [Docker 插件]
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    echo "🐳 Docker enabled, adding docker packages"
    PACKAGES="$PACKAGES docker docker-compose luci-app-dockerman luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # 下载 GeoIP and GeoSite 数据库
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
    echo "✅ openclash预装GeoData 数据库完成！"
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 若构建nikki 则添加GeoIP and GeoSite
if echo "$PACKAGES" | grep -q "luci-app-nikki"; then
    # 创建目录
    mkdir -p files/etc/nikki/run/
    # 下载 GeoIP and GeoSite 数据库
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat -O files/etc/nikki/run/geoip.dat
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat -O files/etc/nikki/run/geosite.dat
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb -O files/etc/nikki/run/country.mmdb
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb -O files/etc/nikki/run/GeoLite2-ASN.mmdb
    #chmod 755 files/etc/nikki/run/*
    # =========================================================
    # 自动获取 Zashboard 最新版本并锁定
    # =========================================================  
    echo "📦 正在获取 Zashboard 最新版本..." 
    ZASHBOARD_LATEST_URL="https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip"
    # 使用 wget 获取最终重定向地址
    ZASHBOARD_FINAL_URL=$(wget \
        --spider \
        --server-response \
        "$ZASHBOARD_LATEST_URL" 2>&1 \
        | grep -i "Location:" \
        | tail -n 1 \
        | sed 's/.*Location: //' \
        | tr -d '\r')    
    if [ -n "$ZASHBOARD_FINAL_URL" ]; then
    
        ZASHBOARD_VERSION=$(echo "$ZASHBOARD_FINAL_URL" \
            | sed -n 's#.*/releases/download/\([^/]*\)/.*#\1#p')    
    fi   
    if [ -n "$ZASHBOARD_VERSION" ]; then
        echo "🔖 Zashboard 最新版本：$ZASHBOARD_VERSION"
        ZASHBOARD_URL="https://github.com/Zephyruso/zashboard/releases/download/${ZASHBOARD_VERSION}/dist-cdn-fonts.zip"
        echo "📥 正在下载 Zashboard $ZASHBOARD_VERSION..."  
        rm -f /tmp/zashboard.zip
        if wget -q --show-progress \
            "$ZASHBOARD_URL" \
            -O /tmp/zashboard.zip; then
            rm -rf files/etc/nikki/run/ui/*
            mkdir -p files/etc/nikki/run/ui
            if unzip -qo /tmp/zashboard.zip \
                -d files/etc/nikki/run/ui/; then
                echo "✅ Zashboard $ZASHBOARD_VERSION 预装完成！"
            else
                echo "❌ Zashboard 解压失败！"
                rm -f /tmp/zashboard.zip
                exit 1
            fi
            rm -f /tmp/zashboard.zip
        else
            echo "❌ Zashboard $ZASHBOARD_VERSION 下载失败！"
            rm -f /tmp/zashboard.zip
            exit 1
        fi  
    else
        echo "❌ 无法获取 Zashboard 最新版本号！"
        exit 1
    fi
    # =========================================================
    # 设置文件权限
    # =========================================================
    find files/etc/nikki/run -type d -exec chmod 755 {} \;
    find files/etc/nikki/run -type f -exec chmod 644 {} \;

    echo "=========================================="
    echo "✅ Nikki 预装完成"
    echo "   GeoData    : MetaCubeX latest"
    echo "   Zashboard  : $ZASHBOARD_VERSION"
    echo "=========================================="
else
    echo "⚪️ 未选择 luci-app-nikki"
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建......打印所有包名"
echo "$PACKAGES"

# ============================================
# 步骤5: 关闭 apk 签名校验
# ============================================
if [ -f .config ] && grep -q "^CONFIG_SIGNATURE_CHECK=y" .config; then
    cp .config .config.bak.imm
    sed -i 's/^CONFIG_SIGNATURE_CHECK=y$/CONFIG_SIGNATURE_CHECK=/' .config
    echo "🔓 .config: CONFIG_SIGNATURE_CHECK 已置空(原值备份到 .config.bak.imm)"
    grep -n '^CONFIG_SIGNATURE_CHECK' .config
fi

# ============================================
# 步骤6: 执行 make image
# ============================================
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" FILES="files"

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
