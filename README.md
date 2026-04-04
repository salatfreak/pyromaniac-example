# Declarative Server Configuration Example using Pyromaniac
This repository contains a complete and production-ready declarative configuration for a server
running [Nextcloud][nextcloud] and [Gitea][gitea] behind a [Caddy][caddy] reverse proxy. It
primarily serves as an example and template for building your own declarative server deployments
using the [Pyromaniac][pyromaniac] framework and the [Pyromaniac Basics Library][pyromaniac-lib]. An
[Ignition][ignition] file or a bootable *ISO* installer image can be generated from this
configuration with a single command, respectively.

Being based on [Fedora CoreOS][fcos], *Pyromaniac* deployments are self-maintaining, have strong
security defaults, and can run on a [variety of platforms][fcos-platforms], whether it's an old x86
box, a *Raspberry Pi*, or a virtual machine at the cloud provider of your choice.

The comments scattered throughout the configuration code aim to make it straightforward to
understand. Please consult the documentation of [Pyromaniac][pyromaniac] and the [Basics
Library][pyromaniac-lib] to learn about the syntax and the employed components you encounter here.

[nextcloud]: https://nextcloud.com/
[gitea]: https://about.gitea.com/
[caddy]: https://caddyserver.com/
[pyromaniac]: https://salatfreak.github.io/pyromaniac/
[pyromaniac-lib]: https://github.com/salatfreak/pyromaniac-lib
[ignition]: https://coreos.github.io/ignition/
[fcos]: https://fedoraproject.org/coreos/
[fcos-platforms]: https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/

## Design Objectives
Demonstrating a variety of best practices regarding project structure, security, and performance
is another central objective of this code base.

### Project Structure
The project is divided into a set of configurable modules (in the *modules* directory) that are
invoked and parameterized from the main component (*main.pyro*) using the [*lib.modules*
component][lib-modules]. The main component loads the relevant parameters from *TOML* files placed
in the *config* directory. *Pyromaniac*'s ability to produce different deployments from a single
code base is showcased through the *debug* parameter in the main component's signature, which can be
assigned by passing the `--debug` flag to *Pyromaniac* as described later in this document.

Most of the configuration adheres to functional programming principles, and the *GLOBAL* variable is
accessed only sparingly. It is, however, used to collect the services exposed through *Caddy* and
the ports opened/forwarded through the firewall. This is made explicit by passing the path to the
respective data structures inside the *GLOBAL* variable as a parameter to the respective component.

### Security
*Fedora CoreOS* already provides a solid basis for well-secured deployments through its minimal
design, [automatic, atomic, and reversible updates][fcos-updates], and enforced *SELinux* rules. We
maintain that minimalism by relying on *Systemd* and [Podman Quadlets][quadlets] instead of adding
complexity that might not be needed through systems like *Podman Compose* or even *Kubernetes*.

To harden the system further, we run each service as a separate *Linux* user in rootless *Podman*
containers. A firewall and additional security configurations are part of the deployment as well.
Notably, the *SSHD* server runs on a configurable non-standard port, and the users' authorized keys
are stored in a way that only the root user can modify them.

### Networking
Listening on privileged *TCP* ports despite running the services as non-privileged users is achieved
through *Netfilter* port translation. Rootless networking through *slirp4netns* or *pasta* usually
comes with a performance penalty because forwarding of traffic into the containers happens in user
space. To circumvent this for the *HTTP(S)* traffic handled by our containers, we run *Caddy* with
host networking and forward the requests to *Nextcloud* and *Gitea* via *Unix Domain Sockets*. This
should be even more efficient than regular rootful container networking and offers security
advantages as well.

### Secret Management
There are no secrets or passwords contained in the production configuration. Instead, *SSHD* keys
and admin passwords for *Nextcloud* and *Gitea* are generated when first provisioning the machine
and stored on a persistent partition along with the container and application data.

The admin accounts are automatically created, and open registration is disabled for both services,
making it reasonably safe to deploy the configuration live to the internet right away. After logging
in to the *core* user account via *SSH*, you can conveniently switch to any of the accounts running
the services by executing `switch caddy`, `switch nextcloud`, or `switch gitea`, respectively. As
the *nextcloud* or *gitea* user, you can then retrieve the generated admin credentials by running
`print-admin-credentials`.

[lib-modules]: https://github.com/salatfreak/pyromaniac-lib#parameterize-execute-and-merge-modules-from-specified-directory
[fcos-updates]: https://docs.fedoraproject.org/en-US/fedora-coreos/auto-updates/
[quadlets]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html

## Compiling the Configuration
First of all, you need to complete your individual configuration by copying *config/main.toml.tmpl*
to *config/main.toml* and *config/debug.toml.tmpl* to *config/debug.toml* and adapting them to your
needs.

After [installing *Pyromaniac*][pyromaniac-install], an *Ignition* configuration can now simply be
generated through the following command.

```bash
pyromaniac . > config.ign
```

To create a bootable *ISO* image that installs the system automatically to */dev/vda*, the following
command may be used.

```bash
pyromaniac --iso-disk /dev/vda . > installer.iso
```

To create a debug build for testing in a local VM, you can set the main component's *debug*
parameter to *true* by passing the `--debug` flag on the command line. Parameters for the main
component [need to be passed as positional parameters][pyromaniac-main-params]. You can therefore
generate the debug build by appending `-- --debug` to the above commands, respectively.

The debug build will load the *config/main.toml* configuration as usual but override any options
specified in *config/debug.toml*. It will also generate a self-signed TLS certificate instead of
retrieving one via *ACME*. Study the *main.pyro* file to understand exactly how it works.

