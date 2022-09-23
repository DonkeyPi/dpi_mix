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

## Tasks

```bash
#runtimes defined in mix.exs
#set rpi4 as default runtime
#creates file .runtime
mix ash.runtime rpi4
#arg default to hostname
mix ash.runtime

#queries cookie and shows shell commands
mix ash.shell

#run app on runtime
#build+upload+start
mix ash.run

#upload app to runtime
mix ash.upload

#build app for runtime
mix ash.build

#start up in runtime
mix ash.start

#stop up in runtime
mix ash.stop

#auto start in runtime
mix ash.auto true|false
```

## References

- https://www.erlang.org/doc/apps/ssh/using_ssh.html
