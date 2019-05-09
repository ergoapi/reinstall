#!/bin/bash

export VER='amd64'
export tmpDIST='buster'
export tmpURL=''
# export tmpWORD=''
export tmpMirror=''
export tmpSSL=''
export tmpINS='auto'
export tmpFW=''
export ipAddr=''
export ipMask=''
export ipGate=''
export linuxdists='debian'
export ddMode='0'
export setNet='0'
export setRDP='0'
export setIPv6='0'
export isMirror='0'
export FindDists='0'
export loaderMode='0'
export SpikCheckDIST='0'
export setInterfaceName='0'
export UNKNOWHW='0'
export UNVER='6.4'

curl --fail --silent --location -o /tmp/stdlib.sh https://code.godu.dev/godu/func/raw/master/func.sh || {
	exit 1
}

source /tmp/stdlib.sh
rm /tmp/stdlib.sh

while [[ $# -ge 1 ]]; do
  case $1 in
    -dd|--image)
      shift
      ddMode='1'
      tmpURL="$1"
      shift
      ;;
#    -p|--password)
#      shift
#      tmpWORD="$1"
#      shift
#      ;;
#    -i|--interface)
#      shift
#      interface="$1"
#      shift
#      ;;
    --ip-addr)
      shift
      ipAddr="$1"
      shift
      ;;
    --ip-mask)
      shift
      ipMask="$1"
      shift
      ;;
    --ip-gate)
      shift
      ipGate="$1"
      shift
      ;;
    --dev-net)
      shift
      setInterfaceName='1'
      ;;
    --loader)
      shift
      loaderMode='1'
      ;;
    --prefer)
      shift
      tmpPrefer="$1"
      shift
      ;;
    -a|--auto)
      shift
      tmpINS='auto'
      ;;
    -m|--manual)
      shift
      tmpINS='manual'
      ;;
    -apt|-yum|--mirror)
      shift
      isMirror='1'
      tmpMirror="$1"
      shift
      ;;
    -rdp)
      shift
      setRDP='1'
      WinRemote="$1"
      shift
      ;;
    -ssl)
      shift
      tmpSSL="$1"
      shift
      ;;
    --ipv6)
      shift
      setIPv6='1'
      ;;
    *)
      :
      ;;
    esac
  done

[[ "$EUID" -ne '0' ]] && notice "Error:This script must be run as root!"

function CheckDependence(){
FullDependence='0';
for BIN_DEP in `echo "$1" |sed 's/,/\n/g'`
  do
    if [[ -n "$BIN_DEP" ]]; then
      Founded='0';
      for BIN_PATH in `echo "$PATH" |sed 's/:/\n/g'`
        do
          ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
          if [ $? == '0' ]; then
            Founded='1';
            break;
          fi
        done
      if [ "$Founded" == '1' ]; then
        info "ok" "$BIN_DEP"
      else
        FullDependence='1';
        info "not Install" "$BIN_DEP"
      fi
    fi
  done
if [ "$FullDependence" == '1' ]; then
  notice "please install it"
fi
}

progress "check Dependence"

if [[ "$ddMode" == '1' ]]; then
  info "ddMode:" "$ddMode" 
  CheckDependence iconv;
  linuxdists='debian';
  tmpDIST='buster';
  VER='amd64';
  tmpINS='auto';
fi

if [[ "$linuxdists" == 'debian' ]] || [[ "$linuxdists" == 'ubuntu' ]]; then
  CheckDependence wget,awk,grep,sed,cut,cat,cpio,gzip,find,dirname,basename;
fi

if [[ -n "$tmpWORD" ]]; then
  CheckDependence openssl;
fi

