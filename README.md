# Athasha Installer

## Development

```bash
mix archive.build
#creates installer-0.1.0.ez
```

## Tasks

```bash
#set rpi4 as default runtime
#runtimes defined in mix.exs
#creates file .runtime
mix ash.runtime rpi4
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
