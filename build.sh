BULID_KERNEL_DIR=`pwd`
# 內核開源倉庫地址
KERNEL_SOURCE=https://github.com/mkcs121/android_kernel_xiaomi_sm8150
# 倉庫分支
KERNEL_SOURCE_BRANCH=miui
# CPU類型
export ARCH=arm64
# 配置文件
KERNEL_CONFIG=raphael_defconfig
KERNEL_NAME=${KERNEL_SOURCE##*/}

# 由GoogleSource提供的Clang編譯器（到這裡查找：https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+refs）
CLANG_BRANCH=android11-release
CLANG_VERSION=r383902b
# 由GoogleSource提供的64位Gcc編譯器（到這裡查找：https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+refs）
GCC64=android11-release
# 由GoogleSource提供的32位Gcc編譯器（到這裡查找：https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+refs）
GCC32=

# 編譯時使用的指令
### 預設指令 ###
BUILDKERNEL_CMDS="
CC=clang
CLANG_TRIPLE=aarch64-linux-gnu-
CROSS_COMPILE=aarch64-linux-androidkernel-
CROSS_COMPILE_ARM32=arm-linux-gnueabi-
"

### 自訂 ZyC-Clang 指令 ###
#BUILDKERNEL_CMDS="
#NM=llvm-nm
#OBJCOPY=llvm-objcopy
#LD=ld.lld
#CROSS_COMPILE=aarch64-linux-gnu-
#CROSS_COMPILE_ARM32=arm-linux-androideabi-
#CC=clang
#AR=llvm-ar
#OBJDUMP=llvm-objdump
#STRIP=llvm-strip
#"

# 原始boot.img文件下載地址（可以從卡刷包或線刷包裡提取，重命名為boot-source.img放到本腳本所在目錄下）
SOURCE_BOOT_IMAGE_NEED_DOWNLOAD=false
SOURCE_BOOT_IMAGE=ftp://192.168.1.1/boot.img

# kprobe集成方案需要修改的參數（每個內核倉庫需要開啟的選項不統一，有的機型可能全都不用開，請自行逐個測試，第一個和第二個一般需要開）：
ADD_OVERLAYFS_CONFIG=true
ADD_KPROBES_CONFIG=true
DISABLE_CC_WERROR=false
DISABLE_LTO=false

CLANG_DIR=$BULID_KERNEL_DIR/clang/$CLANG_BRANCH-$CLANG_VERSION/bin
GCC64_DIR=$BULID_KERNEL_DIR/gcc/$GCC64-64/bin
GCC32_DIR=$BULID_KERNEL_DIR/gcc/$GCC32-32/bin

# 使用自定義Clang編譯器
CLANG_CUSTOM=true
[ "$CLANG_CUSTOM" = true ] && {
	CLANG_DIR=/home/kenshin/kernel/toolchains/zyc-clang/bin
	[ ! -d $CLANG_DIR ] && {
		echo "================================================================================"
		echo "本次編譯中止！原因：自定義 Clang 編譯器文件夾 $CLANG_DIR 不存在"
		echo "================================================================================" && return 2> /dev/null || exit
	}
}
# 使用自定義64位Gcc編譯器
GCC64_CUSTOM=false
[ "$GCC64_CUSTOM" = true ] && {
	GCC64_DIR=/這裡填寫編譯器文件夾的絕對路徑/bin
	[ ! -d $GCC64_DIR ] && {
		echo "================================================================================"
		echo "本次編譯中止！原因：自定義 64 位交叉編譯器文件夾 $GCC64_DIR 不存在"
		echo "================================================================================" && return 2> /dev/null || exit
	}
}
# 使用自定義32位Gcc編譯器
GCC32_CUSTOM=false
[ "$GCC32_CUSTOM" = true ] && {
	GCC32_DIR=/這裡填寫編譯器文件夾的絕對路徑/bin
	[ ! -d $GCC32_DIR ] && {
		echo "================================================================================"
		echo "本次編譯中止！原因：自定義 32 位交叉編譯器文件夾 $GCC32_DIR 不存在"
		echo "================================================================================" && return 2> /dev/null || exit
	}
}

[ ! -f /.Checked ] && {
	echo "================================================================================"
	echo "准備檢查並安裝基本依賴包（不一定齊全，不同內核開源倉庫所需依賴包可能不同）"
	echo "================================================================================" && read -t 3
	apt update
	[ -n "$(uname -v | grep -o 16.04)" ] && {
		apt install git bison flex libssl-dev -y
		[ "$(python3 --version | grep -o 3.... | sed 's/\.//g')" -lt 380 ] && {
			wget https://www.python.org/ftp/python/3.8.0/Python-3.8.0.tar.xz
			xz -dv Python-3.8.0.tar.xz
			tar -xvf Python-3.8.0.tar
			cd Python-3.8.0
			./configure
			make -j$(nproc --all)
			make install
			cd ..
			rm -rf Python-3.8.0 Python-3.8.0.tar
		}
	}
	[ -n "$(uname -v | grep -o 18.04)" ] && {
		apt install git make gcc bison flex libssl-dev zlib1g-dev -y
		[ "$(python3 --version | grep -o 3.... | sed 's/\.//g')" -lt 380 ] && {
			wget https://www.python.org/ftp/python/3.8.0/Python-3.8.0.tar.xz
			xz -dv Python-3.8.0.tar.xz
			tar -xvf Python-3.8.0.tar
			cd Python-3.8.0
			./configure
			make -j$(nproc --all)
			make install
			cd ..
			rm -rf Python-3.8.0 Python-3.8.0.tar
		}
	}
	[ -n "$(uname -v | grep -o 20.04)" ] && apt install git make python-is-python2 gcc bison flex libssl-dev -y
	[ -n "$(uname -v | grep -o 22.04)" ] && ln -s /usr/bin/python3 /usr/bin/python && apt install git make gcc bison flex libssl-dev -y
	touch /.Checked
}

[ ! -d img_repack_tools ] && {
	echo "================================================================================"
	echo "准備下載 IMG 解包、打包工具"
	echo "================================================================================" && read -t 1
	git clone https://android.googlesource.com/platform/system/tools/mkbootimg img_repack_tools -b master-kernel-build-2022 --depth=1
	[ "$?" != 0 ] && {
		echo "================================================================================"
		echo "本次編譯中止！原因：IMG 解包、打包工具下載失敗"
		echo "================================================================================" && return 2> /dev/null || exit
	}
}

[ $SOURCE_BOOT_IMAGE_NEED_DOWNLOAD = true ] && {
	echo "================================================================================"
	echo "准備下載 IMG 備份文件"
	echo "================================================================================" && read -t 1
	wget -O boot-source.img $SOURCE_BOOT_IMAGE
}
[ ! -f boot-source.img -o "$SOURCE_BOOT_IMAGE_NEED_DOWNLOAD" = true -a "$?" != 0 ] && {
	echo "================================================================================" && rm -f boot-source.img
	echo "本次編譯中止！原因：IMG 備份文件不存在，請確認配置的下載地址可以用於正常直鏈下載，或手動將備份文件重命名為 boot-source.img 後放置到 $BULID_KERNEL_DIR 文件夾中"
	echo "================================================================================" && return 2> /dev/null || exit
}

[ ! -d $KERNEL_NAME-$KERNEL_SOURCE_BRANCH ] && {
	echo "================================================================================"
	echo "准備獲取安卓內核開源倉庫"
	echo "================================================================================" && read -t 1
	git clone $KERNEL_SOURCE -b $KERNEL_SOURCE_BRANCH $KERNEL_NAME-$KERNEL_SOURCE_BRANCH --depth=1
	git -C $KERNEL_NAME-$KERNEL_SOURCE_BRANCH submodule update --init
	[ "$?" != 0 ] && {
		echo "================================================================================" && rm -rf $KERNEL_NAME-$KERNEL_SOURCE_BRANCH
		echo "本次編譯中止！原因：安卓內核開源倉庫獲取失敗"
		echo "================================================================================" && return 2> /dev/null || exit
	}
}

[ ! -d $CLANG_DIR ] && {
	echo "================================================================================"
	echo "准備下載 Clang 編譯器"
	echo "================================================================================" && read -t 1
	wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/$CLANG_BRANCH/clang-$CLANG_VERSION.tar.gz
	[ "$?" != 0 ] && {
		wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/$CLANG_BRANCH/clang-$CLANG_VERSION.tar.gz
		[ "$?" != 0 ] && {
			echo "================================================================================" && rm -f clang-$CLANG_VERSION.tar.gz
			echo "本次編譯中止！原因：Clang 編譯器下載失敗"
			echo "================================================================================" && return 2> /dev/null || exit
		}
	}
	mkdir -p clang/$CLANG_BRANCH-$CLANG_VERSION
	tar -C clang/$CLANG_BRANCH-$CLANG_VERSION/ -zxvf clang-$CLANG_VERSION.tar.gz
	rm -f clang-$CLANG_VERSION.tar.gz 
}

[ -n "$GCC64" -a ! -d $GCC64_DIR -a "$GCC64_CUSTOM" != true ] && {
	echo "================================================================================"
	echo "准備下載 64 位 GCC 交叉編譯器"
	echo "================================================================================" && read -t 1
	wget -O gcc-$GCC64-64.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/heads/$GCC64.tar.gz
	[ "$?" != 0 ] && {
		wget -O gcc-$GCC64-64.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/$GCC64.tar.gz
		[ "$?" != 0 ] && {
			echo "================================================================================" && rm -f gcc-$GCC64-64.tar.gz
			echo "本次編譯中止！原因：64 位 GCC 交叉編譯器下載失敗"
			echo "================================================================================" && return 2> /dev/null || exit
		}
	}
	mkdir -p gcc/$GCC64-64
	tar -C gcc/$GCC64-64/ -zxvf gcc-$GCC64-64.tar.gz
	rm -f gcc-$GCC64-64.tar.gz
}
[ -n "$GCC32" -a ! -d $GCC32_DIR -a "$GCC32_CUSTOM" != true ] && {
	echo "================================================================================"
	echo "准備下載 32 位 GCC 交叉編譯器"
	echo "================================================================================" && read -t 1
	wget -O gcc-$GCC32-32.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/heads/$GCC32.tar.gz
	[ "$?" != 0 ] && {
		wget -O gcc-$GCC32-32.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/$GCC32.tar.gz
		[ "$?" != 0 ] && {
			echo "================================================================================" && rm -f gcc-$GCC32-32.tar.gz
			echo "本次編譯中止！原因：32 位 GCC 交叉編譯器下載失敗"
			echo "================================================================================" && return 2> /dev/null || exit
		}
	}
	mkdir -p gcc/$GCC32-32
	tar -C gcc/$GCC32-32/ -zxvf gcc-$GCC32-32.tar.gz
	rm -f gcc-$GCC32-32.tar.gz
}

cd $KERNEL_NAME-$KERNEL_SOURCE_BRANCH
echo "================================================================================" && num="" && SUMODE=""
echo "你想使用哪種方式加入 KernelSU 到內核中？"
[ ! -d [kK][eE][rR][nN][eE][lL][sS][uU] -o -f Need_KernelSU ] && {
	echo "1.使用 kprobe 集成（有可能編譯成功但無法開機，可以使用第二種方式進行嘗試）"
	echo "2.修改內核源碼（僅支持 KernelSU 0.6.1 或以上版本，0.6.0 或以下版本請用第一種方式進行嘗試）"
}
echo "3.不作任何修改直接編譯（第一次編譯建議先用此選項進行嘗試，如果編譯成功並能正常開機後再加入 KernelSU 進行重新編譯）"
[ -f retry ] && echo "4.上一次編譯可能各種原因中斷，接回上一次編譯進度繼續編譯（選這個確認是否每次都在同一個位置出錯）"
[ -f BUILD_KERNEL_COMPLETE -a -f Need_KernelSU ] && echo "5.編譯完成並 KernelSU 已能正常使用，但手機重啟後應用授權列表會丟失，選這裡嘗試使用修復方案"
[ -d KernelSU -a -f Need_KernelSU ] && echo "6.已手動修改完 KernelSU 代碼，直接編譯（跳過下載 KernelSU 源碼步驟，需要手動修改代碼修復問題時選這個）"
echo "7.已編譯完成，僅修改內核包名進行打包操作"
echo "0.退出本次編譯"
echo "================================================================================"

while [[ "$num" != [0-7] ]];do
	read -p "請輸入正確的數字 > " num
	case "$num" in
	1)
		SUMODE="使用 kprobe 集成"
		[ -d [kK][eE][rR][nN][eE][lL][sS][uU] -a ! -f Need_KernelSU ] && num="" && SUMODE=""
		;;
	2)
		SUMODE="修改內核源碼"
		[ -d [kK][eE][rR][nN][eE][lL][sS][uU] -a ! -f Need_KernelSU ] && num="" && SUMODE=""
		;;
	4)
		[ ! -f retry ] && num=""
		;;
	5)
		[ ! -f BUILD_KERNEL_COMPLETE -o ! -f Need_KernelSU ] && num=""
		;;
	6)
		[ ! -d KernelSU -o ! -f Need_KernelSU ] && num=""
		;;
	0)
		echo "================================================================================"
		echo "已退出本次編譯"
		echo "================================================================================" && return 2> /dev/null || exit
	esac