if [[ "$loaderMode" == "0" ]]; then
  [[ -f '/boot/grub/grub.cfg' ]] && GRUBOLD='0' && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg';
  [[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub2/grub.cfg' ]] && GRUBOLD='0' && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg';
  [[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub/grub.conf' ]] && GRUBOLD='1' && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf';
  [ -z "$GRUBDIR" -o -z "$GRUBFILE" ] && echo -ne "Error! \nNot Found grub path.\n" && exit 1;
else
  tmpINS='auto'
fi

if [[ "$isMirror" == '1' ]]; then
  if [[ -n "$tmpMirror" ]]; then
    TMPMirrorHost="$(echo -n "$tmpMirror" |grep -Eo '.*\.(\w+)')";
    echo "$TMPMirrorHost" |grep -q '://';
    if [[ $? == '0' ]]; then
      MirrorHost="$(echo "$TMPMirrorHost" |awk -F'://' '{print $2}')";
    else
      echo -en "\n\033[31mInvaild Mirror! \033[0m\n";
      [[ "$linuxdists" == 'debian' ]] && echo -en "\033[33mexample:\033[0m http://deb.debian.org/debian\n\n";
      exit 1
    fi
    if [[ -n "$MirrorHost" ]]; then
      MirrorFolder="$(echo -n "$tmpMirror" |awk -F''${MirrorHost}'' '{print $2}' |sed 's/\/$//g')";
      if [[ -z "$MirrorFolder" ]]; then
        [[ "$linuxdists" == 'debian' ]] && MirrorFolder='/debian';
      fi
      DISTMirror="${MirrorHost}${MirrorFolder}";
    fi
  fi
fi

if [[ -z "$DISTMirror" ]]; then
  [[ "$linuxdists" == 'debian' ]] && MirrorHost='snapshot.debian.org' && MirrorFolder='/archive/debian/20190321T212815Z' && DISTMirror="${MirrorHost}${MirrorFolder}";
fi

if [[ -n "$tmpPrefer" ]]; then
  PreferOption="$(echo "$tmpPrefer" |sed 's/[[:space:]]*//g')"
fi

PreferOption='current';
if [[ -z "$PreferOption" ]]; then
  PreferOption='current';
fi

if [[ -z "$tmpDIST" ]]; then
  [[ "$linuxdists" == 'debian' ]] && DIST='buster';
fi

if [[ -z "$DIST" ]]; then
  if [[ "$linuxdists" == 'debian' ]]; then
    SpikCheckDIST='0'
    DIST="$(echo "$tmpDIST" |sed -r 's/(.*)/\L\1/')";
    echo "$DIST" |grep -q '[0-9]';
    [[ $? -eq '0' ]] && {
      isDigital="$(echo "$DIST" |grep -o '[\.0-9]\{1,\}' |sed -n '1h;1!H;$g;s/\n//g;$p' |cut -d'.' -f1)";
      [[ -n $isDigital ]] && {
        [[ "$isDigital" == '7' ]] && DIST='wheezy';
        [[ "$isDigital" == '8' ]] && DIST='jessie';
        [[ "$isDigital" == '9' ]] && DIST='buster';
        [[ "$isDigital" == '10' ]] && DIST='buster';
      }
    }
  fi
fi

if [[ "$SpikCheckDIST" == '0' ]]; then
  DistsList="$(wget --no-check-certificate -qO- "http://$DISTMirror/dists/" |grep -o 'href=.*/"' |cut -d'"' -f2 |sed '/-\|old\|Debian\|experimental\|stable\|test\|sid\|devel/d' |grep '^[^/]' |sed -n '1h;1!H;$g;s/\n//g;s/\//\;/g;$p')";
  for CheckDEB in `echo "$DistsList" |sed 's/;/\n/g'`
    do
      [[ "$CheckDEB" == "$DIST" ]] && FindDists='1';
      [[ "$FindDists" == '1' ]] && break;
    done
  [[ "$FindDists" == '0' ]] && {
    echo -ne '\nThe dists version not found, Please check it! \n\n'
    bash $0 error;
    exit 1;
  }
fi

[[ "$ddMode" == '1' ]] && {
  export SSL_SUPPORT='https://moeclub.org/get/wget_udeb_amd64';
  if [[ -n "$tmpURL" ]]; then
    DDURL="$tmpURL"
    echo "$DDURL" |grep -q '^http://\|^ftp://\|^https://';
    [[ $? -ne '0' ]] && echo 'Please input vaild URL,Only support http://, ftp:// and https:// !' && exit 1;
    [[ -n "$tmpSSL" ]] && SSL_SUPPORT="$tmpSSL";
  else
    echo 'Please input vaild image URL! ';
    exit 1;
  fi
}

[[ -n "$tmpINS" ]] && {
  [[ "$tmpINS" == 'auto' ]] && inVNC='n';
  [[ "$tmpINS" == 'manual' ]] && inVNC='y';
}

#[ -n "$ipAddr" ] && [ -n "$ipMask" ] && [ -n "$ipGate" ] && setNet='1';
# [[ -n "$tmpWORD" ]] && myPASSWORD="$(openssl passwd -1 "$tmpWORD")";
# [[ -z "$myPASSWORD" ]] && myPASSWORD='$1$0shYGfBd$8v189JOozDO1jPqPO645e1';
#[[ -n "$tmpFW" ]] && INCFW="$tmpFW";
[[ -z "$INCFW" ]] && INCFW='0';

#if [[ -n "$interface" ]]; then
#  IFETH="$interface"
#else
  # debian
#  IFETH="auto"
#fi

clear && echo -e "\n\033[36m# Install\033[0m\n"

ASKVNC(){
  inVNC='y';
  [[ "$ddMode" == '0' ]] && {
    echo -ne "\033[34mCan you login VNC?\033[0m\e[33m[\e[32my\e[33m/n]\e[0m "
    read tmpinVNC
    [[ -n "$inVNCtmp" ]] && inVNC="$tmpinVNC"
  }
  [ "$inVNC" == 'y' -o "$inVNC" == 'Y' ] && inVNC='y';
  [ "$inVNC" == 'n' -o "$inVNC" == 'N' ] && inVNC='n';
}

[ "$inVNC" == 'y' -o "$inVNC" == 'n' ] || ASKVNC;
[[ "$linuxdists" == 'debian' ]] && LinuxName='Debian';
[[ "$ddMode" == '0' ]] && { 
  [[ "$inVNC" == 'y' ]] && echo -e "\033[34mManual Mode\033[0m insatll \033[33m$LinuxName\033[0m [\033[33m$DIST\033[0m] [\033[33m$VER\033[0m] in VNC. "
  [[ "$inVNC" == 'n' ]] && echo -e "\033[34mAuto Mode\033[0m insatll \033[33m$LinuxName\033[0m [\033[33m$DIST\033[0m] [\033[33m$VER\033[0m]. "
}
[[ "$ddMode" == '1' ]] && {
  echo -ne "\033[34mAuto Mode\033[0m insatll \033[33mWindows\033[0m\n[\033[33m$DDURL\033[0m]\n"
}

echo -e "\n[\033[33m$LinuxName\033[0m] [\033[33m$DIST\033[0m] [\033[33m$VER\033[0m] Downloading..."

[[ -z "$DISTMirror" ]] && echo -ne "\033[31mError! \033[0mInvaild mirror! \n" && exit 1

if [[ "$linuxdists" == 'debian' ]] || [[ "$linuxdists" == 'ubuntu' ]]; then
wget --no-check-certificate -qO '/boot/initrd.img' "https://mirrors.tuna.tsinghua.edu.cn/debian/dists/${tmpDIST}/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
[[ $? -ne '0' ]] && echo -ne "\033[31mError! \033[0mDownload 'initrd.img' for \033[33m$linuxdists\033[0m failed! \n" && exit 1
wget --no-check-certificate -qO '/boot/vmlinuz' "https://mirrors.tuna.tsinghua.edu.cn/debian/dists/${tmpDIST}/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux"
[[ $? -ne '0' ]] && echo -ne "\033[31mError! \033[0mDownload 'vmlinuz' for \033[33m$linuxdists\033[0m failed! \n" && exit 1
fi
if [[ "$linuxdists" == 'debian' ]]; then
  if [[ "$ddMode" == '1' ]]; then
    vKernel_udeb=$(wget --no-check-certificate -qO- "https://mirrors.tuna.tsinghua.edu.cn/debian/dists/${tmpDIST}/main/installer-amd64/current/images/udeb.list" |grep '^acpi-modules' |head -n1 |grep -o '[0-9]\{1,2\}.[0-9]\{1,2\}.[0-9]\{1,2\}-[0-9]\{1,2\}' |head -n1)
    [[ -z "vKernel_udeb" ]] && vKernel_udeb="3.16.0-4"
  fi
fi

[[ "$setNet" == '1' ]] && {
  IPv4="$ipAddr";
  MASK="$ipMask";
  GATE="$ipGate";
} || {
  DEFAULTNET="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
  [[ -n "$DEFAULTNET" ]] && IPSUB="$(ip addr |grep ''${DEFAULTNET}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";
  IPv4="$(echo -n "$IPSUB" |cut -d'/' -f1)";
  NETSUB="$(echo -n "$IPSUB" |grep -o '/[0-9]\{1,2\}')";
  GATE="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
  [[ -n "$NETSUB" ]] && MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${NETSUB}'' |cut -d'/' -f1)";
}

[[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
echo "Not found \`ip command\`, It will use \`route command\`."
ipNum() {
  local IFS='.';
  read ip1 ip2 ip3 ip4 <<<"$1";
  echo $((ip1*(1<<24)+ip2*(1<<16)+ip3*(1<<8)+ip4));
}

SelectMax(){
ii=0;
for IPITEM in `route -n |awk -v OUT=$1 '{print $OUT}' |grep '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'`
  do
    NumTMP="$(ipNum $IPITEM)";
    eval "arrayNum[$ii]='$NumTMP,$IPITEM'";
    ii=$[$ii+1];
  done
echo ${arrayNum[@]} |sed 's/\s/\n/g' |sort -n -k 1 -t ',' |tail -n1 |cut -d',' -f2;
}

[[ -z $IPv4 ]] && IPv4="$(ifconfig |grep 'Bcast' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1)";
[[ -z $GATE ]] && GATE="$(SelectMax 2)";
[[ -z $MASK ]] && MASK="$(SelectMax 3)";

[[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
  echo "Error! Not configure network. ";
  exit 1;
}
}

[[ "$setNet" != '1' ]] && [[ -f '/etc/network/interfaces' ]] && {
  [[ -z "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='1' || AutoNet='0';
  [[ -d /etc/network/interfaces.d ]] && {
    ICFGN="$(find /etc/network/interfaces.d -name '*.cfg' |wc -l)" || ICFGN='0';
    [[ "$ICFGN" -ne '0' ]] && {
      for NetCFG in `ls -1 /etc/network/interfaces.d/*.cfg`
        do 
          [[ -z "$(cat $NetCFG | sed -n '/iface.*inet static/p')" ]] && AutoNet='1' || AutoNet='0';
          [[ "$AutoNet" -eq '0' ]] && break;
        done
    }
  }
}

[[ "$setNet" != '1' ]] && [[ -d '/etc/sysconfig/network-scripts' ]] && {
  ICFGN="$(find /etc/sysconfig/network-scripts -name 'ifcfg-*' |grep -v 'lo'|wc -l)" || ICFGN='0';
  [[ "$ICFGN" -ne '0' ]] && {
    for NetCFG in `ls -1 /etc/sysconfig/network-scripts/ifcfg-* |grep -v 'lo$' |grep -v ':[0-9]\{1,\}'`
      do 
        [[ -n "$(cat $NetCFG | sed -n '/BOOTPROTO.*[dD][hH][cC][pP]/p')" ]] && AutoNet='1' || {
          AutoNet='0' && . $NetCFG;
          [[ -n $NETMASK ]] && MASK="$NETMASK";
          [[ -n $GATEWAY ]] && GATE="$GATEWAY";
        }
        [[ "$AutoNet" -eq '0' ]] && break;
      done
  }
}

if [[ "$loaderMode" == "0" ]]; then
  [[ ! -f $GRUBDIR/$GRUBFILE ]] && echo "Error! Not Found $GRUBFILE. " && exit 1;

  [[ ! -f $GRUBDIR/$GRUBFILE.old ]] && [[ -f $GRUBDIR/$GRUBFILE.bak ]] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old;
  mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak;
  [[ -f $GRUBDIR/$GRUBFILE.old ]] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE;
else
  GRUBOLD='2'
fi

[[ "$GRUBOLD" == '0' ]] && {
  READGRUB='/tmp/grub.read'
  cat $GRUBDIR/$GRUBFILE |sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' |grep -om 1 'menuentry\ [^{]*{[^}]*}%%%%%%%' |sed 's/%%%%%%%/\n/g' >$READGRUB
  LoadNum="$(cat $READGRUB |grep -c 'menuentry ')"
  if [[ "$LoadNum" -eq '1' ]]; then
    cat $READGRUB |sed '/^$/d' >/tmp/grub.new;
  elif [[ "$LoadNum" -gt '1' ]]; then
    CFG0="$(awk '/menuentry /{print NR}' $READGRUB|head -n 1)";
    CFG2="$(awk '/menuentry /{print NR}' $READGRUB|head -n 2 |tail -n 1)";
    CFG1="";
    for tmpCFG in `awk '/}/{print NR}' $READGRUB`
      do
        [ "$tmpCFG" -gt "$CFG0" -a "$tmpCFG" -lt "$CFG2" ] && CFG1="$tmpCFG";
      done
    [[ -z "$CFG1" ]] && {
      echo "Error! read $GRUBFILE. ";
      exit 1;
    }

    sed -n "$CFG0,$CFG1"p $READGRUB >/tmp/grub.new;
    [[ -f /tmp/grub.new ]] && [[ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ]] || {
      echo -ne "\033[31mError! \033[0mNot configure $GRUBFILE. \n";
      exit 1;
    }
  fi
  [ ! -f /tmp/grub.new ] && echo "Error! $GRUBFILE. " && exit 1;
  sed -i "/menuentry.*/c\menuentry\ \'Install OS \[$DIST\ $VER\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" /tmp/grub.new
  sed -i "/echo.*Loading/d" /tmp/grub.new;
  INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
}

[[ "$GRUBOLD" == '1' ]] && {
  CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
  CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)";
  [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >/tmp/grub.new;
  [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE >/tmp/grub.new;
  [[ ! -f /tmp/grub.new ]] && echo "Error! configure append $GRUBFILE. " && exit 1;
  sed -i "/title.*/c\title\ \'Install OS \[$DIST\ $VER\]\'" /tmp/grub.new;
  sed -i '/^#/d' /tmp/grub.new;
  INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
}

if [[ "$loaderMode" == "0" ]]; then
[[ -n "$(grep 'linux.*/\|kernel.*/' /tmp/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

LinuxKernel="$(grep 'linux.*/\|kernel.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)";
[[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
LinuxIMG="$(grep 'initrd.*/' /tmp/grub.new |awk '{print $1}' |tail -n 1)";
[ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" /tmp/grub.new && LinuxIMG='initrd';

if [[ "$setInterfaceName" == "1" ]]; then
  Add_OPTION="net.ifnames=0 biosdevname=0";
else
  Add_OPTION="";
fi

if [[ "$setIPv6" == "1" ]]; then
  Add_OPTION="$Add_OPTION ipv6.disable=1";
fi

if [[ "$linuxdists" == 'debian' ]] || [[ "$linuxdists" == 'ubuntu' ]]; then
  BOOT_OPTION="auto=true $Add_OPTION hostname=$linuxdists domain= -- quiet"
fi

[[ "$Type" == 'InBoot' ]] && {
  sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz $BOOT_OPTION" /tmp/grub.new;
  sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrd.img" /tmp/grub.new;
}

[[ "$Type" == 'NoBoot' ]] && {
  sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz $BOOT_OPTION" /tmp/grub.new;
  sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrd.img" /tmp/grub.new;
}

sed -i '$a\\n' /tmp/grub.new;
fi

[[ "$inVNC" == 'n' ]] && {
GRUBPATCH='0';

if [[ "$loaderMode" == "0" ]]; then
[ -f '/etc/network/interfaces' -o -d '/etc/sysconfig/network-scripts' ] || {
  notice "Error, Not found interfaces config."
}

sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
sed -i ''${INSERTGRUB}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE;
[[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;
fi

[[ -d /tmp/boot ]] && rm -rf /tmp/boot;
mkdir -p /tmp/boot;
cd /tmp/boot;
if [[ "$linuxdists" == 'debian' ]] || [[ "$linuxdists" == 'ubuntu' ]]; then
  COMPTYPE="gzip";
fi
CompDected='0'
for ListCOMP in `echo -en 'gzip\nlzma\nxz'`
  do
    if [[ "$COMPTYPE" == "$ListCOMP" ]]; then
      CompDected='1'
      if [[ "$COMPTYPE" == 'gzip' ]]; then
        NewIMG="initrd.img.gz"
      else
        NewIMG="initrd.img.$COMPTYPE"
      fi
      mv -f "/boot/initrd.img" "/tmp/$NewIMG"
      break;
    fi
  done
[[ "$CompDected" != '1' ]] && echo "Detect compressed type not support." && exit 1;
[[ "$COMPTYPE" == 'lzma' ]] && UNCOMP='xz --format=lzma --decompress';
[[ "$COMPTYPE" == 'xz' ]] && UNCOMP='xz --decompress';
[[ "$COMPTYPE" == 'gzip' ]] && UNCOMP='gzip -d';

$UNCOMP < /tmp/$NewIMG | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1

if [[ "$linuxdists" == 'debian' ]] || [[ "$linuxdists" == 'ubuntu' ]]; then
cat >/tmp/boot/preseed.cfg<<EOF
### localization
d-i debian-installer/locale string en_US
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8
d-i debian-installer/add-kernel-opts string net.ifnames=0 biosdevname=0
d-i localechooser/supported-locales multiselect en_US.UTF-8

### Keyboard selection.
d-i console-tools/archs select at
d-i console-keymaps-at/keymap select us
d-i keyboard-configuration/xkb-keymap select us

### Network configuration
d-i netcfg/choose_interface select auto
#d-i netcfg/disable_autoconfig boolean true
#d-i netcfg/dhcp_failed note
#d-i netcfg/dhcp_options select Configure network manually
#d-i netcfg/get_ipaddress string $IPv4
#d-i netcfg/get_netmask string $MASK
#d-i netcfg/get_gateway string $GATE
#d-i netcfg/get_nameservers string 8.8.8.8
d-i netcfg/no_default_route boolean true
#d-i netcfg/confirm_static boolean true
d-i netcfg/dhcp_timeout string 60

### Mirror settings
choose-mirror-bin mirror/http/proxy string
d-i mirror/country string manual
d-i mirror/http/directory string /debian
#d-i mirror/http/hostname string mirrors.aliyun.com
d-i mirror/http/hostname string mirrors.tuna.tsinghua.edu.cn
d-i mirror/http/proxy string
d-i apt-setup/backports boolean true
d-i apt-setup/services-select multiselect security backports
d-i apt-setup/security_host string mirrors.tuna.tsinghua.edu.cn
d-i apt-setup/security_path string /debian
d-i apt-setup/disable-cdrom-entries boolean true

### Account setup
d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password password vagrant
d-i passwd/root-password-again password vagrant
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

### Clock and time zone setup
d-i clock-setup/utc boolean true
d-i clock-setup/utc-auto boolean true
d-i clock-setup/ntp boolean true
d-i time/zone string Asia/Shanghai

d-i preseed/early_command string anna-install libfuse2-udeb fuse-udeb ntfs-3g-udeb fuse-modules-${vKernel_udeb}-amd64-di
d-i partman/early_command string \
debconf-set partman-auto/disk "\$(list-devices disk |head -n1)"; \
wget -qO- '$DDURL' |gunzip -dc |/bin/dd of=\$(list-devices disk |head -n1); \
mount.ntfs-3g \$(list-devices partition |head -n1) /mnt; \
cd '/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs'; \
cd Start* || cd start*; \
cp -f '/net.bat' './net.bat'; \
/sbin/reboot; \
debconf-set grub-installer/bootdev string "\$(list-devices disk |head -n1)"; \
umount /media || true; \

### Partitioning
d-i partman/mount_style select uuid
d-i partman-auto/init_automatically_partition select Guided - use entire disk
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i debian-installer/allow_unauthenticated boolean true

tasksel tasksel/first multiselect minimal
d-i pkgsel/update-policy select none
d-i pkgsel/include string curl wget openssh-server sudo sed apt-transport-https net-tools nano git
d-i pkgsel/upgrade select none

popularity-contest popularity-contest/participate boolean false

d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/reboot boolean true
d-i preseed/late_command string	\
sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/g' /target/etc/ssh/sshd_config;
EOF

[[ "$loaderMode" != "0" ]] && AutoNet='1'

[[ "$setNet" == '0' ]] && [[ "$AutoNet" == '1' ]] && {
  sed -i '/netcfg\/disable_autoconfig/d' /tmp/boot/preseed.cfg
  sed -i '/netcfg\/dhcp_options/d' /tmp/boot/preseed.cfg
  sed -i '/netcfg\/get_.*/d' /tmp/boot/preseed.cfg
  sed -i '/netcfg\/confirm_static/d' /tmp/boot/preseed.cfg
}


[[ "$GRUBPATCH" == '1' ]] && {
  sed -i 's/^d-i\ grub-installer\/bootdev\ string\ default//g' /tmp/boot/preseed.cfg
}
[[ "$GRUBPATCH" == '0' ]] && {
  sed -i 's/debconf-set\ grub-installer\/bootdev.*\"\;//g' /tmp/boot/preseed.cfg
}

[[ "$linuxdists" == 'debian' ]] && {
  sed -i '/user-setup\/allow-password-weak/d' /tmp/boot/preseed.cfg
  sed -i '/user-setup\/encrypt-home/d' /tmp/boot/preseed.cfg
  sed -i '/pkgsel\/update-policy/d' /tmp/boot/preseed.cfg
  sed -i 's/umount\ \/media.*true\;\ //g' /tmp/boot/preseed.cfg
}
[[ "$INCFW" == '1' ]] && [[ "$linuxdists" == 'debian' ]] && [[ -f '/boot/firmware.cpio.gz' ]] && {
  gzip -d < /boot/firmware.cpio.gz | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1
}

[[ "$ddMode" == '1' ]] && {
WinNoDHCP(){
  echo -ne "for\0040\0057f\0040\0042tokens\00753\0052\0042\0040\0045\0045i\0040in\0040\0050\0047netsh\0040interface\0040show\0040interface\0040\0136\0174more\0040\00533\0040\0136\0174findstr\0040\0057I\0040\0057R\0040\0042本地\0056\0052\0040以太\0056\0052\0040Local\0056\0052\0040Ethernet\0042\0047\0051\0040do\0040\0050set\0040EthName\0075\0045\0045j\0051\r\nnetsh\0040\0055c\0040interface\0040ip\0040set\0040address\0040name\0075\0042\0045EthName\0045\0042\0040source\0075static\0040address\0075$IPv4\0040mask\0075$MASK\0040gateway\0075$GATE\r\nnetsh\0040\0055c\0040interface\0040ip\0040add\0040dnsservers\0040name\0075\0042\0045EthName\0045\0042\0040address\00758\00568\00568\00568\0040index\00751\0040validate\0075no\r\n\r\n" >>'/tmp/boot/net.tmp';
}
WinRDP(){
  echo -ne "netsh\0040firewall\0040set\0040portopening\0040protocol\0075ALL\0040port\0075$WinRemote\0040name\0075RDP\0040mode\0075ENABLE\0040scope\0075ALL\0040profile\0075ALL\r\nnetsh\0040firewall\0040set\0040portopening\0040protocol\0075ALL\0040port\0075$WinRemote\0040name\0075RDP\0040mode\0075ENABLE\0040scope\0075ALL\0040profile\0075CURRENT\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Network\0134NewNetworkWindowOff\0042\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0042\0040\0057v\0040fDenyTSConnections\0040\0057t\0040reg\0137dword\0040\0057d\00400\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0134Wds\0134rdpwd\0134Tds\0134tcp\0042\0040\0057v\0040PortNumber\0040\0057t\0040reg\0137dword\0040\0057d\0040$WinRemote\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0134WinStations\0134RDP\0055Tcp\0042\0040\0057v\0040PortNumber\0040\0057t\0040reg\0137dword\0040\0057d\0040$WinRemote\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0134WinStations\0134RDP\0055Tcp\0042\0040\0057v\0040UserAuthentication\0040\0057t\0040reg\0137dword\0040\0057d\00400\0040\0057f\r\nFOR\0040\0057F\0040\0042tokens\00752\0040delims\0075\0072\0042\0040\0045\0045i\0040in\0040\0050\0047SC\0040QUERYEX\0040TermService\0040\0136\0174FINDSTR\0040\0057I\0040\0042PID\0042\0047\0051\0040do\0040TASKKILL\0040\0057F\0040\0057PID\0040\0045\0045i\r\nFOR\0040\0057F\0040\0042tokens\00752\0040delims\0075\0072\0042\0040\0045\0045i\0040in\0040\0050\0047SC\0040QUERYEX\0040UmRdpService\0040\0136\0174FINDSTR\0040\0057I\0040\0042PID\0042\0047\0051\0040do\0040TASKKILL\0040\0057F\0040\0057PID\0040\0045\0045i\r\nSC\0040START\0040TermService\r\n\r\n" >>'/tmp/boot/net.tmp';
}
  echo -ne "\0100ECHO\0040OFF\r\n\r\ncd\0056\0076\0045WINDIR\0045\0134GetAdmin\r\nif\0040exist\0040\0045WINDIR\0045\0134GetAdmin\0040\0050del\0040\0057f\0040\0057q\0040\0042\0045WINDIR\0045\0134GetAdmin\0042\0051\0040else\0040\0050\r\necho\0040CreateObject\0136\0050\0042Shell\0056Application\0042\0136\0051\0056ShellExecute\0040\0042\0045\0176s0\0042\0054\0040\0042\0045\0052\0042\0054\0040\0042\0042\0054\0040\0042runas\0042\0054\00401\0040\0076\0076\0040\0042\0045temp\0045\0134Admin\0056vbs\0042\r\n\0042\0045temp\0045\0134Admin\0056vbs\0042\r\ndel\0040\0057f\0040\0057q\0040\0042\0045temp\0045\0134Admin\0056vbs\0042\r\nexit\0040\0057b\00402\0051\r\n\r\n" >'/tmp/boot/net.tmp';
  [[ "$setNet" == '1' ]] && WinNoDHCP;
  [[ "$setNet" == '0' ]] && [[ "$AutoNet" == '0' ]] && WinNoDHCP;
  [[ "$setRDP" == '1' ]] && [[ -n "$WinRemote" ]] && WinRDP
  echo -ne "ECHO\0040SELECT\0040VOLUME\0075\0045\0045SystemDrive\0045\0045\0040\0076\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\nECHO\0040EXTEND\0040\0076\0076\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\nSTART\0040/WAIT\0040DISKPART\0040\0057S\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\nDEL\0040\0057f\0040\0057q\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\n\r\n" >>'/tmp/boot/net.tmp';
  echo -ne "cd\0040\0057d\0040\0042\0045ProgramData\0045\0057Microsoft\0057Windows\0057Start\0040Menu\0057Programs\0057Startup\0042\r\ndel\0040\0057f\0040\0057q\0040net\0056bat\r\n\r\n\r\n" >>'/tmp/boot/net.tmp';
  iconv -f 'UTF-8' -t 'GBK' '/tmp/boot/net.tmp' -o '/tmp/boot/net.bat'
  rm -rf '/tmp/boot/net.tmp'
  echo "$DDURL" |grep -q '^https://'
  [[ $? -eq '0' ]] && {
    info "Add ssl support..."
    [[ -n $SSL_SUPPORT ]] && {
      wget --no-check-certificate -qO- "$SSL_SUPPORT" |tar -x
      [[ ! -f  /tmp/boot/usr/bin/wget ]] && notice "Error! SSL_SUPPORT."
      run sed -i 's/wget\ -qO-/\/usr\/bin\/wget\ --no-check-certificate\ --retry-connrefused\ --tries=7\ --continue\ -qO-/g' /tmp/boot/preseed.cfg
    } || {
      notice "Not ssl support package! \n\n"
    }
  }
}

[[ "$ddMode" == '0' ]] && {
  sed -i '/anna-install/d' /tmp/boot/preseed.cfg
  sed -i 's/wget.*\/sbin\/reboot\;\ //g' /tmp/boot/preseed.cfg
}
fi

  find . | cpio -H newc --create --verbose | gzip -9 > /boot/initrd.img;
  rm -rf /tmp/boot;
}

info "ddMode:" "$ddMode"

chown root:root $GRUBDIR/$GRUBFILE
chmod 444 $GRUBDIR/$GRUBFILE

progress "will reboot"
sleep 3 && reboot >/dev/null 2>&1
