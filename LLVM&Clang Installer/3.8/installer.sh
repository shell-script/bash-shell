#!/bin/bash

# Dependency: swig libedit Python

# ======================================= 配置 =======================================
LLVM_VERSION=3.8.1;
PREFIX_DIR=/usr/local/llvm-$LLVM_VERSION;
BUILD_TARGET_COMPOMENTS="llvm clang compiler_rt libcxx libcxxabi clang_tools_extra lldb lld";
BUILD_GCC="gcc-4.6";

# ======================= 非交叉编译 ======================= 
BUILD_LLVM_CONF_OPTION="--enable-optimized --disable-assertions";
BUILD_LLVM_CMAKE_OPTION="-DLLVM_ENABLE_CXX1Y=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_PIC=ON -DLLVM_ENABLE_LTO=On -DLIBCXX_ENABLE_EXCEPTIONS=ON -DLIBCXX_ENABLE_RTTI=ON -DBUILD_SHARED_LIBS=ON";
BUILD_LLVM_CMAKE_OPTION_STAGE_3=""; #  -DBUILD_SHARED_LIBS=ON";
BUILD_OTHER_CONF_OPTION="";
 
# ======================= 交叉编译配置示例(暂不可用) ======================= 
  
# ======================================= 检测 ======================================= 
 
# ======================= 检测完后等待时间 ======================= 
CHECK_INFO_SLEEP=3
 
# ======================= 安装目录初始化/工作目录清理 ======================= 
while getopts "p:cht:l:g:m:" OPTION; do
    case $OPTION in
        p)
            PREFIX_DIR="$OPTARG";
        ;;
        c)
            rm -rf $(ls -A -d -p * | grep -E "(.*)/$" | grep -v "addition/");
            echo -e "\\033[32;1mnotice: clear work dir(s) done.\\033[39;49;0m";
            exit 0;
        ;;
        h)
            echo "usage: $0 [options] -p=prefix_dir -c -h";
            echo "options:";
            echo "-p [prefix_dir]             set prefix directory.";
            echo "-c                          clean build cache.";
            echo "-h                          help message.";
            echo "-t [build target]           set build target(llvm clang compiler_rt libcxx libcxxabi lldb polly openmp clang_tools_extra llvm_test_suite)."; # dragonegg safecode 
            echo "-l [llvm cpnfigure option]  add llvm build options.";
            echo "-m [llvm cmake option]      add llvm build options.";
            echo "-g [gnu option]             add gcc,binutils,gdb build options.";
            exit 0;
        ;;
        t)
            if [ "+" == "${OPTARG:0:1}" ]; then
                BUILD_TARGET_COMPOMENTS="$BUILD_TARGET_COMPOMENTS ${OPTARG:1}";
			else
				BUILD_TARGET_COMPOMENTS="$OPTARG";
            fi
        ;;
        l)
            BUILD_LLVM_CONF_OPTION="$BUILD_LLVM_CONF_OPTION $OPTARG";
        ;;
        m)
            BUILD_LLVM_CMAKE_OPTION="$BUILD_LLVM_CMAKE_OPTION $OPTARG";
        ;;
        g)
            BUILD_TARGET_CONF_OPTION="$BUILD_TARGET_CONF_OPTION $OPTARG";
        ;;
        ?)  #当有不认识的选项的时候arg为?
            echo "unkonw argument detected";
            exit 1;
        ;;
    esac
done

mkdir -p "$PREFIX_DIR"
PREFIX_DIR="$( cd "$PREFIX_DIR" && pwd )";

# llvm 脚本fix 
BUILD_LLVM_CONF_OPTION="$BUILD_LLVM_CONF_OPTION -DLLVM_PREFIX=$PREFIX_DIR";

# ======================= 转到脚本目录 ======================= 
WORKING_DIR="$PWD";