done

[[ "$num" = [1-2] ]] && {
	echo "================================================================================"
	echo "你想使用哪個版本的 KernelSU 加入到內核中？" && sunum="" && sutag="" && SUVERSION=""
	echo "1.最新版"
	echo "2.自定義輸入版本號"
	echo "0.退出本次編譯"
	echo "================================================================================"
	while [[ "$sunum" != [0-2] ]];do
		read -p "請輸入正確的數字 > " sunum
		case "$sunum" in
		1)
			SUVERSION="最新版"
			;;
		2)
			read -p "請直接輸入版本號，如：0.6.9 > " sutag
			sutag=v$sutag && SUVERSION="自定義輸入版本號 $sutag"
			;;
		0)
			echo "================================================================================"
			echo "已退出本次編譯"
			echo "================================================================================" && return 2> /dev/null || exit
		esac
	done
}

[[ "$num" = [1-3] ]] && {
	[ -f retry ] && rm -f retry
	[ -d KernelSU -a -f Need_KernelSU ] && rm -rf KernelSU drivers/kernelsu drivers/common/kernelsu
	[ -f drivers/Kconfig.backup ] && mv -f drivers/Kconfig.backup drivers/Kconfig 2> /dev/null
	[ -f drivers/Makefile.backup ] && mv -f drivers/Makefile.backup drivers/Makefile 2> /dev/null
	[ -f drivers/common/Kconfig.backup ] && mv -f drivers/common/Kconfig.backup drivers/common/Kconfig 2> /dev/null
	[ -f drivers/common/Makefile.backup ] && mv -f drivers/common/Makefile.backup drivers/common/Makefile 2> /dev/null
	[ -f arch/$ARCH/configs/$KERNEL_CONFIG.backup ] && mv -f arch/$ARCH/configs/$KERNEL_CONFIG.backup arch/$ARCH/configs/$KERNEL_CONFIG
	[ -f fs/exec.c.backup ] && mv -f fs/exec.c.backup fs/exec.c
	[ -f fs/read_write.c.backup ] && mv -f fs/read_write.c.backup fs/read_write.c
	[ -f fs/open.c.backup ] && mv -f fs/open.c.backup fs/open.c
	[ -f fs/stat.c.backup ] && mv -f fs/stat.c.backup fs/stat.c
	[ -f drivers/input/input.c.backup ] && mv -f drivers/input/input.c.backup drivers/input/input.c
}

