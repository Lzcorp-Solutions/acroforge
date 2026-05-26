# Installation

## Requirements

- Ruby `>= 2.7`
- [HexaPDF](https://hexapdf.gettalong.org/) `~> 1.0` (runtime dependency, installed automatically)

If you don't already have a Ruby version manager, [mise](https://mise.jdx.dev/) is a good default. It manages Ruby alongside Node, Python, and other runtimes:

```bash
mise use --global ruby@3.3
```

## Install AcroForge

```bash
gem install acroforge
```

That's it. The `acroforge` command is now on your `PATH` and runnable from any directory:

```bash
acroforge version
# 0.1.0

acroforge help
```

This is the same mechanism Rails uses. `gem install` writes the executable into your Ruby environment's binary directory, and mise (or rbenv, asdf, rvm) keeps that directory on `PATH` through its shim layer. No manual setup, no shell config changes.

## Embedding AcroForge in a Ruby project

If you want AcroForge as a **library inside another Ruby application** (not as a global CLI), add it to your `Gemfile`:

```ruby
gem "acroforge"
```

Then `bundle install`. Inside that project, call the library API directly:

```ruby
require "acroforge"
AcroForge::Engine.new("form.pdf", schema: ...).fill!(payload, "out.pdf")
```

The CLI is still reachable via `bundle exec acroforge` inside the project. Using `gem install` globally and using a Gemfile dependency in a project are not mutually exclusive: do both if you need both.

## Install from source

If you want to work *on* AcroForge (contributing, hacking, testing unreleased changes), clone the repo and install your local build:

```bash
git clone https://github.com/Lzcorp-Solutions/acroforge.git
cd acroforge
bundle install
rake install
```

`rake install` builds the gem from your working tree and installs it the same way `gem install acroforge` would. To pick up changes after `git pull` or local edits, re-run `rake install`. With mise, run `mise reshim` if the shim doesn't pick up the new binary immediately.

## Troubleshooting

### `acroforge: command not found` after `gem install`

Your Ruby environment's executable directory is missing from `PATH`. This rarely happens with a version manager but is common with system Ruby. Find the directory:

```bash
gem environment | grep -i 'executable directory'
# EXECUTABLE DIRECTORY: /home/you/.local/share/mise/installs/ruby/3.3.0/bin
```

If you use mise and the binary exists in mise's installs path but isn't on your `PATH`, re-shim:

```bash
mise reshim
```

For other setups, add the bin directory to your shell rc:

```bash
# Bash
echo 'export PATH="$(gem env home)/bin:$PATH"' >> ~/.bashrc

# Zsh
echo 'export PATH="$(gem env home)/bin:$PATH"' >> ~/.zshrc

# Fish
fish_add_path (gem env home)/bin
```

Restart your shell or source the rc file, then `acroforge version` should resolve.

### Verifying the install

```bash
which acroforge
# /home/you/.local/share/mise/shims/acroforge   (mise)
# /home/you/.rbenv/shims/acroforge              (rbenv)
# /home/you/.asdf/shims/acroforge               (asdf)

acroforge version
# 0.1.0
```
