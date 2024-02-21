# Containerized Development Environment

Development environment as code. Your dev env in a container with seamless X11 support. You get a gnome-terminal from
where you can start additional windows and programs.

## Details

Runs as a podman container (using an Ubuntu Jammy base image) on an Ubuntu Jammy host.

Your `~/.ssh` and `~/Downloads` are mounted into the container.

The Podman socket is mounted into the container, so you can interact with the host's podman daemon using the podman
client inside the container.

The `~/source` directory in the container is mounted to a volume, so your work there will survive stops and starts of
the container.

## Security considerations

To protect your host, make sure podman runs rootless. Otherwise, if the root user inside the container escapes the
container it will have root privileges on your host.

If you need sudo rights inside your development container you can run `podman exec -it -u 0 devenv /bin/bash` to start
a second session as the root user. Note that this user is only root inside your container, it is mapped to an ephemeral
subordinate UID on your host.

## Requirements

- Linux
- Git (`sudo apt install git`)
- Podman (`sudo apt install podman`)

This has only been tested on an Ubuntu Jammy host.

## Getting started

* Clone this repo:

```shell
git clone https://github.com/jonaslind/devenv.git
```

* Start the Development Environment:

```shell
./devenv
```

The first time the development environment starts it'll ask you for your name and email. These are used to set up the
`~/.gitconfig` file inside the container. You only need to enter this once, your answers are remembered (stored in
`~/.local/devenv/` on the host) for the next time.

## Why?

- When you change laptop you only need to install git and podman, the rest is recreated by the utility.
- You can run several different conflicting environments in parallel.
- Try out changes, new versions of software etc and throw it away if it doesn't work out.
- Version controlled source code of all your settings and installations.

## Customizing

This environment is obviously set up with software and settings that I prefer. There is no ambition to create a
development environment that suits everyone. You should have your tools of the trade set up just the way you like it.

However, you can use this repository as a blueprint to modify into whatever setup you prefer.