[[ "$num" = [1-2] ]] && {
	[ ! -f NoneKernelSU ] && touch Need_KernelSU
	[ ! -f drivers/Kconfig.backup ] && cp drivers/Kconfig drivers/Kconfig.backup 2> /dev/null
	[ ! -f drivers/Makefile.backup ] && cp drivers/Makefile drivers/Makefile.backup 2> /dev/null
	[ ! -f drivers/common/Kconfig.backup ] && cp drivers/Kconfig drivers/common/Kconfig.backup 2> /dev/null
	[ ! -f drivers/common/Makefile.backup ] && cp drivers/Makefile drivers/common/Makefile.backup 2> /dev/null
	echo "================================================================================" && rm -rf out
	echo " 准備下載 KernelSU 源碼，請等候······"
	echo "================================================================================" && read -t 1
	if [ "${sutag::1}" = v ];then
		wget https://github.com/tiann/KernelSU/archive/refs/tags/$sutag.tar.gz
		[ "$?" != 0 ] && {
			echo "================================================================================"
			echo "本次編譯中止！原因：KernelSU $SUVERSION 源碼下載失敗，請確認是否有此版本存在"
			echo "================================================================================" && return 2> /dev/null || exit
		}
		tar -zxf $sutag.tar.gz
		mv -f `echo KernelSU-$sutag | sed 's/-v/-/'` KernelSU && rm $sutag.tar.gz
	else
		git clone https://github.com/tiann/KernelSU
		[ "$?" != 0 ] && {
			echo "================================================================================"
			echo "本次編譯中止！原因：KernelSU $SUVERSION 源碼下載失敗"
			echo "================================================================================" && return 2> /dev/null || exit
		}
		cd KernelSU;git checkout "$(git describe --abbrev=0 --tags)" &> /dev/null
		SUVERSION="$SUVERSION：$(grep $(cat .git/HEAD) .git/packed-refs | awk -F '/' {'print $3'} | tail -n1)";cd ..
	fi;
	if [ -d /common/drivers ];then
		ln -sf ../../KernelSU/kernel drivers/common/kernelsu
		grep -q kernelsu drivers/common/Makefile || echo "obj-\$(CONFIG_KSU)		+= kernelsu/" >> drivers/common/Makefile
		grep -q kernelsu drivers/common/Kconfig || sed -i "/endmenu/i\\source \"drivers/kernelsu/Kconfig\"\\n" drivers/common/Kconfig
	else
		ln -sf ../KernelSU/kernel drivers/kernelsu
		grep -q kernelsu drivers/Makefile || echo "obj-\$(CONFIG_KSU)		+= kernelsu/" >> drivers/Makefile
		grep -q kernelsu drivers/Kconfig || sed -i "/endmenu/i\\source \"drivers/kernelsu/Kconfig\"\\n" drivers/Kconfig
	fi
}

