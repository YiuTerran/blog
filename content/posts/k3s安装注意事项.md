---
title: K3s安装注意事项
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2024-02-19T09:08:10+08:00
lastmod: 2024-02-19T09:08:10+08:00
featuredVideo:
featuredImage:
draft: false
---

k3s自带了containerd作为CRI实现，不过我们一般习惯上还是使用docker作为运行时。但是两者结合使用有一些坑，这里做一下记录。

> 不用containerd的主要原因是它的命令太难记，ctr/ctictl做的什么jb玩意儿。还有一个原因是，如果只想用容器不想用k8s，docker的功能是最完善的。
>
> 如果你选择使用containerd，那么可以考虑安装nerdctl，它的命令格式与docker基本一致，具体使用方法可以参考[这里](http://kingsd.top/2021/09/30/nerdctl/)。

## 安装docker

需要注意的是，**k3s并不是与docker的所有版本都兼容**！一般来说，最好不要使用最新的版本，大版本号降低一级更好。比如这篇博客发布的时候，最新的docker是25.0.3，但是k3s只能兼容到24.0.9，因此安装docker的时候，就不能安装最新的版本，否则k3s无法正常启动！

安装脚本是根据[官方脚本](https://releases.rancher.com/install-docker/19.03.sh)修改的，适配了常见的发行版，参考：

<details><summary>点击折叠</summary>

```bash
#!/bin/sh
set -e
SCRIPT_COMMIT_SHA="a8a6b338bdfedd7ddefb96fe3e7fe7d4036d945a"

CHANNEL="stable"
DOWNLOAD_URL="https://download.docker.com"
REPO_FILE="docker-ce.repo"
VERSION="24.0.9"
DIND_TEST_WAIT=${DIND_TEST_WAIT:-3s} # Wait time until docker start at dind test env

# Issue https://github.com/rancher/rancher/issues/29246
adjust_repo_releasever() {
	DOWNLOAD_URL="https://download.docker.com"
	case $1 in
	7*)
		releasever=7
		;;
	8*)
		releasever=8
		;;
	*)
		# fedora, or unsupported
		return
		;;
	esac

	for channel in "stable" "test" "nightly"; do
		$sh_c "$config_manager --setopt=docker-ce-${channel}.baseurl=${DOWNLOAD_URL}/linux/centos/${releasever}/\\\$basearch/${channel} --save"
		$sh_c "$config_manager --setopt=docker-ce-${channel}-debuginfo.baseurl=${DOWNLOAD_URL}/linux/centos/${releasever}/debug-\\\$basearch/${channel} --save"
		$sh_c "$config_manager --setopt=docker-ce-${channel}-source.baseurl=${DOWNLOAD_URL}/linux/centos/${releasever}/source/${channel} --save"
	done
}

mirror=''
DRY_RUN=${DRY_RUN:-}
while [ $# -gt 0 ]; do
	case "$1" in
	--mirror)
		mirror="$2"
		shift
		;;
	--dry-run)
		DRY_RUN=1
		;;
	--*)
		echo "Illegal option $1"
		;;
	esac
	shift $(($# > 0 ? 1 : 0))
done

case "$mirror" in
Aliyun)
	DOWNLOAD_URL="https://mirrors.aliyun.com/docker-ce"
	;;
AzureChinaCloud)
	DOWNLOAD_URL="https://mirror.azure.cn/docker-ce"
	;;
esac

start_docker() {
	if [ ! -z "$DIND_TEST" ]; then
		# Starting dockerd manually due to dind env is not using systemd
		dockerd &
		sleep "$DIND_TEST_WAIT"
	elif [ -d '/run/systemd/system' ]; then
		$sh_c 'systemctl start docker'
	else
		$sh_c 'service docker start'
	fi
}

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

# version_gte checks if the version specified in $VERSION is at least
# the given CalVer (YY.MM) version. returns 0 (success) if $VERSION is either
# unset (=latest) or newer or equal than the specified version. Returns 1 (fail)
# otherwise.
#
# examples:
#
# VERSION=20.10
# version_gte 20.10 // 0 (success)
# version_gte 19.03 // 0 (success)
# version_gte 21.10 // 1 (fail)
version_gte() {
	if [ -z "$VERSION" ]; then
		return 0
	fi
	eval calver_compare "$VERSION" "$1"
}

# calver_compare compares two CalVer (YY.MM) version strings. returns 0 (success)
# if version A is newer or equal than version B, or 1 (fail) otherwise. Patch
# releases and pre-release (-alpha/-beta) are not taken into account
#
# examples:
#
# calver_compare 20.10 19.03 // 0 (success)
# calver_compare 20.10 20.10 // 0 (success)
# calver_compare 19.03 20.10 // 1 (fail)
calver_compare() (
	set +x

	yy_a="$(echo "$1" | cut -d'.' -f1)"
	yy_b="$(echo "$2" | cut -d'.' -f1)"
	if [ "$yy_a" -lt "$yy_b" ]; then
		return 1
	fi
	if [ "$yy_a" -gt "$yy_b" ]; then
		return 0
	fi
	mm_a="$(echo "$1" | cut -d'.' -f2)"
	mm_b="$(echo "$2" | cut -d'.' -f2)"
	if [ "${mm_a#0}" -lt "${mm_b#0}" ]; then
		return 1
	fi

	return 0
)

is_dry_run() {
	if [ -z "$DRY_RUN" ]; then
		return 1
	else
		return 0
	fi
}

is_wsl() {
	case "$(uname -r)" in
	*microsoft*) true ;; # WSL 2
	*Microsoft*) true ;; # WSL 1
	*) false ;;
	esac
}

is_darwin() {
	case "$(uname -s)" in
	*darwin*) true ;;
	*Darwin*) true ;;
	*) false ;;
	esac
}

deprecation_notice() {
	distro=$1
	distro_version=$2
	echo
	printf "\033[91;1mDEPRECATION WARNING\033[0m\n"
	printf "    This Linux distribution (\033[1m%s %s\033[0m) reached end-of-life and is no longer supported by this script.\n" "$distro" "$distro_version"
	echo "    No updates or security fixes will be released for this distribution, and users are recommended"
	echo "    to upgrade to a currently maintained version of $distro."
	echo
	printf "Press \033[1mCtrl+C\033[0m now to abort this script, or wait for the installation to continue."
	echo
	sleep 10
}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "$lsb_dist"
}

echo_docker_as_nonroot() {
	if is_dry_run; then
		return
	fi
	if command_exists docker && [ -e /var/run/docker.sock ]; then
		(
			set -x
			$sh_c 'docker version'
		) || true
	fi

	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
	echo
	echo "================================================================================"
	echo
	if version_gte "20.10"; then
		echo "To run Docker as a non-privileged user, consider setting up the"
		echo "Docker daemon in rootless mode for your user:"
		echo
		echo "    dockerd-rootless-setuptool.sh install"
		echo
		echo "Visit https://docs.docker.com/go/rootless/ to learn about rootless mode."
		echo
	fi
	echo
	echo "To run the Docker daemon as a fully privileged service, but granting non-root"
	echo "users access, refer to https://docs.docker.com/go/daemon-access/"
	echo
	echo "WARNING: Access to the remote API on a privileged Docker daemon is equivalent"
	echo "         to root access on the host. Refer to the 'Docker daemon attack surface'"
	echo "         documentation for details: https://docs.docker.com/go/attack-surface/"
	echo
	echo "================================================================================"
	echo
}

# Check if this is a forked Linux distro
check_forked() {

	# Check for lsb_release command existence, it usually exists in forked distros
	if command_exists lsb_release; then
		# Check if the `-u` option is supported
		set +e
		lsb_release -a -u >/dev/null 2>&1
		lsb_release_exit_code=$?
		set -e

		# Check if the command has exited successfully, it means we're in a forked distro
		if [ "$lsb_release_exit_code" = "0" ]; then
			# Print info about current distro
			cat <<-EOF
				You're using '$lsb_dist' version '$dist_version'.
			EOF

			# Get the upstream release info
			lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
			dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')

			# Print info about upstream distro
			cat <<-EOF
				Upstream release is '$lsb_dist' version '$dist_version'.
			EOF
		else
			if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
				if [ "$lsb_dist" = "osmc" ]; then
					# OSMC runs Raspbian
					lsb_dist=raspbian
				else
					# We're Debian and don't even know it!
					lsb_dist=debian
				fi
				dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
				case "$dist_version" in
				12)
					dist_version="bookworm"
					;;
				11)
					dist_version="bullseye"
					;;
				10)
					dist_version="buster"
					;;
				9)
					dist_version="stretch"
					;;
				8)
					dist_version="jessie"
					;;
				esac
			fi
		fi
	fi
}

do_install() {
	echo "# Executing docker install script, commit: $SCRIPT_COMMIT_SHA"

	if command_exists docker; then
		cat >&2 <<-'EOF'
			Warning: the "docker" command appears to already exist on this system.

			If you already have Docker installed, this script can cause trouble, which is
			why we're displaying this warning and provide the opportunity to cancel the
			installation.

			If you installed the current Docker package using this script and are using it
			again to update Docker, you can safely ignore this message.

			You may press Ctrl+C now to abort this script.
		EOF
		(
			set -x
			sleep 20
		)
	fi

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
			cat >&2 <<-'EOF'
				Error: this installer needs the ability to run commands as root.
				We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit 1
		fi
	fi

	if is_dry_run; then
		sh_c="echo"
	fi

	# perform some very rudimentary platform detection
	lsb_dist=$(get_distribution)
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	if is_wsl; then
		echo
		echo "WSL DETECTED: We recommend using Docker Desktop for Windows."
		echo "Please get Docker Desktop from https://www.docker.com/products/docker-desktop"
		echo
		cat >&2 <<-'EOF'

			You may press Ctrl+C now to abort this script.
		EOF
		(
			set -x
			sleep 20
		)
	fi

	case "$lsb_dist" in

	ubuntu)
		if command_exists lsb_release; then
			dist_version="$(lsb_release --codename | cut -f2)"
		fi
		if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
			dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
		fi
		;;

	debian | raspbian)
		dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
		case "$dist_version" in
		12)
			dist_version="bookworm"
			;;
		11)
			dist_version="bullseye"
			;;
		10)
			dist_version="buster"
			;;
		9)
			dist_version="stretch"
			;;
		8)
			dist_version="jessie"
			;;
		esac
		;;

	centos | rhel | sles | rocky)
		if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
			dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
		fi

		;;

	oracleserver | ol)
		lsb_dist="ol"
		# need to switch lsb_dist to match yum repo URL
		dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
		;;

	*)
		if command_exists lsb_release; then
			dist_version="$(lsb_release --release | cut -f2)"
		fi
		if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
			dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
		fi
		;;

	esac

	# Check if this is a forked Linux distro
	check_forked

	# Print deprecation warnings for distro versions that recently reached EOL,
	# but may still be commonly used (especially LTS versions).
	case "$lsb_dist.$dist_version" in
	debian.stretch | debian.jessie)
		deprecation_notice "$lsb_dist" "$dist_version"
		;;
	raspbian.stretch | raspbian.jessie)
		deprecation_notice "$lsb_dist" "$dist_version"
		;;
	ubuntu.xenial | ubuntu.trusty)
		deprecation_notice "$lsb_dist" "$dist_version"
		;;
	fedora.*)
		if [ "$dist_version" -lt 36 ]; then
			deprecation_notice "$lsb_dist" "$dist_version"
		fi
		;;
	esac

	# Run setup for each distro accordingly
	case "$lsb_dist" in
	ubuntu | debian | raspbian)
		pre_reqs="apt-transport-https ca-certificates curl"
		if ! command -v gpg >/dev/null; then
			pre_reqs="$pre_reqs gnupg"
		fi
		apt_repo="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOWNLOAD_URL/linux/$lsb_dist $dist_version $CHANNEL"
		(
			if ! is_dry_run; then
				set -x
			fi
			$sh_c 'apt-get update -qq >/dev/null'
			$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pre_reqs >/dev/null"
			$sh_c 'mkdir -p /etc/apt/keyrings && chmod -R 0755 /etc/apt/keyrings'
			$sh_c "curl -fsSL \"$DOWNLOAD_URL/linux/$lsb_dist/gpg\" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg"
			$sh_c "chmod a+r /etc/apt/keyrings/docker.gpg"
			$sh_c "echo \"$apt_repo\" > /etc/apt/sources.list.d/docker.list"
			$sh_c 'apt-get update -qq >/dev/null'
		)
		pkg_version=""
		if [ -n "$VERSION" ]; then
			if is_dry_run; then
				echo "# WARNING: VERSION pinning is not supported in DRY_RUN"
			else
				# Will work for incomplete versions IE (17.12), but may not actually grab the "latest" if in the test channel
				pkg_pattern="$(echo "$VERSION" | sed "s/-ce-/~ce~.*/g" | sed "s/-/.*/g")"
				search_command="apt-cache madison 'docker-ce' | grep '$pkg_pattern' | head -1 | awk '{\$1=\$1};1' | cut -d' ' -f 3"
				pkg_version="$($sh_c "$search_command")"
				echo "INFO: Searching repository for VERSION '$VERSION'"
				echo "INFO: $search_command"
				if [ -z "$pkg_version" ]; then
					echo
					echo "ERROR: '$VERSION' not found amongst apt-cache madison results"
					echo
					exit 1
				fi
				if version_gte "18.09"; then
					search_command="apt-cache madison 'docker-ce-cli' | grep '$pkg_pattern' | head -1 | awk '{\$1=\$1};1' | cut -d' ' -f 3"
					echo "INFO: $search_command"
					cli_pkg_version="=$($sh_c "$search_command")"
				fi
				pkg_version="=$pkg_version"
			fi
		fi
		(
			pkgs="docker-ce${pkg_version%=}"
			if version_gte "18.09"; then
				# older versions didn't ship the cli and containerd as separate packages
				pkgs="$pkgs docker-ce-cli${cli_pkg_version%=} containerd.io"
			fi
			if version_gte "20.10"; then
				pkgs="$pkgs docker-compose-plugin docker-ce-rootless-extras$pkg_version"
			fi
			if version_gte "23.0"; then
				pkgs="$pkgs docker-buildx-plugin"
			fi
			if ! is_dry_run; then
				set -x
			fi
			$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs >/dev/null"
			start_docker
		)
		echo_docker_as_nonroot
		exit 0
		;;
	centos | fedora | rhel | ol | rocky)
		# set vault.centos.or repo as CentOS8 is now EOL
		if [ "$lsb_dist" = "centos" ] && [ "$dist_version" -ge "8" ]; then
			$sh_c "find /etc/yum.repos.d -type f -exec sed -i 's/mirrorlist=http:\/\/mirrorlist.centos.org/\#mirrorlist=http:\/\/mirrorlist.centos.org/g' {} \;"
			$sh_c "find /etc/yum.repos.d -type f -exec sed -i 's/\#baseurl=http:\/\/mirror.centos.org/baseurl=http:\/\/vault.centos.org/g' {} \;"
			$sh_c "dnf swap centos-linux-repos centos-stream-repos -y"
		fi
		if [ "$lsb_dist" = "fedora" ]; then
			pkg_manager="dnf"
			config_manager="dnf config-manager"
			enable_channel_flag="--set-enabled"
			disable_channel_flag="--set-disabled"
			pre_reqs="dnf-plugins-core"
			pkg_suffix="fc$dist_version"
		else
			pkg_manager="yum"
			config_manager="yum-config-manager"
			enable_channel_flag="--enable"
			disable_channel_flag="--disable"
			pre_reqs="yum-utils"
			pkg_suffix="el"
		fi
		repo_file_url="$DOWNLOAD_URL/linux/$lsb_dist/$REPO_FILE"
		if [ "$lsb_dist" = "ol" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "rhel" ]; then
			repo_file_url="$DOWNLOAD_URL/linux/centos/$REPO_FILE"
		fi
		(
			if ! is_dry_run; then
				set -x
			fi
			$sh_c "$pkg_manager install -y -q $pre_reqs"
			$sh_c "$config_manager --add-repo $repo_file_url"

			if [ "$CHANNEL" != "stable" ]; then
				$sh_c "$config_manager $disable_channel_flag docker-ce-*"
				$sh_c "$config_manager $enable_channel_flag docker-ce-$CHANNEL"
			fi
			if [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "ol" ]; then
				adjust_repo_releasever "$dist_version"
				# Add extra repo for version 7.x
				if [[ "$dist_version" =~ "7." ]] || [ "$dist_version" == "7" ]; then
					if [ "$lsb_dist" = "rhel" ]; then
						$sh_c "$config_manager $enable_channel_flag rhui-REGION-rhel-server-extras"
						$sh_c "$config_manager $enable_channel_flag rhui-rhel-7-server-rhui-extras-rpms"
						$sh_c "$config_manager $enable_channel_flag rhui-rhel-7-for-arm-64-extras-rhui-rpms"
						$sh_c "$config_manager $enable_channel_flag rhel-7-server-rhui-extras-rpms"
						$sh_c "$config_manager $enable_channel_flag rhel-7-server-extras-rpms"
					else
						$sh_c "$config_manager $enable_channel_flag ol7_addons"
						# Adding OL7 developer repo if doesn't exist
						if [ "$(yum repolist | grep yum.oracle.com_repo_OracleLinux_OL7_developer >/dev/null || echo add)" == "add" ]; then
							$sh_c "$config_manager --add-repo https://yum.oracle.com/repo/OracleLinux/OL7/developer/x86_64"
						fi
					fi
				fi
			fi
			$sh_c "$pkg_manager makecache"
		)
		pkg_version=""
		if [ -n "$VERSION" ]; then
			if is_dry_run; then
				echo "# WARNING: VERSION pinning is not supported in DRY_RUN"
			else
				pkg_pattern="$(echo "$VERSION" | sed "s/-ce-/\\\\.ce.*/g" | sed "s/-/.*/g").*$pkg_suffix"
				search_command="$pkg_manager list --showduplicates 'docker-ce' | grep '$pkg_pattern' | tail -1 | awk '{print \$2}'"
				pkg_version="$($sh_c "$search_command")"
				echo "INFO: Searching repository for VERSION '$VERSION'"
				echo "INFO: $search_command"
				if [ -z "$pkg_version" ]; then
					echo
					echo "ERROR: '$VERSION' not found amongst $pkg_manager list results"
					echo
					exit 1
				fi
				if version_gte "18.09"; then
					# older versions don't support a cli package
					search_command="$pkg_manager list --showduplicates 'docker-ce-cli' | grep '$pkg_pattern' | tail -1 | awk '{print \$2}'"
					cli_pkg_version="$($sh_c "$search_command" | cut -d':' -f 2)"
				fi
				# Cut out the epoch and prefix with a '-'
				pkg_version="-$(echo "$pkg_version" | cut -d':' -f 2)"
			fi
		fi
		(
			pkgs="docker-ce$pkg_version"
			if version_gte "18.09"; then
				# older versions didn't ship the cli and containerd as separate packages
				if [ -n "$cli_pkg_version" ]; then
					pkgs="$pkgs docker-ce-cli-$cli_pkg_version containerd.io"
				else
					pkgs="$pkgs docker-ce-cli containerd.io"
				fi
			fi
			if version_gte "20.10"; then
				pkgs="$pkgs docker-compose-plugin docker-ce-rootless-extras$pkg_version"
			fi
			if version_gte "23.0"; then
				pkgs="$pkgs docker-buildx-plugin"
			fi
			if ! is_dry_run; then
				set -x
			fi
			$sh_c "$pkg_manager install -y -q $pkgs"
		)
		echo_docker_as_nonroot
		exit 0
		;;
	sles)
		if [ "$(uname -m)" != "s390x" ]; then
			echo "Packages for SLES are currently only available for s390x"
			exit 1
		fi
		if [ "$dist_version" = "15.3" ]; then
			sles_version="SLE_15_SP3"
		else
			sles_version="SLE_15_SP2"
		fi
		opensuse_repo="https://download.opensuse.org/repositories/security:SELinux/$sles_version/security:SELinux.repo"
		repo_file_url="$DOWNLOAD_URL/linux/$lsb_dist/$REPO_FILE"
		pre_reqs="ca-certificates curl libseccomp2 awk"
		(
			if ! is_dry_run; then
				set -x
			fi
			$sh_c "zypper install -y $pre_reqs"
			$sh_c "zypper addrepo $repo_file_url"
			if ! is_dry_run; then
				cat >&2 <<-'EOF'
					WARNING!!
					openSUSE repository (https://download.opensuse.org/repositories/security:SELinux) will be enabled now.
					Do you wish to continue?
					You may press Ctrl+C now to abort this script.
				EOF
				(
					set -x
					sleep 30
				)
			fi
			$sh_c "zypper addrepo $opensuse_repo"
			$sh_c "zypper --gpg-auto-import-keys refresh"
			$sh_c "zypper lr -d"
		)
		pkg_version=""
		if [ -n "$VERSION" ]; then
			if is_dry_run; then
				echo "# WARNING: VERSION pinning is not supported in DRY_RUN"
			else
				pkg_pattern="$(echo "$VERSION" | sed "s/-ce-/\\\\.ce.*/g" | sed "s/-/.*/g")"
				search_command="zypper search -s --match-exact 'docker-ce' | grep '$pkg_pattern' | tail -1 | awk '{print \$6}'"
				pkg_version="$($sh_c "$search_command")"
				echo "INFO: Searching repository for VERSION '$VERSION'"
				echo "INFO: $search_command"
				if [ -z "$pkg_version" ]; then
					echo
					echo "ERROR: '$VERSION' not found amongst zypper list results"
					echo
					exit 1
				fi
				search_command="zypper search -s --match-exact 'docker-ce-cli' | grep '$pkg_pattern' | tail -1 | awk '{print \$6}'"
				# It's okay for cli_pkg_version to be blank, since older versions don't support a cli package
				cli_pkg_version="$($sh_c "$search_command")"
				pkg_version="-$pkg_version"
			fi
		fi
		(
			pkgs="docker-ce$pkg_version"
			if version_gte "18.09"; then
				if [ -n "$cli_pkg_version" ]; then
					# older versions didn't ship the cli and containerd as separate packages
					pkgs="$pkgs docker-ce-cli-$cli_pkg_version containerd.io"
				else
					pkgs="$pkgs docker-ce-cli containerd.io"
				fi
			fi
			if version_gte "20.10"; then
				pkgs="$pkgs docker-compose-plugin docker-ce-rootless-extras$pkg_version"
			fi
			if version_gte "23.0"; then
				pkgs="$pkgs docker-buildx-plugin"
			fi
			if ! is_dry_run; then
				set -x
			fi
			$sh_c "zypper -q install -y $pkgs"
			if ! command_exists iptables; then
				$sh_c "$pkg_manager install -y -q iptables"
			fi
			start_docker
		)
		echo_docker_as_nonroot
		exit 0
		;;
	rancheros)
		(
			set -x
			$sh_c "sleep 3;ros engine list --update"
			engine_version="$(sudo ros engine list | awk '{print $2}' | grep "${docker_version}" | tail -n 1)"
			if [ "$engine_version" != "" ]; then
				$sh_c "ros engine switch -f $engine_version"
			fi
		)
		exit 0
		;;
	*)
		if [ -z "$lsb_dist" ]; then
			if is_darwin; then
				echo
				echo "ERROR: Unsupported operating system 'macOS'"
				echo "Please get Docker Desktop from https://www.docker.com/products/docker-desktop"
				echo
				exit 1
			fi
		fi
		echo
		echo "ERROR: Unsupported distribution '$lsb_dist'"
		echo
		exit 1
		;;
	esac
	exit 1
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
```
</details>

为了防止安装后自动升级覆盖了docker，Ubuntu可以使用`sudo apt-mark hold docker-ce docker-ce-cli docker-ce-rootless-extras`锁定版本，其他发行版也有类似的命令。

## 自动化配置docker

将上面的脚本另存为`docker-install-24.0.9.sh`，然后再写一个脚本来完成docker的安装和配置：

```bash
#!/usr/bin/env bash
# init docker with composed

if ! type docker >/dev/null 2>&1; then
    max_try=3
    while true; do
        sudo bash docker-install-24.0.9.sh --mirror Aliyun
        if [ $? -eq 0 ]; then
            echo "succ to install docker"
            break
        else
            max_try=$((max_try - 1))
            if [ $max_try -eq 0 ]; then
                echo "can't install docker, exit"
                exit 1
            fi
            echo "fail to install docker, sleeping 5s before retrying"
            sleep 5
        fi
    done
fi

sudo mkdir -p /etc/docker
sudo rm /etc/docker/daemon.json >/dev/null 2>&1
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": [
        "https://docker.nju.edu.cn/",
        "https://mirror.baidubce.com"
    ],
    "live-restore": true,
    "log-driver":"json-file",
    "log-opts": {"max-size":"50m", "max-file":"3"}
}
EOF
sudo systemctl daemon-reload
sudo systemctl stop docker
systemctl enable docker

while true; do
    sudo systemctl start docker
    if [ $? -eq 0 ]; then
        echo "Docker start successfully"
        break
    else
        echo "Failed to restart Docker, sleeping for 5s before retrying..."
        sleep 5
    fi
done
```

这里主要是安装docker，配置国内镜像源和日志大小限制，然后重启docker服务。如果是在国外的机器上，可以不用配置镜像，但是日志大小限制一般还是需要配置的，否则服务日志可能会逐渐塞满硬盘。

## 安装k3s

参考如下脚本，需要注意的是`--docker`必须放在安装命令的最后面，否则不生效。

```bash
#!/usr/bin/env bash

MAX_POD_CNT=0
DATA_PATH=""
AGENT_MODE=0
SERVER_TOKEN=""
SERVER_IP=""
K3S_VERSION="v1.26.13+k3s2"
# 如果升级了k3s的版本，这里可以也跟着升级
HELM_VERSION="v3.12.3"
# 分布式存储插件
LONGHORN_VERSION="1.5.1"
NEED_LONGHORN=0
INIT_INSTALL=0
FORCE=0
export DEBIAN_FRONTEND=noninteractive

help() {
    echo "install script for k3s, you can run 'k3s-uninstall.sh' to uninstall"
    echo "Usage:"
    echo "  k3s_install.sh [-a] [-s server_url] [-t server_token] [-p max_pod_cnt] [-d data_path]"
    echo "  -a: install k3s as agent. Use it with -t <server token> and -s <server url>"
    echo "  -l: install longhorn"
    echo "  -t: token, for server or agent join cluster"
    echo "  -s: server ip"
    echo "  -f: force install"
    echo "  -p: max pod count, default is 110"
    echo "  -d: data path, default is ${DATA_PATH}"
    echo "  -v: k3s version, default is ${K3S_VERSION}"
    exit 0
}

while getopts 's:l:t:p:v:d:afh' OPT; do
    case $OPT in
    a) AGENT_MODE=1 ;;
    l) NEED_LONGHORN=1 ;;
    f) FORCE=1 ;;
    t) SERVER_TOKEN="$OPTARG" ;;
    s) SERVER_IP="$OPTARG" ;;
    p) MAX_POD_CNT="$OPTARG" ;;
    d) DATA_PATH="$OPTARG" ;;
    v) K3S_VERSION="$OPTARG" ;;
    h) help ;;
    ?) help ;;
    esac
done

# check if static ip
if ! ip route list default | grep static >/dev/null; then
    echo "you must set static ip before init env"
    exit 1
fi

# Check parameters
if [ $AGENT_MODE -eq 1 ] && { [ -z "$SERVER_IP" ] || [ -z "$SERVER_TOKEN" ]; }; then
    echo "miss server_ip or server_token for agent mode, exit"
    exit 1
fi

if [ -z "$SERVER_TOKEN" ] || [ -z "$SERVER_IP" ]; then
    INIT_INSTALL=1
fi

if [ $FORCE -eq 1 ] && type k3s >/dev/null 2>&1; then
    if k3s-uninstall.sh >/dev/null 2>&1; then
        echo "k3s uninstalled"
    else
        k3s-agent-uninstall.sh >/dev/null 2>&1
        echo "k3s agent uninstalled"
    fi
fi

# install k3s if not exist
if ! type k3s >/dev/null 2>&1; then
    # install k3s from now
    opts="K3S_KUBECONFIG_MODE=\"644\""
    cmd=""
    server_url="https://$SERVER_IP:6443"
    if [ $AGENT_MODE -eq 1 ]; then
        echo "install k3s as agent, server url is $server_url"
        opts="$opts K3S_URL=$server_url K3S_TOKEN=$SERVER_TOKEN"
    else
        if [ $INIT_INSTALL -eq 1 ]; then
            cmd="server --cluster-init"
        else
            opts="$opts K3S_TOKEN=$SERVER_TOKEN"
            cmd="server --server $server_url"
        fi
    fi
    # set to `--kube-proxy-arg=proxy-mode=ipvs`, if you want ipvs mode
    exec_opts=""
    if [ "$MAX_POD_CNT" -gt 0 ]; then
        exec_opts="$exec_opts --kubelet-arg=max-pods=$MAX_POD_CNT"
    fi
    if [ -n "$DATA_PATH" ] && [ $AGENT_MODE -eq 0 ]; then
        exec_opts="$exec_opts --default-local-storage-path=$DATA_PATH"
    fi
    if [ -n "$exec_opts" ]; then
        exec_opts=$(echo "$exec_opts" | xargs)
        opts="$opts INSTALL_K3S_EXEC='$exec_opts'"
    fi
    echo "install k3s online..."
    opts="$opts INSTALL_K3S_MIRROR=cn"
    if [ -n "$K3S_VERSION" ]; then
        opts="$opts INSTALL_K3S_VERSION=$K3S_VERSION"
    fi
    # --docker must at end!!!
    cmd="curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | $opts sh -s - $cmd --docker"
    echo "$cmd"
    eval "$cmd"
    if type k3s >/dev/null 2>&1; then
        echo "succ to install k3s"
    else
        echo "fail to install k3s"
        exit 1
    fi
else
    echo "skip k3s install..."
fi

if [ $AGENT_MODE -eq 0 ]; then
    echo "restart every 9 month for certificate rotate in server node"
    grep 'systemctl restart k3s' /etc/crontab || echo '0 2 1 */9 * systemctl restart k3s >/dev/null 2>&1' >>/etc/crontab
fi

if grep -q "KUBECONFIG" ~/.bashrc; then
    sed -i 's/export KUBECONFIG=.*/export KUBECONFIG=\/etc\/rancher\/k3s\/k3s.yaml/' ~/.bashrc
else
    echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >>~/.bashrc
fi

if ! grep -q "alias k='kubectl'" ~/.bashrc; then
    echo "alias k='kubectl'" >>~/.bashrc
fi

if ! type helm >/dev/null 2>&1; then
    echo "install helm..."
    curl https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/helm-install.sh | bash /dev/stdin -v $HELM_VERSION
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
fi

if [ $AGENT_MODE -eq 1 ]; then
    echo "all done"
    exit 0
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# wait node ready
while true; do
    node_status=$(kubectl get node "$(hostname)" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [[ "$node_status" == "True" ]]; then
        break
    else
        echo "wait until current node ready..."
        sleep 5
    fi
done

# new cluster
if [ $INIT_INSTALL -eq 1 ]; then
    # install longhorn
    if [ $NEED_LONGHORN -eq 1 ]; then
        helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version $LONGHORN_VERSION
        kubectl patch sc longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: longhorn-system-middleware@kubernetescrd
spec:
  rules:
  - http:
      paths:
      - path: /longhorn
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: middleware
  namespace: longhorn-system
spec:
  replacePathRegex:
    regex: "^/longhorn(/|$)(.*)"
    replacement: "/${2}"
EOF
    fi
fi

echo "all done"
```

## 使用时注意

* k3s安装到了root用户下，个人用户如果想要使用`kubectl`命令，建议`cp /etc/rancher/k3s/k3s.yaml ~/.kube/config`，如果使用`export KUBECONFIG`的方式，可能会提示权限问题，比较烦人；
* k3s自带了kubectl命令，不过你也可以自己安装一个标准的[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)；
* k3s有时候会莫名其妙的挂掉，建议用`systemctl restart k3s`重启一下；
* 卸载k3s使用`k3s-uninstall.sh`即可；