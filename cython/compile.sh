#!/bin/bash

environ=${1:-dev}

if [[ x$environ == "xprod" ]]; then
    nexus_env="prod-releases"
    jenkins_env="Prod-SmartControl"
    GIT_HEAD="origin/release"
    mockify=false
elif [[ x$environ == "xtest" ]]; then
    nexus_env="test-release"
    jenkins_env="BuildSmartControl"
    GIT_HEAD="origin/ci-develop"
    mockify=false
else
    nexus_env="dev-releases"
    jenkins_env="Dev-SmartControl"
    GIT_HEAD="origin/develop"
    mockify=false
fi

nexus_url="http://nexus.daho.tech/nexus/content/repositories"
src_repo="git@gitlab.daho.tech:dahoo/SmartControl.git"

last_version=$(cat VERSION 2>/dev/null)
if [[ $? == 0 ]]; then
    smartcontrol_url="com/fabric4cloud/smartcontrol/smartcontrol/$last_version"
    package_name="smartcontrol-$last_version.tar.gz"
    package="$nexus_url/$nexus_env/$smartcontrol_url/$package_name"
    md5file="$package.md5"
fi

function logger() {
    local msg=$1; shift
    local level=${1:-INFO}; shift
    level=$(printf '%5s' $level)
    t=$(date +"%Y-%m-%d %H:%M:%S %z")
    echo "[$t][$level][$0]: $msg"
}