[ "$num" = 5 ] && {
	echo "================================================================================"
	echo "請選擇以下可用修復方案" && fixnum=""
	echo "1.嘗試修復開機後丟失用戶授權列表（ KernelSU 0.6.7 或以上版本）"
	echo "X.因為沒有其它有問題的設備用於測試，所以其它的修復代碼暫時不寫了，請自行參考下面地址"
	echo "X.其他有可能會遇到的問題解決方案：https://github.com/tiann/KernelSU/issues/943"
	echo "0.退出本次編譯"
	echo "================================================================================"
	while [[ "$fixnum" != [0-1] ]];do
		read -p "請輸入正確的數字 > " fixnum
		[ "$fixnum" = 0 ] && {
			echo "================================================================================"
			echo "已退出本次編譯"
			echo "================================================================================" && return 2> /dev/null || exit
		}
	done;rm -rf out
	[ -f KernelSU/kernel/core_hook.c.backup ] && mv -f KernelSU/kernel/core_hook.c.backup KernelSU/kernel/core_hook.c && mv -f KernelSU/kernel/kernel_compat.c.backup KernelSU/kernel/kernel_compat.c && mv -f KernelSU/kernel/kernel_compat.h.backup KernelSU/kernel/kernel_compat.h
}

[ "$num" = 1 ] && {
	[ ! -f arch/$ARCH/configs/$KERNEL_CONFIG.backup ] && cp arch/$ARCH/configs/$KERNEL_CONFIG arch/$ARCH/configs/$KERNEL_CONFIG.backup
	[ $DISABLE_LTO = true ] && {
		sed -i 's/CONFIG_LTO=y/CONFIG_LTO=n/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_LTO=y 已修改為 CONFIG_LTO=n" && read -t 1
		sed -i 's/CONFIG_LTO_CLANG=y/CONFIG_LTO_CLANG=n/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_LTO_CLANG=y 已修改為 CONFIG_LTO_CLANG=n" && read -t 1
		sed -i 's/CONFIG_THINLTO=y/CONFIG_THINLTO=n/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_THINLTO=y 已修改為 CONFIG_THINLTO=n" && read -t 1
		[ -z "$(grep CONFIG_LTO_NONE=y arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_LTO_NONE /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_LTO_NONE=y" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_LTO_NONE=y 已加入到配置文件中" && read -t 1
	}
	[ $DISABLE_CC_WERROR = true ] && {
		[ -z "$(grep CONFIG_CC_WERROR=n arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_CC_WERROR /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_CC_WERROR=n" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_CC_WERROR=n 已加入到配置文件中" && read -t 1
	}
	[ $ADD_KPROBES_CONFIG = true ] && {
		[ -z "$(grep CONFIG_MODULES=y arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_MODULES /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_MODULES=y" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_MODULES=y 已加入到配置文件中" && read -t 1
		[ -z "$(grep CONFIG_KPROBES=y arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_KPROBES /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_KPROBES=y" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_KPROBES=y 已加入到配置文件中" && read -t 1
		[ -z "$(grep CONFIG_HAVE_KPROBES=y arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_HAVE_KPROBES /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_HAVE_KPROBES=y" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_HAVE_KPROBES=y 已加入到配置文件中" && read -t 1
		[ -z "$(grep CONFIG_KPROBE_EVENTS=y arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_KPROBE_EVENTS /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_KPROBE_EVENTS=y" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_KPROBE_EVENTS=y 已加入到配置文件中" && read -t 1
	}
	[ $ADD_OVERLAYFS_CONFIG = true ] && {
		[ -z "$(grep CONFIG_OVERLAY_FS=y arch/$ARCH/configs/$KERNEL_CONFIG)" ] && sed -i 's/CONFIG_OVERLAY_FS /d/' arch/$ARCH/configs/$KERNEL_CONFIG && echo "CONFIG_OVERLAY_FS=y" >> arch/$ARCH/configs/$KERNEL_CONFIG && echo "參數 CONFIG_OVERLAY_FS=y 已加入到配置文件中" && read -t 1
	}
}

[ "$num" = 2 ] && {
	[ ! -f fs/exec.c.backup ] && cp fs/exec.c fs/exec.c.backup
	[ ! -f fs/read_write.c.backup ] && cp fs/read_write.c fs/read_write.c.backup
	[ ! -f fs/open.c.backup ] && cp fs/open.c fs/open.c.backup
	[ ! -f fs/stat.c.backup ] && cp fs/stat.c fs/stat.c.backup
	[ ! -f drivers/input/input.c.backup ] && cp drivers/input/input.c drivers/input/input.c.backup
	[ -n "$(grep 'static int do_execveat_common(int fd, struct filename \*filename,' fs/exec.c)" ] && {
		cat > add_sucode << EOF
extern bool ksu_execveat_hook __read_mostly;
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,
			void *envp, int *flags);
extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,
				 void *argv, void *envp, int *flags);
EOF
		line=$(($(sed -n '/static int do_execveat_common(int fd, struct filename \*filename,/=' fs/exec.c)-1))
		[ "$line" != -1 ] && sed -i ''$line'r add_sucode' fs/exec.c
		cat > add_sucode << EOF
	if (unlikely(ksu_execveat_hook))
		ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
	else
		ksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);
EOF
		line=$(($(sed -n '/return __do_execve_file(fd, filename, argv, envp, flags, NULL);/=' fs/exec.c)-1))
		[ "$line" != -1 ] && sed -i ''$line'r add_sucode' fs/exec.c
	}
	[ -n "$(grep 'ssize_t vfs_read(struct file \*file, char __user \*buf, size_t count, loff_t \*pos)' fs/read_write.c)" ] && {
		cat > add_sucode << EOF
extern bool ksu_vfs_read_hook __read_mostly;
extern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr,
			size_t *count_ptr, loff_t **pos);
EOF
		line=$(($(sed -n '/ssize_t vfs_read(struct file \*file, char __user \*buf, size_t count, loff_t \*pos)/=' fs/read_write.c)-1))
		[ "$line" != -1 ] && sed -i ''$line'r add_sucode' fs/read_write.c
		cat > add_sucode << EOF
	if (unlikely(ksu_vfs_read_hook))
		ksu_handle_vfs_read(&file, &buf, &count, &pos);
EOF
		line=$(($(sed -n '/ssize_t vfs_read(struct file \*file, char __user \*buf, size_t count, loff_t \*pos)/=' fs/read_write.c)+3))
		[ "$line" != 3 ] && sed -i ''$line'r add_sucode' fs/read_write.c
	}
	[ -n "$(grep '\* access() needs to use the real uid\/gid, not the effective uid\/gid.' fs/open.c)" ] && {
		cat > add_sucode << EOF
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,
			 int *flags);
EOF
		line=$(($(sed -n '/\* access() needs to use the real uid\/gid, not the effective uid\/gid./=' fs/open.c)-2))
		[ "$line" != -2 ] && sed -i ''$line'r add_sucode' fs/open.c
		cat > add_sucode << EOF
	ksu_handle_faccessat(&dfd, &filename, &mode, NULL);
EOF
		if [ -n "$(grep 'long do_faccessat(int dfd, const char __user \*filename, int mode)' fs/open.c)" ];then
			line=$(($(sed -n '/long do_faccessat(int dfd, const char __user \*filename, int mode)/=' fs/open.c)+1))
			[ "$line" != 1 ] && sed -i ''$line'r add_sucode' fs/open.c
		elif [ -n "$(grep "if (mode & ~S_IRWXO)	/\* where's F_OK, X_OK, W_OK, R_OK? \*/" fs/open.c)" ];then
			line=$(($(sed -n "/if (mode & ~S_IRWXO)	\/\* where's F_OK, X_OK, W_OK, R_OK? \*\//=" fs/open.c)-1))
			[ "$line" != -1 ] && sed -i ''$line'r add_sucode' fs/open.c
		fi
	}
	cat > add_sucode << EOF
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);
EOF
	cat > add_sucode2 << EOF
	ksu_handle_stat(&dfd, &filename, &flags);
EOF
	if [ -n "$(grep 'EXPORT_SYMBOL(vfs_statx_fd);' fs/stat.c)" ];then
		line=$(($(sed -n '/EXPORT_SYMBOL(vfs_statx_fd);/=' fs/stat.c)+1))
		[ "$line" != 1 ] && sed -i ''$line'r add_sucode' fs/stat.c
		line=$(($(sed -n '/if ((flags & ~(AT_SYMLINK_NOFOLLOW | AT_NO_AUTOMOUNT |/=' fs/stat.c)-1))
		[ "$line" != -1 ] && sed -i ''$line'r add_sucode2' fs/stat.c
	elif [ -n "$(grep 'EXPORT_SYMBOL(vfs_fstat);') fs/stat.c" ];then
		line=$(($(sed -n '/EXPORT_SYMBOL(vfs_fstat);/=' fs/stat.c)+1))
		[ "$line" != 1 ] && sed -i ''$line'r add_sucode' fs/stat.c
		line=$(($(sed -n '/if ((flag & ~(AT_SYMLINK_NOFOLLOW | AT_NO_AUTOMOUNT |/=' fs/stat.c)-1))
		[ "$line" != -1 ] && sed -i ''$line'r add_sucode2' fs/stat.c
	fi
	
	[ -n "$(grep 'static void input_handle_event(struct input_dev \*dev,' drivers/input/input.c)" ] && {
		cat > add_sucode << EOF
extern bool ksu_input_hook __read_mostly;
extern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);
EOF
		line=$(($(sed -n '/static void input_handle_event(struct input_dev \*dev,/=' drivers/input/input.c)-1))
		[ "$line" != -1 ] && sed -i ''$line'r add_sucode' drivers/input/input.c
		cat > add_sucode << EOF
	if (unlikely(ksu_input_hook))
		ksu_handle_input_handle_event(&type, &code, &value);
EOF
		line=$(($(sed -n '/static void input_handle_event(struct input_dev \*dev,/=' drivers/input/input.c)+3))
		[ "$line" != 3 ] && sed -i ''$line'r add_sucode' drivers/input/input.c
	}
	rm -f add_sucode add_sucode2
}

