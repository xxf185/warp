#!/bin/bash

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")

# 判断是否为root用户
[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

# 检测系统，本部分代码感谢fscarmen的指导
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持VPS的当前系统，请使用主流的操作系统" && exit 1

curr=$(pwd)

checkvirt(){
    case "$(systemd-detect-virt)" in
        openvz) echo "" ;;
        * ) red "脚本仅支持OpenVZ虚拟化架构的VPS启用TUN模块！" && exit 1 ;;
    esac
}

checkTUN(){
    TUNStatus=1
    TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')
    [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]] && TUNStatus=0
}

openTUN(){
    checkTUN
    if [[ $TUNStatus == 1 ]]; then
        red "检测到目前VPS已经启用TUN模块，无需重复启用"
    fi
    if [[ $TUNStatus == 0 ]]; then
        yellow "检测到VPS虚拟化架构为OpenVZ，正在尝试使用脚本启用TUN"
        cd /dev
        mkdir net
        mknod net/tun c 10 200
        chmod 0666 net/tun
        sleep 2
        checkTUN
        if [[ $TUNStatus == 1 ]]; then
            green "OpenVZ VPS的TUN模块已启用成功！"
            cd $curr && rm -f tun.sh
        else
            red "在OpenVZ VPS尝试开启TUN模块失败，请到VPS控制面板处开启" 
            cd $curr && rm -f tun.sh
            exit 1
        fi
        cat <<EOF > /usr/bin/tun.sh
#!/bin/bash
# Generated by Script: Misaka-blog/cfwarp-script
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
        chmod +x /usr/bin/tun.sh
        grep -qE "^ *@reboot root bash /usr/bin/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /usr/bin/tun.sh >/dev/null 2>&1" >> /etc/crontab
    fi
}

checkvirt
openTUN
