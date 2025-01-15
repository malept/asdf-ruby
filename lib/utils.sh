#!/usr/bin/env bash

RUBY_BUILD_VERSION="${ASDF_RUBY_BUILD_VERSION:-v20250115}"
RUBY_BUILD_TAG="$RUBY_BUILD_VERSION"

echoerr() {
  echo >&2 -e "\033[0;31m$1\033[0m"
}

errorexit() {
  echoerr "$1"
  exit 1
}

ensure_ruby_build_setup() {
  ensure_ruby_build_installed
}

ensure_ruby_build_installed() {
  local current_ruby_build_version

  if [ ! -f "$(ruby_build_path)" ]; then
    download_ruby_build
  else
    current_ruby_build_version="$("$(ruby_build_path)" --version | cut -d ' ' -f2)"
    # If ruby-build version does not start with 'v',
    # add 'v' to beginning of version
    # shellcheck disable=SC2086
    if [ ${current_ruby_build_version:0:1} != "v" ]; then
      current_ruby_build_version="v$current_ruby_build_version"
    fi
    if [ "$current_ruby_build_version" != "$RUBY_BUILD_VERSION" ]; then
      # If the ruby-build directory already exists and the version does not
      # match, remove it and download the correct version
      rm -rf "$(ruby_build_dir)"
      download_ruby_build
    fi
  fi
}

download_ruby_build() {
  # Print to stderr so asdf doesn't assume this string is a list of versions
  echoerr "Downloading ruby-build..."
  # shellcheck disable=SC2155
  local build_dir="$(ruby_build_source_dir)"

  # Remove directory in case it still exists from last download
  rm -rf "$build_dir"

  # Clone down and checkout the correct ruby-build version
  git clone https://github.com/rbenv/ruby-build.git "$build_dir" >/dev/null 2>&1
  (
    cd "$build_dir" || exit
    git checkout "$RUBY_BUILD_TAG" >/dev/null 2>&1
  )

  # Install in the ruby-build dir
  PREFIX="$(ruby_build_dir)" "$build_dir/install.sh"

  # Remove ruby-build source dir
  rm -rf "$build_dir"
}

asdf_ruby_plugin_path() {
  # shellcheck disable=SC2005
  echo "$(dirname "$(dirname "$0")")"
}
ruby_build_dir() {
  echo "$(asdf_ruby_plugin_path)/ruby-build"
}

ruby_build_source_dir() {
  echo "$(asdf_ruby_plugin_path)/ruby-build-source"
}

ruby_build_path() {
  echo "$(ruby_build_dir)/bin/ruby-build"
}

ensure_patchelf_installed() {
  if ! command -v patchelf >/dev/null; then
    errorexit "Run 'sudo apt install patchelf' to install Ruby binaries from ruby/ruby-builder"
  fi
}

load_os_release() {
  local os_release

  # Needed for both the distro ID and version ID
  test -e /etc/os-release && os_release='/etc/os-release' || os_release='/usr/lib/os-release'
  # shellcheck source=/dev/null
  source "${os_release}"
}

get_rvm_io_linux_distro() {
  local distro_slug distro_id

  distro_id="$1"

  if [[ -n "${RUBY_INSTALL_BINARY_RVM_DISTRO:-}" ]]; then
    echo "$RUBY_INSTALL_BINARY_RVM_DISTRO"
    return
  fi

  case "$distro_id" in
  amzn) distro_slug="amazon" ;;
  arch | centos | debian | opensuse | ubuntu) distro_slug="$distro_id" ;;
  ol) distro_slug="oracle" ;;
  "opensuse-leap") distro_slug="opensuse" ;;
  *) errorexit "Unsupported Linux distro $NAME, install from source instead" ;;
  esac

  echo "$distro_slug"
}

get_rvm_io_url() {
  local kernel
  kernel="$(uname -s)"
  case "$kernel" in
  Darwin)
    # There is an osx folder but the binaries haven't been built since 2015
    errorexit "macOS not supported by rvm.io/binaries, install from source instead"
    ;;

  Linux)
    local distro
    load_os_release
    distro="$(get_rvm_io_linux_distro "$ID")"
    echo "https://rvm.io/binaries/$distro/${VERSION_ID:-UNDEFINED_BY_OS_RELEASE}/$(uname -m)"
    ;;

  *) errorexit "OS '$kernel' not supported by rvm.io/binaries, install from source instead" ;;
  esac
}

get_travis_rubies_url() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    errorexit "macOS currently unsupported, install from source instead"
  fi
  load_os_release
  if [[ "$ID" != "ubuntu" ]]; then
    errorexit "Travis CI only provides Linux binaries for the Ubuntu distro"
  fi
  echo "https://s3.amazonaws.com/travis-rubies/binaries/$ID/${VERSION_ID:-UNDEFINED_BY_OS_RELEASE}/$(uname -m)"
}

run_gnu_tar() {
  local tar
  case "$(uname -s)" in
  Darwin) tar=gtar ;;
  *) tar=tar ;;
  esac

  "$tar" "$@"
}

download_and_install_prebuilt_ruby() {
  local base_url download_file filename install_path url
  base_url="$1"
  filename="$2"
  install_path="$3"
  url="$base_url/$filename"
  download_file="$(mktemp -d "${TMPDIR:-/tmp}/asdf-ruby.XXXXXX")/$filename"

  curl --fail --silent --show-error --location --output "$download_file" "$url"
  mkdir -p "$install_path"
  run_gnu_tar --strip-components=1 --extract --file="$download_file" --directory="$install_path" --preserve-permissions
}

fix_runpath() {
  local kernel="$1"
  local install_path="$2"
  case "$kernel" in
  Linux)
    # shellcheck disable=SC2016
    patchelf --set-rpath '${ORIGIN}/../lib' "$install_path/bin/ruby"
    # shellcheck disable=SC2016
    find "$install_path" -type f -name "*.so" -exec patchelf --set-rpath '${ORIGIN}/../lib' "{}" \;
    ;;
  Darwin)
    # TODO: run install_name_tool on the ruby executable plus any libraries (*.bundle?)
    # to change the rpath of libruby*.dylib to @loader_path/../lib/libruby*.dylib
    errorexit "fix_runpath not implemented for macOS"
    ;;
  esac
}

sed_inplace_cmd() {
  local kernel="$1"
  shift
  case "$kernel" in
  Darwin) echo 'sed -i ""' ;;
  Linux) echo 'sed -i' ;;
  esac
}

fix_scripts_from_binary() {
  local kernel="$1"
  local install_path="$2"

  # shellcheck disable=SC2014,SC2046
  find "$install_path/bin" -type f -perm 755 -exec $(sed_inplace_cmd "$kernel") -e "1s:#!.*:#!$install_path/bin/ruby:" {} \;
}