[ "$fixnum" = 1 ] && {
	[ ! -f KernelSU/kernel/core_hook.c.backup ] && \
	cp KernelSU/kernel/core_hook.c KernelSU/kernel/core_hook.c.backup && \
	cp KernelSU/kernel/kernel_compat.c KernelSU/kernel/kernel_compat.c.backup && \
	cp KernelSU/kernel/kernel_compat.h KernelSU/kernel/kernel_compat.h.backup
	sed -i 's/LINUX_VERSION_CODE < KERNEL_VERSION(4, 10, 0)/1/' KernelSU/kernel/core_hook.c KernelSU/kernel/kernel_compat.c KernelSU/kernel/kernel_compat.h
}

[[ "$num" = [1-3,5-6] ]] && {
	[ -d out ] && {
	#	echo "================================================================================"
	#	echo "檢測到有上一次編譯留下的文件，可能會影響編譯結果，是否刪除？" && del=""
	#	echo "1.確認刪除"
	#	echo "0.跳過，繼續編譯"
	#	echo "================================================================================"
	#	while [[ "$del" != [0-1] ]];do
	#		read -p "請輸入正確的數字 > " del
	#		[ "$del" = 1 ] && {
				rm -rf out
				echo "================================================================================"
				echo " 文件夾 $BULID_KERNEL_DIR/$KERNEL_NAME-$KERNEL_SOURCE_BRANCH/out 已刪除"
				echo "================================================================================" && read -t 1
	#		}
	#	done
	}
}

