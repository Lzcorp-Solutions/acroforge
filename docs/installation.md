# Installation

## Requirements

- Ruby `>= 2.7`
- [HexaPDF](https://hexapdf.gettalong.org/) `~> 1.0` (runtime dependency, installed automatically)

## Installing AcroForge

AcroForge v0.1.0 is not yet published to rubygems.org. Until a stable release lands on the gem index, you must depend on it via a local path or a git URL. Once it is published, a standard `gem install acroforge` or Gemfile entry will work like any other gem.

### Via Gemfile (recommended)

Add one of the following to your `Gemfile`:

```ruby
# Local path — useful when developing against the gem itself
gem "acroforge", path: "/path/to/acroforge"

# Git URL — pin to a tag or commit for reproducibility
gem "acroforge", git: "https://github.com/youruser/acroforge.git"
gem "acroforge", git: "https://github.com/youruser/acroforge.git", tag: "v0.1.0"
```

Then run:

```bash
bundle install
```

### Verifying the install

After `bundle install`, confirm the CLI is on your path:

```bash
bundle exec acroforge version
# => AcroForge 0.1.0
```

Or, if `exe/` is on your `PATH`:

```bash
acroforge version
```
