# Installation

## Requirements

- Ruby `>= 2.7`
- [HexaPDF](https://hexapdf.gettalong.org/) `~> 1.0` (runtime dependency, installed automatically)

## Installing AcroForge

AcroForge v0.1.0 is not yet published to rubygems.org. Until a stable release lands on the gem index, you must depend on it via a local path or a git URL. Once it is published, a standard `gem install acroforge` or Gemfile entry will work like any other gem.

### Via Gemfile (recommended)

Add one of the following to your `Gemfile`:

```ruby
# Local path: useful when developing against the gem itself
gem "acroforge", path: "/path/to/acroforge"

# Git URL: pin to a tag or commit for reproducibility
gem "acroforge", git: "https://github.com/Lzcorp-Solutions/acroforge.git"
gem "acroforge", git: "https://github.com/Lzcorp-Solutions/acroforge.git", tag: "v0.1.0"
```

Then run:

```bash
bundle install
```

### Verifying the install

After `bundle install`, confirm the CLI works inside the bundler context:

```bash
bundle exec acroforge version
# => 0.1.0
```

## Making `acroforge` available globally

Bundler's `path:` and `git:` dependencies only expose the CLI through `bundle exec` from inside a project's Gemfile. To run `acroforge` as a plain command from any directory, like a normal Unix tool, install the gem into your Ruby environment.

### From a clone of the repo (recommended for now)

```bash
git clone https://github.com/Lzcorp-Solutions/acroforge.git ~/acroforge
cd ~/acroforge
bundle install
rake install
```

`rake install` (provided by Bundler's gem tasks) builds the gem and runs `gem install acroforge-0.1.0.gem` for you. After this, your Ruby version manager (rbenv, asdf, rvm, or chruby) places the binary on your `PATH` via its standard shim or gemset bin directory.

Verify:

```bash
which acroforge
# /home/you/.rbenv/shims/acroforge   (or equivalent)

acroforge version
# 0.1.0
```

### After future updates

Pull the latest code and re-run `rake install`:

```bash
cd ~/acroforge
git pull
rake install
```

### Once published to rubygems.org

The above ceremony goes away. A single `gem install acroforge` will fetch from the index and put `acroforge` on your `PATH`.

### If your shell still can't find `acroforge`

Your Ruby environment's bin directory isn't on `PATH`. Find it with:

```bash
gem environment | grep -i 'executable directory'
# EXECUTABLE DIRECTORY: /home/you/.gem/ruby/3.3.0/bin   (example)
```

Add that path to your shell rc:

```bash
echo 'export PATH="$(gem env | sed -n "/EXECUTABLE DIRECTORY/s/.*: //p"):$PATH"' >> ~/.bashrc
```

(Adjust for `~/.zshrc` or `~/.config/fish/config.fish` accordingly.)
