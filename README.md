# asdf-ruby

[![Build Status](https://github.com/malept/asdf-ruby/actions/workflows/ci.yml/badge.svg?branch=binary)](https://github.com/malept/asdf-ruby/actions/workflows/ci.yml?query=branch%3Abinary)

Ruby plugin for [asdf](https://github.com/asdf-vm/asdf) version manager

## Install

```
asdf plugin add ruby https://github.com/malept/asdf-ruby.git
```

Please make sure you have the required [system dependencies](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment) installed before trying to install Ruby. It is also recommended that you [remove other ruby version managers before using asdf-ruby](#troubleshooting)

## Use

Check [asdf](https://github.com/asdf-vm/asdf) readme for instructions on how to install & manage versions of Ruby.

When installing Ruby using `asdf install`, you can pass custom configure options with the [env vars supported by ruby-build](https://github.com/rbenv/ruby-build#custom-build-configuration).

Under the hood, asdf-ruby uses [ruby-build](https://github.com/rbenv/ruby-build) to build and install Ruby, check its [README](https://github.com/rbenv/ruby-build/blob/master/README.md) for more information about build options and the [troubleshooting](https://github.com/rbenv/ruby-build/wiki#troubleshooting) wiki section for any issues encountered during installation of ruby versions.

You may also apply custom patches before building with `RUBY_APPLY_PATCHES`, e.g.

```
RUBY_APPLY_PATCHES=$'dir/1.patch\n2.patch\nhttp://example.com/3.patch' asdf install ruby 2.4.1
RUBY_APPLY_PATCHES=$(curl -s https://raw.githubusercontent.com/rvm/rvm/master/patchsets/ruby/2.1.1/railsexpress) asdf install ruby 2.1.1
```

> [!NOTE]
> This plugin does not automatically fetch new Ruby versions. Running `asdf plugin-update ruby` will update asdf-ruby and ensure the latest versions of Ruby are available to install.

By default asdf-ruby uses a recent release of ruby-build, however instead you can choose your own branch/tag through the `ASDF_RUBY_BUILD_VERSION` variable:

```
ASDF_RUBY_BUILD_VERSION=master asdf install ruby 2.6.4
```

### Installing binaries

If `RUBY_BINARY_INSTALL` is set, `asdf-ruby` will install a binary distribution of Ruby from the specified source, as determined by the value of the environment variable. The following valid values are:

* `rvm`
* `travis`
* Custom (templated URL)

The following extra tools are required for this functionality:

* `uname`
* GNU tar

On macOS, GNU tar can be installed via Homebrew:

```shell
brew install gnu-tar
```

#### `rvm`

Installs one of the Ruby binaries provided by RVM via `rvm.io/binaries`. Note that only Linux is supported, and only certain Linux distros and Ruby versions.

The Linux distribution name and version is determined via the [operating system identification standard](https://www.linux.org/docs/man5/os-release.html). To override these values, you can use the `RUBY_BINARY_INSTALL_DISTRO` and `RUBY_BINARY_INSTALL_DISTRO_VERSION` environment variables, respectively.

#### `travis`

Installs one of the Ruby binaries provided by Travis CI via `rubies.travis-ci.org`. Note that only Ubuntu Linux is supported, and only certain Ruby versions are supported for certain Ubuntu versions.

#### Custom

Installs a Ruby binary using the provided templated URL. Valid template values:

* `{ruby_version}` - the version of Ruby to install.
* `{os}` - the lowercase target operating system kernel as reported by `uname -s`. This may be overridden using the `RUBY_BINARY_INSTALL_OS` environment variable.
* `{arch}` - the architecture of the target machine as reported by `uname -m`. This may be overridden using the `RUBY_BINARY_INSTALL_ARCH` environment variable.
* `{distro}` - on Linux, the distribution name (`ID`) as detected by the [operating system identification standard](https://www.linux.org/docs/man5/os-release.html). This may be overridden using the `RUBY_BINARY_INSTALL_DISTRO` environment variable. On all other operating systems, this is `none`.
* `{distro_version}` - on Linux, the distribution version (`VERSION_ID`) as detected by the [operating system identification standard](https://www.linux.org/docs/man5/os-release.html). This may be overridden using the `RUBY_BINARY_INSTALL_DISTRO_VERSION` environment variable. On all other operating systems, this is `none`.

It is assumed that the binaries provided are distributed in tarballs. If there are extra `tar` flags needed to properly extract the tarball, you can provide them via the `RUBY_BINARY_INSTALL_TAR_ARGS` environment variable.

## Default gems

asdf-ruby can automatically install a set of default gems right after
installing a Ruby version. To enable this feature, provide a
`$HOME/.default-gems` file that lists one gem per line, for example:

```
bundler
pry
gem-ctags
```

You can specify a non-default location of this file by setting a `ASDF_GEM_DEFAULT_PACKAGES_FILE` variable.

## Migrating from another Ruby version manager

### `.ruby-version` file

asdf uses the `.tool-versions` for auto-switching between software versions.
To ease migration, you can have it read an existing `.ruby-version` file to
find out what version of Ruby should be used. To do this, add the following to
`$HOME/.asdfrc`:

    legacy_version_file = yes

If you are migrating from version manager that supported fuzzy matching in `.ruby-version`
like [rvm](https://github.com/rvm/rvm) or [chruby](https://github.com/postmodern/chruby),
note that you might have to change `.ruby-version` to include full version (e.g. change `2.6` to `2.6.1`).

## Troubleshooting

> [!NOTE]
> The most common issue reported for this plugin is a missing Ruby version. If you are not seeing a recent Ruby version in the list of available Ruby versions it's likely due to having an older version of this plugin. Run `asdf plugin-update ruby` to get the most recent list of Ruby versions.

If you are moving to asdf-ruby from another Ruby version manager, it is recommended to completely uninstall the old Ruby version manager before installing asdf-ruby.

If you install asdf and asdf-ruby and it doesn't make `ruby` and `irb` available in your shell double check that you have installed asdf correctly. Make sure you have [system dependencies](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment) installed BEFORE running `asdf install ruby <version>`. After installing a Ruby with asdf, run `type -a ruby` to see what rubies are currently on your `$PATH`. The asdf `ruby` shim should be listed first, if it is not asdf is not installed correctly.

Correct output from `type -a ruby` (asdf shim is first in the list):

```
ruby is /Users/someone/.asdf/shims/ruby
ruby is /usr/bin/ruby
```

Incorrect output `type -a ruby`:

```
ruby is /usr/bin/ruby
```
