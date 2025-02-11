#!/usr/bin/env bash

RUBY_BUILD_VERSION="${ASDF_RUBY_BUILD_VERSION:-v20250205}"
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

load_os_release() {
  local os_release

  # Needed for both the distro ID and version ID
  test -e /etc/os-release && os_release='/etc/os-release' || os_release='/usr/lib/os-release'
  # shellcheck source=/dev/null
  source "${os_release}"
}

get_os() {
  local os="${RUBY_BINARY_INSTALL_OS:-}"
  if [[ -z $os ]]; then
    os="$(uname -s | awk '{print tolower($0)}')"
  fi

  echo "$os"
}

get_arch() {
  local arch="${RUBY_BINARY_INSTALL_ARCH:-}"
  if [[ -z $arch ]]; then
    arch="$(uname -m)"
  fi

  echo "$arch"
}

get_linux_distro() {
  local distro="${RUBY_BINARY_INSTALL_DISTRO:-}"
  if [[ -z $distro ]]; then
    distro="${1:-none}"
  fi

  echo "$distro"
}

get_linux_distro_version() {
  local distro_version="${RUBY_BINARY_INSTALL_DISTRO_VERSION:-}"
  if [[ -z $distro_version ]]; then
    distro_version="${1:-none}"
  fi

  echo "$distro_version"
}

get_rvm_io_linux_distro() {
  local distro_slug distro_id

  distro_id="$1"

  if [[ -n "${RUBY_BINARY_INSTALL_DISTRO:-}" ]]; then
    echo "$RUBY_BINARY_INSTALL_DISTRO"
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

get_rvm_io_base_url() {
  local os
  os="$(get_os)"
  case "$os" in
  darwin)
    # There is an osx folder but the binaries haven't been built since 2015
    errorexit "macOS not supported by rvm.io/binaries, install from source instead"
    ;;

  linux)
    load_os_release
    echo "https://rvm.io/binaries/$(get_rvm_io_linux_distro "$ID")/$(get_linux_distro_version "$VERSION_ID")/$(get_arch)"
    ;;
  *) errorexit "OS '$os' not supported by rvm.io/binaries, install from source instead" ;;
  esac
}

get_travis_rubies_base_url() {
  local distro
  if [[ "$(get_os)" != "linux" ]]; then
    errorexit "Non-Linux OSes currently unsupported, install from source instead"
  fi
  load_os_release
  distro="$(get_linux_distro "$ID")"
  if [[ "$distro" != "ubuntu" ]]; then
    errorexit "Travis CI only provides Linux binaries for the Ubuntu distro"
  fi
  echo "https://s3.amazonaws.com/travis-rubies/binaries/$distro/$(get_linux_distro_version "$VERSION_ID")/$(get_arch)"
}

# Replace {...} placeholders with appropriate values
render_custom_url() {
  local url_template="$1"
  local ruby_version="$2"
  local os
  os="$(get_os)"
  if [[ "$os" == "linux" ]]; then
    load_os_release
  fi
  echo "$url_template" | sed \
    -e "s:{distro}:$(get_linux_distro "$ID"):g" \
    -e "s:{distro_version}:$(get_linux_distro_version "$VERSION_ID"):g" \
    -e "s:{os}:$os:g" \
    -e "s:{arch}:$(get_arch):g" \
    -e "s:{ruby_version}:$ruby_version:g"
}

run_gnu_tar() {
  local tar
  case "$(get_os)" in
  darwin) tar=gtar ;;
  *) tar=tar ;;
  esac

  "$tar" "$@"
}

download_and_install_prebuilt_ruby() {
  local base_url download_file filename install_path url
  base_url="$1"
  shift
  filename="$1"
  shift
  install_path="$1"
  shift
  url="$base_url/$filename"
  download_file="$(mktemp -d "${TMPDIR:-/tmp}/asdf-ruby.XXXXXX")/$filename"

  curl --fail --silent --show-error --location --output "$download_file" "$url"
  mkdir -p "$install_path"
  run_gnu_tar --extract --file="$download_file" --directory="$install_path" --preserve-permissions "$@"
}