[ "$num" != 7 ] && {
	export SUBARCH=$ARCH
	export PATH=$CLANG_DIR:$PATH
	[ -n "$GCC64_DIR" ] && export PATH=$GCC64_DIR:$PATH
	[ -n "$GCC32_DIR" ] && export PATH=$GCC32_DIR:$PATH
	[ -f BUILD_KERNEL_COMPLETE ] && rm -f BUILD_KERNEL_COMPLETE
	[ "$num" != 4 ] && make -j$(nproc --all) O=out $BUILDKERNEL_CMDS $KERNEL_CONFIG
	touch retry && num="";make -j$(nproc --all) O=out $BUILDKERNEL_CMDS
	if [ "$?" = 0 ];then
		[ -d KernelSU -a -f Need_KernelSU ] && touch BUILD_KERNEL_COMPLETE
		echo "================================================================================"
		echo "內核倉庫：$KERNEL_SOURCE"
		echo "倉庫分支：$KERNEL_SOURCE_BRANCH"
		[ "$CLANG_CUSTOM" = true ] && \
		echo "自定義 Clang 編譯器：$CLANG_DIR" || \
		echo "Clang 編譯器：$CLANG_BRANCH-$CLANG_VERSION"
		[ "$GCC64_CUSTOM" = true ] && \
		echo "自定義 64 位 Gcc 交叉編譯器：$GCC64_DIR" || \
		echo "64 位 Gcc 交叉編譯器：$GCC64"
		[ "$GCC32_CUSTOM" = true ] && \
		echo "自定義 32 位 Gcc 交叉編譯器：$GCC32_DIR" || \
		echo "32 位 Gcc 交叉編譯器：$GCC32"
		echo "加入 KernelSU 方式：$SUMODE"
		echo "加入 KernelSU 版本：$SUVERSION"
		echo "本次編譯使用指令：make -j$(nproc --all) O=out $(echo $BUILDKERNEL_CMDS | sed ':i;N;s/\n/ /;ti')"
		echo "================================================================================"
		echo "編譯成功！將進行 boot.img 文件重新打包"
		echo "================================================================================" && num=7 && rm -f retry && read -t 3
	else
		echo "================================================================================"
		echo "內核倉庫：$KERNEL_SOURCE"
		echo "倉庫分支：$KERNEL_SOURCE_BRANCH"
		[ "$CLANG_CUSTOM" = true ] && \
		echo "自定義 Clang 編譯器：$CLANG_DIR" || \
		echo "Clang 編譯器：$CLANG_BRANCH-$CLANG_VERSION"
		[ "$GCC64_CUSTOM" = true ] && \
		echo "自定義 64 位 Gcc 交叉編譯器：$GCC64_DIR" || \
		echo "64 位 Gcc 交叉編譯器：$GCC64"
		[ "$GCC32_CUSTOM" = true ] && \
		echo "自定義 32 位 Gcc 交叉編譯器：$GCC32_DIR" || \
		echo "32 位 Gcc 交叉編譯器：$GCC32"
		echo "加入 KernelSU 方式：$SUMODE"
		echo "加入 KernelSU 版本：$SUVERSION"
		echo "本次編譯使用指令：make -j$(nproc --all) O=out $(echo $BUILDKERNEL_CMDS | sed ':i;N;s/\n/ /;ti')"
		echo "================================================================================"
		echo "編譯失敗！請自行根據上面編譯過程中的提示檢查錯誤"
		echo "若非每次都在同一個地方出錯，有可能是系統內存不足導致卡機失敗"
		echo "可以直接重新編譯進行嘗試，如果是用虛擬機編譯請盡量分配多一點的內存給虛擬機"
		echo "如果只提示（make[*]: *** [*****/*****：*****] 錯誤 *）"
		echo "但這條信息的上面沒有明確提示什麼錯誤的，很有可能是這個內核倉庫源碼本身有問題"
		echo "================================================================================"
	fi;
}