# ======================= 如果是64位系统且没安装32位的开发包，则编译要gcc加上 --disable-multilib 参数, 不生成32位库 ======================= 
SYS_LONG_BIT=$(getconf LONG_BIT);
 
# ======================= 检测CPU数量，编译线程数不能大于CPU数量的2倍，否则可能出问题 ======================= 
BUILD_THREAD_OPT=1;
BUILD_CPU_NUMBER=$(cat /proc/cpuinfo | grep -c "^processor[[:space:]]*:[[:space:]]*[0-9]*");
BUILD_THREAD_OPT=$(($BUILD_CPU_NUMBER));
if [ $BUILD_THREAD_OPT -gt 4 ]; then
    BUILD_THREAD_OPT=4;
fi
BUILD_THREAD_OPT="-j$BUILD_THREAD_OPT";
echo -e "\\033[32;1mnotice: $BUILD_CPU_NUMBER cpu(s) detected. use $BUILD_THREAD_OPT for multi-thread compile.";
 
# ======================= 统一的包检查和下载函数 ======================= 
function check_and_download(){
    PKG_NAME="$1";
    PKG_MATCH_EXPR="$2";
    PKG_URL="$3";
     
    PKG_VAR_VAL=$(ls -d $PKG_MATCH_EXPR);
    if [ ! -z "$PKG_VAR_VAL" ]; then
        echo "$PKG_VAR_VAL"
        return 0;
    fi
     
    if [ -z "$PKG_URL" ]; then
        echo -e "\\033[31;1m$PKG_NAME not found.\\033[39;49;0m" 
        return -1;
    fi
     
    wget -c "$PKG_URL";
    PKG_VAR_VAL=$(ls -d $PKG_MATCH_EXPR);
     
    if [ -z "$PKG_VAR_VAL" ]; then
        echo -e "\\033[31;1m$PKG_NAME not found.\\033[39;49;0m" 
        return -1;
    fi
     
    echo "$PKG_VAR_VAL";
}

# ======================= 列表检查函数 ======================= 
function is_in_list() {
    ele="$1";
    shift;

    for i in $*; do
        if [ "$ele" == "$i" ]; then
            echo 0;
            exit 0;
        fi
    done

    echo 1;
    exit 1;
}
 
# ======================================= 搞起 ======================================= 
echo -e "\\033[31;1mcheck complete.\\033[39;49;0m"
 
# ======================= 准备环境, 把库和二进制目录导入，否则编译会找不到库或文件 ======================= 
echo "WORKING_DIR = $WORKING_DIR";
echo "PREFIX_DIR = $PREFIX_DIR";
echo "BUILD_TARGET_COMPOMENTS = $BUILD_TARGET_COMPOMENTS";
echo "BUILD_LLVM_CONF_OPTION = $BUILD_LLVM_CONF_OPTION";
echo "BUILD_LLVM_CMAKE_OPTION = $BUILD_LLVM_CMAKE_OPTION";
echo "BUILD_OTHER_CONF_OPTION = $BUILD_OTHER_CONF_OPTION";
echo "CHECK_INFO_SLEEP = $CHECK_INFO_SLEEP";
echo "BUILD_CPU_NUMBER = $BUILD_CPU_NUMBER";
echo "BUILD_THREAD_OPT = $BUILD_THREAD_OPT";
echo "SYS_LONG_BIT = $SYS_LONG_BIT";
 
echo -e "\\033[32;1mnotice: now, sleep for $CHECK_INFO_SLEEP seconds.\\033[39;49;0m"; 
sleep $CHECK_INFO_SLEEP
  
# ======================= 关闭交换分区，否则就爽死了 ======================= 
swapoff -a
 