[pyromaniac-install]: https://salatfreak.github.io/pyromaniac/installation.html
[pyromaniac-main-params]: https://salatfreak.github.io/pyromaniac/components-signature.html#passing-arguments-to-the-main-component

## Installation
The simplest way to install the system is to generate an *ISO* image as described above and boot it
on a machine with a clean drive to install the system to. To avoid data loss, the installation might
abort if partition tables or filesystems are already found on the drive. There is no interaction
required during the installation, and when everything is done, you'll be booted into the server
running all services as configured.

### Mutually Authenticated Network Retrieval
To avoid having to generate a new *ISO* image every time you would like to install a revised version
of your configuration, you can build the installer once and have it load the actual configuration
via the network. *Pyromaniac* [supports generating such remote installers][pyromaniac-remote] very
easily, including encrypted and mutually authenticated transmission of the configuration.

Assuming your development machine is reachable at *192.168.1.10* and your firewall allows incoming
traffic on TCP port 8080, you can generate a remote installer by executing the following command.

```bash
pyromaniac \
  --iso-disk /dev/vda \
  --address https://192.168.1.10:8080/ \
  <<< '`remote()`' > installer-remote.iso
```

*Pyromaniac* will automatically generate a self-signed *TLS* certificate and *HTTP* basic
authentication credentials and embed them into the *ISO* image. Your configuration is therefore
protected from being sniffed or manipulated even when serving it over an untrusted network like the
internet.

You can now serve your actual configuration by executing the following.

```bash
pyromaniac --serve --address https://192.168.1.10:8080/ .
```

On every request by the remote installer, the configuration will be recompiled and served to it.
You can simply leave the command running in the background, make your changes, and reprovision your
machine by booting into the remote installer whenever you would like to apply the current state of
the configuration. This allows for quick iteration when refining your deployment.

[pyromaniac-remote]: https://salatfreak.github.io/pyromaniac/recipes-remote.html

### Simple Virtual Machine
Virtual machines are the quickest way to test your configurations locally on your machine. You do
not need graphical or *CLI* management tools like *Virtual Machine Manager* or *virsh*, though. You
don't even need root privileges or a graphical session at all to run *Fedora CoreOS* in a virtual
machine.

The *scripts/vm.sh* script makes sure a virtual disk exists and directly executes *QEMU* as your
unprivileged *Linux* user account. It attaches *STDIN* and *STDOUT* of your terminal session as a
serial console to your *VM*, allowing you to monitor the boot logs, interact with the rescue shell,
or log in to the *CoreOS* system, e.g. in case you locked yourself out of *SSH*. What's especially
useful is the ability to conveniently scroll through the entire boot and shutdown logs in your
terminal emulator, which you don't get when using a virtual pixel display instead of a serial
console. You can enter the QEMU command line, e.g. to cleanly shut down or reboot your *VM*, by
pressing *Ctrl-a* followed by the *C* key. Use the *X* key instead of the *C* key to terminate the
machine instantly without a clean shutdown.

You'll have to configure the kernel to use the serial console when generating your installer *ISO*
as follows.

```bash
pyromaniac --iso-raw-{live,dest}-karg-append=console=ttyS0 --iso-disk /dev/vda . > installer-vm.iso
```

You can now install the system in a virtual machine by executing `scripts/vm.sh --install
installer-vm.iso`. To boot the installed machine again later, simply execute `scripts/vm.sh` without
any parameters.

**Bonus:** Combine this with loading your configuration over *HTTP(S)* as described above. Kill the
machine after the installer has copied the base system to your virtual disk (when it reboots for the
first time). Now create a snapshot of the disk by executing `qemu-img snapshot -c before-remote
virtual-machine/root.qcow2`. You can now jump back to that snapshot whenever you like by executing
`qemu-img snapshot -a before-remote virtual-machine/root.qcow2`. If you boot the *VM* now, it will
immediately request the current configuration via *HTTP(S)*, apply it, and you'll be booted into the
provisioned system in well below a minute. This allows for truly rapid iteration during
development.

[download]: https://fedoraproject.org/coreos/download/?stream=stable
[docs]: https://docs.fedoraproject.org/en-US/fedora-coreos/

### Reprovisioning
Since this configuration stores all important data on a separate persistent partition, you can
reprovision your machine with a new configuration without losing your *SSHD* keys, login
credentials, or data stored in container volumes. You don't need to (and shouldn't!) make manual
changes to your running system (except for quickly testing them out). Instead, you simply adapt your
*Pyromaniac* config and reprovision the machine with it.

Even when fetching the configuration over *HTTP(S)*, keeping an up-to-date remote installer around,
starting your *Pyromaniac* server, and rebooting into the installation process is more work than
should be required to apply a simple configuration change, though. This deployment includes the
*Basic Library*'s [quick-reprovision][lib-quick-reprovision] component to make reprovisioning even
easier. All you need to do is run the *quick-reprovision* script in the booted system and feed it a
new *Ignition* file. Generating the *Ignition* code, transmitting it to the server via *SSH*,
applying it, and rebooting into the new deployment can be done in a single command line. Assuming
your server is reachable at *example.com* and *SSHD* runs on port 19521, simply execute the
following.

```bash
pyromaniac . | ssh -p 19521 core@example.com sudo quick-reprovision --now
```

Your system will apply the configuration and reboot. If anything fails, the changes will be rolled
back and you'll reboot into your current configuration. If the reprovisioning succeeds but something
breaks anyway, you can select the previous deployment from the boot loader menu to roll back
manually. Custom disk layouts, *RAID*s, and encryption are supported too. What you cannot do,
though, is make changes to your disk layout, *GRUB* configuration, or kernel parameters this way.

[lib-quick-reprovision]: https://github.com/salatfreak/pyromaniac-lib#add-service-for-quickly-reprovisioning-the-machine-without-reinstallation