function str_in_file() {
    local s=$1; shift
    local f=$1; shift
    # Catch only the result. Standard output is not needed
    grep -q $s $f
    if [[ $? == 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

function compile_file() {
    local f=$1; shift
    if [[ $f == *__init__.py ]] || [[ $f != *.py ]]; then
        logger "Ignore file $f"
        return 0
    fi
    if [[ ! -f $f ]]; then
        logger "File $f removed. Ignore it" "WARN"
        return 0
    fi

    local start=$(date +%s)

    local name=$(echo $f | sed 's/.py$//')
    cython -X always_allow_keywords=True $name.py -o $name.c || exit 1
    cc $name.c -o $name.so -O2 -Wall -fPIC -shared -I /usr/include/python2.7/ -lpython2.7 -lpthread || exit 1
    rm -f $name.py $name.pyc $name.c

    local end=$(date +%s)
    runtime=$((end-start))
    logger "Compiling file $f costs $runtime seconds"
}

function clear_src() {
    # if mocked, reserve tests files
    find smartcontrol -name "*.pyc" -delete
    if [[ $mockify = true ]]; then
        find smartcontrol -name "*.py" -not -path "smartcontrol/tests/*" \
            ! -name "*__init__.py" -delete
    else
        find smartcontrol -name "*.py" ! -name "*__init__.py" -delete
        rm -rf QA  # remove QA codes
    fi
}

function incremental_compile() {
    # extract old packages
    cd $build_tmpdir
    tar xf $package_name
    cd ..

    # clear previous compiling output
    find smartcontrol -name "*.so" -delete
    # copy all files from previous build package
    dirlist=$(find smartcontrol -type d | grep -v "schemas\|tests\|locale" | xargs)
    for d in $dirlist; do
        local dir="$build_tmpdir/smartcontrol-$last_version/$d"
        if [[ ! -d $dir ]]; then
            logger "Directory $dir no longer exists. Ignore it" "WARN"
            continue
        fi
        local so_files=$(ls $dir/*.so | xargs)
        if [[ "x$so_files" == "x" ]]; then
            logger "No '.so' files found in $dir. Ignore it"
            continue
        fi
        cp $dir/*.so $d || exit 1
    done

    # retrieve python files changed since last build
    cd $build_tmpdir
    git clone $src_repo source_code || exit 1
    cd source_code
    git checkout $GIT_HEAD || exit 1
    changed_files=$(git diff --name-only $GIT_HEAD..$(python tools/latest_build.py $jenkins_env) | grep -e "py$" | xargs)
    logger "All files changed:"
    echo $changed_files

    # compile only changed files
    cd ../..
    if [[ $mockify = true ]]; then
        # mock necessary files before compiling
        logger "Cloud clients mock request received."
        python tools/mockify.py
    fi
    for f in $changed_files; do
        # ignore files outside smartcontrol
        if [[ $f == smartcontrol* ]] && [[ $f != smartcontrol/tests* ]]; then
            compile_file $f
        else
            logger "Ignore file $f"
        fi
    done
    # compile aws/aliyun cloud file
    cloud_files="smartcontrol/client/aliyun.py smartcontrol/client/aws.py"
    for f in $cloud_files; do
        logger "---- Compile file $f ----"
        compile_file $f
    done

    clear_src
}

function full_compile() {
    if [[ $mockify = true ]]; then
        logger "Cloud clients mock request received."
        python tools/mockify.py
    fi
    # clear previous compiling output
    find smartcontrol -name "*.so" -delete
    dirlist=$(find smartcontrol -type d | grep -v "schemas\|tests\|locale" | xargs)
    for m in $dirlist; do
        logger "---- Compile directory $m ----"
        for f in $(ls $m/*.py); do
            compile_file $f
        done
    done
    clear_src
}

################################################
#### compiling logic starts here
################################################
build_tmpdir=build_tmpdir
rm -rf $build_tmpdir
mkdir $build_tmpdir

# retrieve old builds
incremental=true
if [[ "x$last_version" == "x" ]]; then
    logger "VERSION file not found. Start a full compiling"
    incremental=false
elif [[ "x$environ" == "xprod" ]]; then
    logger "Force full compiling for production release"
    incremental=false
else
    logger "Last build version: $last_version."
    logger "Download last build package to prepare an incremental compiling"
    wget --no-verbose -P $build_tmpdir $package $md5file
    if [[ $? -ne 0 ]]; then
        logger "Failed to download package. Start a full compiling instead" "WARN"
        incremental=false
    else
        logger "Package $package downloaded. Verify file consistency"
        downloaded_md5=$(md5sum $build_tmpdir/$package_name | awk '{ print $1 }')
        real_md5=$(cat $build_tmpdir/$package_name.md5)
        if [[ $downloaded_md5 != $real_md5 ]]; then
            logger "Downloaded file MD5($downloaded_md5) is not equal to $real_md5" "WARN"
            logger "Start a full compiling instead"
            incremental=false
        else
            logger "File verified. Start the incremental compiling"
        fi
    fi
fi

# mock code detection. keep this until mock service is ready
mfiles="smartcontrol/client/aliyun.py smartcontrol/client/aws.py smartcontrol/common/canalapi.py"
if [[ $mockify == "false" ]]; then
    for f in $mfiles; do
        mock_pattern=""
        if [[ $f == *smartcontrol/client/aliyun.py ]]; then
            mock_pattern="MockExpressConnectRequest"
        elif [[ $f == *smartcontrol/client/aws.py ]]; then
            mock_pattern="MockDirectConnectRequest"
        elif [[ $f == *smartcontrol/common/canalapi.py ]]; then
            mock_pattern="MockCanalCoreRequest"
        fi

        if [[ $mock_pattern != "" ]]; then
            found=$(str_in_file $mock_pattern $f)
            if [[ $found != "false" ]]; then
                logger "Found mock code in $f. Compiling rejected" "ERROR"
                rm -rf $build_tmpdir
                exit 1
            fi
        fi
    done
fi

time {
    if [[ $incremental = true ]]; then
        incremental_compile
    else
        full_compile
    fi
    rm -rf smartcontrol.egg-info
    rm -rf build
    rm -rf dist/*
    echo
    logger "Total compiling time:"
}

# save this build status and clear build scene
python setup.py build
python setup.py compile_catalog
python setup.py --version > VERSION
rm -rf $build_tmpdir