# unpack llvm
if [ "0" == $(is_in_list llvm $BUILD_TARGET_COMPOMENTS) ]; then
    LLVM_PKG=$(check_and_download "llvm" "llvm-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/llvm-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$LLVM_PKG";
        exit -1;
    fi
    tar -axvf $LLVM_PKG;
fi
LLVM_SRC_DIR_NAME=$(ls -d llvm-* | grep -v \.tar\.xz);

if [ "" == "$LLVM_SRC_DIR_NAME" ]; then
	echo -e "\\033[31;1mError: build llvm src dir not found.\\033[39;49;0m";
	exit -1;
fi
LLVM_DIR="$WORKING_DIR/$LLVM_SRC_DIR_NAME";

# unpack clang
if [ "0" == $(is_in_list clang $BUILD_TARGET_COMPOMENTS) ]; then
    CLANG_PKG=$(check_and_download "clang" "cfe-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/cfe-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$CLANG_PKG";
        exit -1;
    fi
    if [ ! -e "$LLVM_DIR/tools/clang" ]; then
    	tar -axvf $CLANG_PKG;
    	CLANG_DIR=$(ls -d cfe-* | grep -v \.tar\.xz);
    	mv "$CLANG_DIR" "$LLVM_DIR/tools/clang";
	fi
fi
CLANG_DIR="$LLVM_DIR/tools/clang";

   
# unpack clang tools extra
if [ "0" == $(is_in_list clang_tools_extra $BUILD_TARGET_COMPOMENTS) ]; then
    CLANG_TOOLS_EXTRA_PKG=$(check_and_download "clang tools extra" "clang-tools-extra-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/clang-tools-extra-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$CLANG_TOOLS_EXTRA_PKG";
        exit -1;
    fi
    
    if [ ! -e "$CLANG_DIR/tools/extra" ]; then
	    tar -axvf $CLANG_TOOLS_EXTRA_PKG;
    	CLANG_TOOLS_EXTRA_DIR=$(ls -d clang-tools-extra-* | grep -v \.tar\.xz);
    	mv "$CLANG_TOOLS_EXTRA_DIR" "$CLANG_DIR/tools/extra";
	fi
	
    if [ ! -e "$CLANG_DIR/tools/extra" ]; then
    	echo -e "\\033[31;1mclang src not found but clang tools extra enabled.\\033[39;49;0m";
    	exit -1;
	fi
fi
CLANG_TOOLS_EXTRA_DIR="$CLANG_DIR/tools/extra";
  
# unpack compiler rt
if [ "0" == $(is_in_list compiler_rt $BUILD_TARGET_COMPOMENTS) ]; then
    COMPILER_RT_PKG=$(check_and_download "compiler rt" "compiler-rt-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/compiler-rt-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$COMPILER_RT_PKG";
        exit -1;
    fi

    if [ ! -e "$LLVM_DIR/projects/compiler-rt" ]; then
	    tar -axvf $COMPILER_RT_PKG;
    	COMPILER_RT_DIR=$(ls -d compiler-rt-* | grep -v \.tar\.xz);
    	mv "$COMPILER_RT_DIR" "$LLVM_DIR/projects/compiler-rt";
	fi
	
    if [ ! -e "$LLVM_DIR/projects/compiler-rt" ]; then
    	echo -e "\\033[31;1mcompiler-rt src not found but compiler-rt enabled.\\033[39;49;0m";
    	exit -1;
	fi
fi
COMPILER_RT_DIR="$LLVM_DIR/projects/compiler-rt";

LLVM_BUILD_DIR="$LLVM_DIR/build";

function build_llvm() {
	LLVM_BUILD_DIR="$LLVM_DIR/build";
    if [ -e "$LLVM_BUILD_DIR" ]; then
		rm -rf "$LLVM_BUILD_DIR";
	fi

	MAKE_TOOLS="$1";
	shift;
	STAGE_STEP_NAME="Stage $1";
	shift;
    STAGE_PREFIX_DIR="$1";
    shift;
    LLVM_TOOLS_BIN_DIR="$1";
    shift;
	
	mkdir -p "$LLVM_BUILD_DIR";
	cd "$LLVM_BUILD_DIR";
	echo -e "\\033[32;1m$STAGE_STEP_NAME: start to build llvm\\033[39;49;0m";
	
	for any_file in $(ls *); do
		echo "remove old cache file $any_file";
		rm -rf $any_file;
	done
	
	# llvm 源码有bug，会导致开启exception时编译通不过，所以修正一下 
	# perl -p -i -e "s;::name\(\)\s*const\s*[{];::name\(\) const LLVM_NOEXCEPT {;g" $(find "$LLVM_DIR" -name Error.cpp);

    CLANG_PREFIX_FLAGS="";
    if [ "0" == $(is_in_list lld $BUILD_TARGET_COMPOMENTS) ]; then
        CLANG_PREFIX_FLAGS=(CMAKE_CXX_LINK_EXECUTABLE=lld CMAKE_C_LINK_EXECUTABLE=lld);
    fi
            
	sleep 1;
    USING_NANJA="";
    
    #which ninja;
    #if [ 0 -eq $? ]; then
    #    USING_NANJA="-G Ninja";
    #fi

    export LDFLAGS="-pthread -ldl";
	if [ "${MAKE_TOOLS}" == "cmake" ]; then
		cmake $USING_NANJA -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=$STAGE_PREFIX_DIR $BUILD_LLVM_CMAKE_OPTION "$@" ..;
	elif [ "${MAKE_TOOLS}" == "cmake_clang" ]; then
        export LDFLAGS="$LDFLAGS -lc++ -lc++abi";
		CC=clang CXX=clang++ cmake $USING_NANJA -D_CMAKE_TOOLCHAIN_PREFIX=llvm- -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_TOOLS_BINARY_DIR=$LLVM_TOOLS_BIN_DIR/bin -DCMAKE_INSTALL_PREFIX=$STAGE_PREFIX_DIR ${CLANG_PREFIX_FLAGS[@]} $BUILD_LLVM_CMAKE_OPTION "$@" ..;
	elif [ "${MAKE_TOOLS}" == "automake_clang" ]; then
        export LDFLAGS="$LDFLAGS -lc++ -lc++abi";
		CC=clang CXX=clang++ CXXFLAGS="-stdlib=libc++" ../configure --prefix=$STAGE_PREFIX_DIR ${CLANG_PREFIX_FLAGS[@]} $BUILD_LLVM_CONF_OPTION $@;
	else
		../configure --prefix=$STAGE_PREFIX_DIR $BUILD_LLVM_CONF_OPTION $@;
	fi 

    if [ ${#USING_NANJA} -gt 0 ]; then
        ninja clean;
        ninja $BUILD_THREAD_OPT;
        mkdir -p lib/python2.7;
        ninja install;
    else
        make clean;
        make $BUILD_THREAD_OPT; 

	    # 这也是llvm的install脚本写得2b才加的hack
	    mkdir -p lib/python2.7;
        make install;
    fi

	if [ $? -ne 0 ]; then
	    echo -e "\\033[31;1mError: build llvm failed in $STAGE_STEP_NAME.\\033[39;49;0m";
	    exit -1;
	fi
	cd "$WORKING_DIR";
}

# unpack lld
if [ "0" == $(is_in_list lld $BUILD_TARGET_COMPOMENTS) ]; then
    LLD_PKG=$(check_and_download "lld" "lld-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/lld-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$LLD_PKG";
        exit -1;
    fi

    if [ ! -e "$LLVM_DIR/tools/lld" ]; then
	    tar -axvf $LLD_PKG;
    	LLD_DIR=$(ls -d lld-* | grep -v \.tar\.xz);
    	mv "$LLD_DIR" "$LLVM_DIR/tools/lld";
	fi
	
	if [ ! -e "$LLVM_DIR/tools/lld" ]; then
    	echo -e "\\033[31;1mlld src not found but lld enabled.\\033[39;49;0m";
    	exit -1;
	fi
fi
LLD_DIR="$LLVM_DIR/tools/lld";


# unpack polly (require gmp,cloog-isl)
if [ "0" == $(is_in_list polly $BUILD_TARGET_COMPOMENTS) ]; then
    POLLY_PKG=$(check_and_download "polly" "polly-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/polly-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$POLLY_PKG";
        exit -1;
    fi

    if [ ! -e "$LLVM_DIR/tools/polly" ]; then
	    tar -axvf $POLLY_PKG;
    	POLLY_DIR=$(ls -d polly-* | grep -v \.tar\.xz);
    	mv "$POLLY_DIR" "$LLVM_DIR/tools/polly";
	fi
	
	if [ ! -e "$LLVM_DIR/tools/polly" ]; then
    	echo -e "\\033[31;1mpolly src not found but polly enabled.\\033[39;49;0m";
    	exit -1;
	fi
	
	export BASE=$WORKING_DIR;
	export LLVM_SRC=$LLVM_DIR;
	export POLLY_SRC=$LLVM_DIR/tools/polly;
	
	export CLANG_SRC=$CLANG_DIR;
	
	# install gmp
	# install cloog
	export CLOOG_SRC=$BASE/cloog_src;
	export CLOOG_INSTALL=$PREFIX_DIR;
	
	$POLLY_SRC/utils/checkout_cloog.sh $CLOOG_SRC;
	cd $CLOOG_SRC;
	./configure --prefix=$CLOOG_INSTALL;
	make $BUILD_THREAD_OPT;
	make install;
	if [ $? -ne 0 ]; then
	    echo -e "\\033[31;1mError: build cloog failed in polly.\\033[39;49;0m";
	    exit -1;
	fi
	cd "$WORKING_DIR";
	
	export LLVM_BUILD=$LLVM_BUILD_DIR;
fi
POLLY_DIR="$LLVM_DIR/tools/polly";

# openmp 集成在clang内，略过
# llvm_test_suite 略过

# build dragonegg
if [ ! -z "$BUILD_GCC" ] && [ "0" == $(is_in_list dragonegg $BUILD_TARGET_COMPOMENTS) ]; then
    DRAGONEGG_PKG=$(check_and_download "dragonegg" "dragonegg-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/dragonegg-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$DRAGONEGG_PKG";
        exit -1;
    fi

	tar -axvf $DRAGONEGG_PKG;
    DRAGONEGG_DIR=$(ls -d dragonegg-* | grep -v \.tar\.xz);
    mv "$DRAGONEGG_DIR" "$LLVM_DIR/projects/dragonegg";
fi

STAGE_PREFIX_DIR="$WORKING_DIR/stage_1";
# 初始包准备完毕-开始第一次编译
# Stage 1 -- compiling llvm & clang using gcc
if [ -e "$STAGE_PREFIX_DIR/bin/clang" ]; then
    echo -e "\\033[31;1mStage 1: Already built, skip building.\\033[39;49;0m";
else
    echo -e "\\033[31;1mStage 1: Ready to compile llvm, clang and etc. using gcc.\\033[39;49;0m";
    build_llvm "cmake" 1 "$STAGE_PREFIX_DIR" ""; # -DLLVM_ENABLE_LIBCXX=ON;
fi

# 编译 libcxx 和libcxxabi
export LD_LIBRARY_PATH=$STAGE_PREFIX_DIR/lib:$LD_LIBRARY_PATH
export PATH=$STAGE_PREFIX_DIR/bin:$PATH

echo "add $STAGE_PREFIX_DIR/bin to PTAH";
echo "add $STAGE_PREFIX_DIR/lib to LD_LIBRARY_PATH";

# LLVM_DIR_BAK="$LLVM_DIR";
# LLVM_DIR="$WORKING_DIR/llvm.libcxx.src";

# unpack llvm
# if [ "0" == $(is_in_list llvm $BUILD_TARGET_COMPOMENTS) ]; then
#     mkdir -p "$LLVM_DIR";
#     cd "$LLVM_DIR";
#     tar -axvf ../$LLVM_PKG;
#     mv -f $LLVM_SRC_DIR_NAME/* ./;
#     rm -rf $LLVM_SRC_DIR_NAME;
#     cd "$WORKING_DIR";
# fi

# Stage 2 -- compiling tools
# STAGE_PREFIX_DIR="$WORKING_DIR/stage_2";
echo -e "\\033[31;1mStage 2: Compile libcxx & libcxxabi. using llvm & clang.\\033[39;49;0m";

# unpack libcxxabi
if [ "0" == $(is_in_list libcxxabi $BUILD_TARGET_COMPOMENTS) ]; then
    LIBCXXABI_PKG=$(check_and_download "libc++abi" "libcxxabi-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/libcxxabi-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$LIBCXXABI_PKG";
        exit -1;
    fi
    
    tar -axvf $LIBCXXABI_PKG;
    LIBCXXABI_DIR=$(ls -d libcxxabi-* | grep -v \.tar\.xz);
fi

# unpack libcxx
if [ "0" == $(is_in_list libcxx $BUILD_TARGET_COMPOMENTS) ]; then
    LIBCXX_PKG=$(check_and_download "libc++" "libcxx-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/libcxx-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$LIBCXX_PKG";
        exit -1;
    fi

	tar -axvf $LIBCXX_PKG;
	LIBCXX_DIR=$(ls -d libcxx-* | grep -v \.tar\.xz);
    mkdir -p $LIBCXX_DIR/build;
fi

export LD_LIBRARY_PATH=$PREFIX_DIR/lib:$LD_LIBRARY_PATH
export PATH=$PREFIX_DIR/bin:$PATH

echo "add $PREFIX_DIR/bin to PTAH";
echo "add $PREFIX_DIR/lib to LD_LIBRARY_PATH";

mkdir -p $LIBCXXABI_DIR/build;
cd $LIBCXXABI_DIR/build;
cmake .. -DLLVM_PATH="$LLVM_DIR" -DLIBCXXABI_LIBCXX_PATH="$WORKING_DIR/$LIBCXX_DIR" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR;
if [ 0 -ne $? ]; then
    echo "cmake .. -DLLVM_PATH=$LLVM_DIR -DLIBCXXABI_LIBCXX_PATH=$WORKING_DIR/$LIBCXX_DIR -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR";
    echo -e "\\033[33;1mStage 2: Configure libcxxabi failed\\033[39;49;0m";
    exit -1;
fi
make $BUILD_THREAD_OPT install;
if [ 0 -ne $? ]; then
    echo -e "\\033[33;1mStage 2: Build libcxxabi failed\\033[39;49;0m";
    exit -1;
fi
cd -;
LIBCXXABI_INC_DIR=$(find "$WORKING_DIR/$LIBCXXABI_DIR/include" -name cxxabi.h);
LIBCXXABI_INC_DIR="${LIBCXXABI_INC_DIR%%/cxxabi.h}";
echo "LIBCXX_CXX_ABI_INCLUDE_PATHS=$LIBCXXABI_INC_DIR";

cd $LIBCXX_DIR/build;
cmake .. -DLLVM_PATH="$LLVM_DIR" -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_CXX_ABI_INCLUDE_PATHS=$LIBCXXABI_INC_DIR -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR ;
if [ 0 -ne $? ]; then
    echo "cmake .. -DLLVM_PATH=$LLVM_DIR -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_CXX_ABI_INCLUDE_PATHS=$LIBCXXABI_INC_DIR -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR";
    echo -e "\\033[31;1mStage 2: Configure libcxx failed\\033[39;49;0m";
    exit -1;
fi
if [ 0 -ne $? ]; then
    echo -e "\\033[33;1mStage 2: Build libcxx failed\\033[39;49;0m";
    exit -1;
fi
make $BUILD_THREAD_OPT install;
cd -;

# LLVM_DIR="$LLVM_DIR_BAK";
## unpack lldb, gcc 编译不过，所以clang编译好后用clang编译
if [ "0" == $(is_in_list lldb $BUILD_TARGET_COMPOMENTS) ]; then
    LLDB_PKG=$(check_and_download "lldb" "lldb-*.tar.xz" "http://llvm.org/releases/$LLVM_VERSION/lldb-$LLVM_VERSION.src.tar.xz" );
    if [ $? -ne 0 ]; then
        echo -e "$LLDB_PKG";
        exit -1;
    fi

    if [ ! -e "$LLVM_DIR/tools/lldb" ]; then
	    tar -axvf $LLDB_PKG;
    	LLDB_DIR=$(ls -d lldb-* | grep -v \.tar\.xz);
    	mv "$LLDB_DIR" "$LLVM_DIR/tools/lldb";
	fi
	
	if [ ! -e "$LLVM_DIR/tools/lldb" ]; then
    	echo -e "\\033[31;1mlldb src not found but lldb enabled.\\033[39;49;0m";
    	exit -1;
	fi
fi
LLDB_DIR="$LLVM_DIR/tools/lldb";


LIBCXX_INC_DIR=$(find "$PREFIX_DIR/include" -name cstdio);
LIBCXX_INC_DIR="${LIBCXX_INC_DIR%%/cstdio}";
echo "LIBCXX_INC_DIR=$LIBCXX_INC_DIR";

# Stage 3 -- self compiling
# 阶段三  -- 自举编译，这样就能脱离对gcc的依赖(貌似这步结束以后llvm和clang仍然依赖c++，不过libcxx和libcxxabi不依赖了)
# libcxx 和 libcxxabi准备完毕-开始第二次编译
echo -e "\\033[31;1mStage 3: Ready to compile tools. using llvm & clang & libcxx & libcxxabi.\\033[39;49;0m";

# 某些模块没有从cmake变量里找
export C_INCLUDE_PATH=$LIBCXX_INC_DIR:$C_INCLUDE_PATH:$LIBCXXABI_INC_DIR;
export CPLUS_INCLUDE_PATH=$LIBCXX_INC_DIR:$CPLUS_INCLUDE_PATH:$LIBCXXABI_INC_DIR;

build_llvm "cmake_clang" 3 "$PREFIX_DIR" "$STAGE_PREFIX_DIR" -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang -DLLVM_TOOLS_BINARY_DIR="$STAGE_PREFIX_DIR/bin" $BUILD_LLVM_CMAKE_OPTION_STAGE_3 ;
# build_llvm "cmake_clang" 3 "$PREFIX_DIR" "$STAGE_PREFIX_DIR" -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_FLAGS="-stdlib=libc++" -DCMAKE_EXE_LINKER_FLAGS="-lc++abi"  -DLLVM_TOOLS_BINARY_DIR="$STAGE_PREFIX_DIR/bin" $BUILD_LLVM_CMAKE_OPTION_STAGE_3 ;
STAGE_DIRS=$(ls "$WORKING_DIR/stage_"*);
echo -e "\\033[33;1mclean up $STAGE_DIRS.\\033[39;49;0m"
rm -rf $STAGE_DIRS;

echo -e "\\033[33;1mAddition, run the cmds below to add environment var(s).\\033[39;49;0m"
echo -e "\\033[31;1mexport PATH=$PREFIX_DIR/bin:$PATH\\033[39;49;0m"
echo -e "\\033[31;1mexport LD_LIBRARY_PATH=$PREFIX_DIR/lib:$LD_LIBRARY_PATH\\033[39;49;0m"
echo -e "\tor you can add $PREFIX_DIR/lib to file [/etc/ld.so.conf] and then run [ldconfig]"
echo -e "\\033[33;1mBuild LLVM done.\\033[39;49;0m"