[ "$num" = 7 ] && {
	cd $BULID_KERNEL_DIR && KERNEL_IMAGE_NAME=""
	while [ ! -f $KERNEL_NAME-$KERNEL_SOURCE_BRANCH/out/arch/$ARCH/boot/$KERNEL_IMAGE_NAME ];do
		echo "================================================================================" && image=""
		[ -n "$KERNEL_IMAGE_NAME" ] && echo "內核 $KERNEL_NAME-$KERNEL_SOURCE_BRANCH/out/arch/$ARCH/boot/$KERNEL_IMAGE_NAME 文件不存在！請重新選擇內核文件名" || \
		echo "哪一個是編譯出來的內核文件？這將會用於打包 boot.img（一般就下面三個其中一個，不知道的可以逐個嘗試）"
		echo "1.Image"
		echo "2.Image.gz"
		echo "3.Image.gz-dtb"
		echo "4.自定義輸入"
		echo "0.退出打包操作"
		echo "================================================================================"
		while [[ "$image" != [0-4] ]];do
			read -p "請輸入正確的數字 > " image
			case "$image" in
			1)
				KERNEL_IMAGE_NAME=Image
				;;
			2)
				KERNEL_IMAGE_NAME=Image.gz
				;;
			3)
				KERNEL_IMAGE_NAME=Image.gz-dtb
				;;
			4)
				read -p "請輸入編譯出來後的內核文件的名稱： > " KERNEL_IMAGE_NAME
				;;
			0)
				echo "================================================================================"
				echo "已退出本次打包操作"
				echo "================================================================================" && return 2> /dev/null || exit
			esac
		done
	done
	img_repack_tools/unpack_bootimg.py --boot_img boot-source.img --format mkbootimg --out=img_repack_tools/out > BuildBootInfo 2> /dev/null
	[ "$?" != 0 ] && {
		echo "================================================================================" && rm -f BuildBootInfo
		echo "本次打包中止！原因：boot-source.img 文件錯誤（可能未完全下載成功？）"
		echo "================================================================================" && return 2> /dev/null || exit
	}
	echo "cp $KERNEL_NAME-$KERNEL_SOURCE_BRANCH/out/arch/$ARCH/boot/$KERNEL_IMAGE_NAME img_repack_tools/out/kernel" >> BuildBoot
	echo "img_repack_tools/mkbootimg.py $(cat BuildBootInfo) -o boot.img" >> BuildBoot
	echo "================================================================================" && source BuildBoot
	echo "打包成功！打包後的 boot.img 文件已存放於 $BULID_KERNEL_DIR 中"
	echo "fastboot 刷入時建議不要直接加入 flash 參數來進行刷入，等能開機了再真正刷入到手機"
	echo "刷入手機後首次開機可能會比較慢，請耐心等候"
	echo "如果加入 KernelSU 後能正常使用，但有各種小問題，可再運行本腳本選 5 嘗試進行修復"
	echo "腳本制作不易，如果本腳本對你有用，希望能打賞支持一下！非常感謝！！！"
	echo "支持一下：https://github.com/xilaochengv/BuildKernelSU"
	echo "================================================================================" && rm -f BuildBootInfo BuildBoot
}