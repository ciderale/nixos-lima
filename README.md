# NixOS for MacOS using Lima-VM

This project combines [NixOS](nixos.org) with [Lima](lima-vm.io) to provide
reproducible NixOS deployments on MacOS with aarch64 architecture.

## Usage (off-the-shelf)

```
nix run github:ciderale/nixos-lima start
```

The above command boots a VM (named `mynixos`) using lima and deploys an NixOS configuration.
The default configuration includes docker engine and adds some default volume mounts.

## Container support

The default `nixos-lima` configuration includes a docker installation. On VM
creation, `nixos-lima` also generates a shell script `~/.lima/mynixos.shrc` to setup
the DOCKER_HOST and CONTAINER_HOST variable and add `docker` to your PATH.
You could add this to your .zprofile startup script for example.

## Adhoc customization using NIXOS_LIMA_IMPURE_CONFIG

You can extend the system configurations by pointing the NIXOS_LIMA_IMPURE_CONFIG
environment variable to additional configuration files. The configuration includes all
[nixos options](https://search.nixos.org/options) as well as the [lima-vm configurations](https://lima-vm.io).

For example, the following configuration defines cpu/memory/disk size,
additional mount locations from host to guest, and a docker registry mirror.
```
{
  lima.settings = {
    cpus = 8;
    memory = "8GB";
    disk = "60GB";
    mounts = [ { location = "/host/folder/data"; mountPoint = "/data"; } ];
  };
  virtualisation.docker.daemon.settings.registry-mirrors = [ "https://xxx.xxx.xxx" ];
}
```
For more examples see "example/lima-settings.nix". It's worth noting that the options
under `lima.settings` correspond to lima templates and are used to the generate the
`lima.yaml` configuration. Moreover, the mount location must exist or the vm does
not start.

Changes are applied by re-running `nixos-lima start`.

```
NIXOS_LIMA_IMPURE_CONFIG=configuration.nix nix run github:ciderale/nixos-lima start
```

Note that changes to `lima.settings` result in a restart of the VM for those
changes to take effect. Normal nixos options changes are applied by means of
`nixos-rebuild switch` and don't require a VM restart. `nixos-lima` takes care
of the entire process.

Technically, the referenced configuration files are merged into the existing
configuration using the nix modules `{ imports = [ ... ]; }` expression.
Multiple files may be referenced (separated by comma, e.g., `NIXOS_LIMA_IMPURE_CONFIG=sizing.nix,mounts.nix`
and each file may be an absolute path or relative to the current working directory.


## Usage with advanced customisation

More advanced configuration are better versioned explicitly using git. The
`nixos-lima` repository provides a nix flake template to start building the own
configuration. This approach is more flexible and allows to remove configuration
present in the example configuration.

```
# create a new repository to track your changes
cd some/path && mkdir mynixos && cd mynixos
nix flake init -t github:ciderale/nixos-lima

# deploy (and update) the configuration
nix run .#nixos-lima -- mynixos start

# get shell access to your machine
nix run .#nixos-lima -- mynixos ssh
```

# Related work

## https://lima-vm.io

As the name suggests, `nixos-lima` uses lima-vm.io as its underlying
virtualisation system. `nixos-lima` also benefits from the port- and
volume-mapping functionality provided by lima. Configuration in lima is done
via yaml templates and the linux vm is setup using cloud-init scripts.

In contrast, `nixos-lima` has a minimal cloud-init setup and instead relies on
NixOS configurations. NixOS provides a modular configuration system with many
pre-configured services. Moreover, NixOS generates highly reproducible
deployments.

## https://github.com/kasuboski/nixos-lima

`kasuboski/nixos-lima` also aims for running nixos on lima, hence the same
name. A key difference is how the two projects bootstrap a system.

`kasuboski/nixos-lima` uses the [nixos-generator](https://github.com/nix-community/nixos-generators) project to build an initial
image. This approach requires a linux system running nix. For example, a
lima-vm can be used with cloud-init script to setup nix. A benefit of this
is that the generated image can be reused multiple times.

In contrast, `nixos-lima` uses
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to deploy
NixOS onto a freshly started lima-vm. In other words, instead of starting a vm
to build an image, which is then used for a second vm, `nixos-lima` starts one
vm and overwrites that system with the nixos configuration.

Moreover, `nixos-lima` integrates the lima-vm configuration into the NixOS module
system and provides a unified configuration experience.
