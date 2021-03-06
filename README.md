# A simple filesystem containerizer

Tired of intricate container frameworks? Just want a better chroot for
building things in? This is for you!

## Installation

It needs no more than a recent util-linux (with unshare) and sudo:
users who can create containers need to be added to /etc/sudoers
like so:

```
CONTAINERERS ALL = (root) NOPASSWD: CONTAINERIZE
```

## Container organization and syntax

Containers are located in a fixed place in the filesystem, under /trees,
arranged in groups, e.g. /trees/group/root1, /trees/group/root2, etc. Each group
is a set of distinct filesystem hierarchies (instances) which all share the same
configuration.

The syntax of containerize is

```
containerize GROUP CONTAINER [COMMAND ...]
```

which sets up the container (if no containerize session is already live in that
container), chroots into `/trees/$GROUP/$CONTAINER`, and runs `COMMAND` in it (by
default, `bash`).

## Creating container images

We have no hub, no collections of containers, all we have is a filesystem
hierarchy. You can get them via rsync from inside virtual machines, or simply
boot your VMs via netbooting and nfsroot or something and store the whole VM in
a container under /trees.  Copying a container is as easy as cp (using a
filesystem capable of reflinking is strongly recommended, so you can use
cp --reflink to make copies efficiently).

## Container configuration

Container configuration is stored under `/trees/group/.container`. Mostly it's
little bash scripts. All are optional, though the directory must be present.
None are executed if this is a containerize being run while another containerize
is already active on the same container: in that case, we just join the existing
container, so no setup is needed.

### `bind`

Invoked as `bind /trees/$GROUP/$INSTANCE $GROUP $INSTANCE` immediately after
unsharing, before any filesystems are mounted or the chroot is done: can
bind-mount filesystems into place. (`/proc`, `/sys`, and `/dev` are always
bind-mounted into place from the host, and `/tmp` is always a new empty tmpfs.)

Trivial example for a Debian container:

```
#!/bin/sh

mount --rbind /usr/src $1/usr/src
mount --rbind /trees/apt-caches/x86_64 $1/var/cache/apt
rm -f $1/usr/sbin/policy-rc.d
ln $1/usr/sbin/policy-rc.d.container $1/usr/sbin/policy-rc.d
```

### `unbind`

The converse of `bind`, invoked right before exiting, outside the chroot, after
/proc and the like are unmounted. Invoked with one argument,
`/trees/$GROUP/$INSTANCE`. Should tear down any persistent changes made by the
bind script.  There is usually no need to unmount anything: the lazy unmount done
by the containerize script should suffice.

Trivial example:

```
#!/bin/sh

rm -f $1/usr/sbin/policy-rc.d
```

### `profile`

This shell script is invoked while chrooted into the container right before
anything else is done. It is the only script executed from the same perspective
as processes that will run inside the container itself. (It's actually
bind-mounted into the container under /tmp and invoked in a chroot used for
nothing else). It can do general setup work of various sorts, but it's not
suitable for propagating things into the shell environment, despite its name.

### `cgroup-name`

This plain file gives the name of the cgroup that owns all the processes in this
container.  If not present, `"containerize"` is used.

### `unshare-options`

This plain file gives extra options to `unshare(1)`. It can be used to unshare
more than just the mount namespace.  You can't change the mount propagation,
which is always 'slave' (this limitation will defintely be lifted in future).

### `stop`

Invoked as `stop /trees/$GROUP/INSTANCE $INSTANCE_PID` right after the container is
terminated, before anything is unmounted.  Can do general cleanup of things like
processes if that is wanted:

```
#!/bin/sh

CGROUP=containerize
if [[ -x $1/../.container/cgroup-name ]]; then
    CGROUP="$(cat $1/../.container/cgroup-name)"
fi 

[[ ! -d /sys/fs/cgroup/$CGROUP/$2 ]] && exit 0

cat /sys/fs/cgroup/$CGROUP/$2/cgroup.procs | while read -r PID; do
    kill -9 $PID
done
```

## Limitations

There is no attempt at security: anyone who can do anything with any containers
can do everything with all of them.  If you don't like this, wrap containerize
in a script which does extra validation (the syntax is easy enough), or use
a real container system which pays at least a bit of attention to such things.
Obviously, since we only unshare filesystems by default, there is no attempt
to make anything involving hostile guests work either!

There is no refcounting of containers: the first prompt you start in a given
container owns that container, and when you leave it all the mounts are
terminated. So it's best to start one prompt in a given container and not exit
it until you've exited all the others. (This would be an easy restriction to
overcome, but for the "build stuff" use case this is rarely needed, so I haven't
bothered.)

## Bugs

Exiting sometimes leaves `/trees/GROUP/.container/*.pid` files behind, leading to
future containerizations failing.  Fix trivial, but I want to figure out why
it's happening rather than just kludge around it, so I haven't fixed it yet
to annoy myself into solving it properly.
