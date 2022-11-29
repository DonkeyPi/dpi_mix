# Athasha Installer

## Development

```bash
#creates installer-<version> in project folder
mix archive.build
#installs installer-<version>.ez archive to 
#/home/samuel/.asdf/installs/
mix archive.install 
#requires vscode github authentication
mix archive.install git https://github.com/AthashaIO/installer
```

## Config

```bash
#cat .ash_runtime.sel
rpi4
#cat .ash_runtime.exs
[
  {:p3420, target: :host, host: "localhost"},
  {:svmbair, target: :host, host: "localhost"},
  {:rpi4, target: :rpi4, host: "athasha-4ad8.local"},
  {:rpi400, target: :rpi4, host: "athasha-4975.local"},
  {:rpi3, target: :rpi3, host: "athasha-62c2.local"},
  {:qemu, target: :x86_64, host: "athasha-3456.local"}
]
```

## Tasks

```bash
#runtimes defined in mix.exs
#set rpi4 as default runtime
#creates file .ash_runtime.sel
mix ash.runtime rpi4
#arg default to hostname
mix ash.runtime

#queries cookie and shows shell commands
mix ash.shell

#connect to the application log
mix ash.log

#run app on runtime
#build+upload+start
mix ash.run

#upload app to runtime
mix ash.upload

#manages deps for runtime
#task: get | update | clean | ...
mix ash.deps <task> <args...>

#build app for runtime
mix ash.build

#start up in runtime
#auto flag set to true
mix ash.start

#stop up in runtime
#auto flag set to false
mix ash.stop
```

## Roadmap

- [x] Use target from selected runtime config. 
- [-] Load nerves system dependency from runtime config.
  - Deps changes are infrequent
  - Deps will be autogen eventually

## References

- https://www.erlang.org/doc/apps/ssh/using_ssh.html
- https://ferd.ca/dev/repl-a-bit-more-and-less-than-that.html
- https://github.com/rebar/rebar/blob/master/src/rebar_shell.erl
