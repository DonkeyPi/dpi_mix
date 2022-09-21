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
mix ash.run <rt>
#upload app to target
mix ash.upload
#start up in target
mix ash.start
#stop up in target
mix ash.stop
```
