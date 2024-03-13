FROM ubuntu:jammy

ARG USERID
ARG GROUPID
ARG USERNAME
ARG FULLNAME
ARG EMAIL

# Use bash instead of sh to be able to use process substitution in RUN commands.
SHELL ["/bin/bash", "-c"]

# Install software!
#
# We're basing this image on ubuntu and I'm trusting the default apt repos.
#
# Unfortunately we're getting a very old podman version this way.
#
RUN apt update && apt upgrade -y && \
  export DEBIAN_FRONTEND="noninteractive" && \
  export TZ="Europe/Stockholm" && \
  apt install -y \
  ack \
  bash-completion \
  build-essential \
  curl \
  dconf-cli \
  dbus-x11 \
  file \
  fonts-noto \
  git \
  gitk \
  gnome-icon-theme \
  gnome-terminal \
  jq \
  libcanberra-gtk-module \
  libcanberra-gtk3-module \
  libglib2.0-bin \
  libxml2-dev \
  libxslt-dev \
  meld \
  net-tools \
  netcat \
  openjdk-21-jdk \
  openjdk-21-source \
  podman \
  python3 \
  python3-dev \
  python3-pip \
  python3-tk \
  ruby-full \
  sudo \
  unzip \
  vim \
  wget \
  x11-apps \
  zlib1g-dev

# Make podman use remote by default.
# This is much easier to achieve by using the CONTAINER_HOST environment variable on more modern versions of podman.
RUN \
  mv /usr/bin/podman /usr/bin/podman-local && \
  echo -e '#!/bin/bash\npodman-local --remote "$@"\nexit $?' > /usr/bin/podman && \
  chmod 755 /usr/bin/podman

# Make sure we're using the latest pip
RUN \
  pip install --upgrade pip wheel setuptools Cython

# Yq is not published in any apt repo that I trust, so let's take it directly from github.
#
# I'm locking down the specific version and verifying the binary's sha512 sum to protect against supply chain attacks.
# Obviously, when we upgrade yq version we need to update the checksum too.
#
# If the sha512 checksum mismatches then the RUN process will fail. But note how the tar command inside the process
# substitution is asynchronous and may fail without that error propagating to the parent process. In that case we're
# saved by the mv command which WILL fail if the tar command didn't manage to extract the file.
RUN \
  cd /usr/bin && \
  curl -L https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64.tar.gz | \
    tee >(tar xz --no-same-owner -f- ./yq_linux_amd64) | \
    sha512sum -c <(echo "33d0f3a96dcbe0f4382eb7087850ee7678999fc1a3c760a0b908d5d0fae82fc9df76651957cdd80eb880f8ec7c461f953f5109ab6db551518e495a1af2d63862 -") && \
  mv yq_linux_amd64 yq

# Maven
#
# See above for detailed explanation about what's going on here. Here the cd command will save us in case the
# substituted process fails.
#
RUN \
  cd /opt && \
  curl -L https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz | \
    tee >(tar xz --no-same-owner -f-) | \
    sha512sum -c <(echo "706f01b20dec0305a822ab614d51f32b07ee11d0218175e55450242e49d2156386483b506b3a4e8a03ac8611bae96395fd5eec15f50d3013d5deed6d1ee18224 -") && \
  cd apache-maven-* && \
  MAVENHOME=$(pwd) && \
  cd /usr/bin && \
  ln -s ${MAVENHOME}/bin/mvn mvn

# Eclipse
#
# See above for detailed explanation about what's going on here. Here the cd command will save us in case the
# substituted process fails.
# 
RUN \
  cd /opt && \
  curl -L https://ftp.acc.umu.se/mirror/eclipse.org/technology/epp/downloads/release/2024-03/R/eclipse-jee-2024-03-R-linux-gtk-x86_64.tar.gz | \
    tee >(tar xz --no-same-owner -f-) | \
    sha512sum -c <(echo "d674d5eb95c4836440463a89dc8f849e45057d2f89e7b698c48f342c82e169d1ab6dc2c697654474c3ecd5625d04a593db3c1e06984d3596db1e86cabad1eb2f -") && \
  cd eclipse* && \
  ECLIPSEHOME=$(pwd) && \
  cd /usr/bin && \
  ln -s ${ECLIPSEHOME}/eclipse eclipse && \
  echo '-Dorg.eclipse.oomph.setup.donate=false' >> /opt/eclipse/eclipse.ini

# Protobuf compiler
RUN \
  cd /usr/bin && \
  curl -L https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-linux-x86_64.zip --output protoc.zip && \
  sha512sum -c <(echo "75da030a2c9fb3ccd689a2beaeab42d44803b314410f6578c7af030d1ac29d3de1260a4fb50eca5c8efbcd1ac4a94b4a130e45afebf8a182d6c1d3241a2f8dba protoc.zip") && \
  unzip -p protoc.zip bin/protoc > protoc && \
  chmod 755 protoc && \
  rm protoc.zip

# Node.js
RUN \
  cd /opt && \
  curl -L https://nodejs.org/dist/v20.11.0/node-v20.11.0-linux-x64.tar.gz | \
    tee >(tar xz --no-same-owner -f-) | \
    sha256sum -c <(echo "9556262f6cd4c020af027782afba31ca6d1a37e45ac0b56cecd2d5a4daf720e0 -") && \
  cd node-* && \
  NODEHOME=$(pwd) && \
  cd /usr/bin && \
  ln -s ${NODEHOME}/bin/corepack corepack && \
  ln -s ${NODEHOME}/bin/node node && \
  ln -s ${NODEHOME}/bin/npm npm && \
  ln -s ${NODEHOME}/bin/npx npx

# Java Preferences Utility
RUN \
  mkdir /opt/javaprefs && \
  chmod 755 /opt/javaprefs
COPY javauserprefadd /opt/javaprefs/.
RUN \
  chmod 755 /opt/javaprefs/javauserprefadd && \
  cd /usr/bin && \
  ln -s /opt/javaprefs/javauserprefadd javauserprefadd

# Create the user
RUN \
  groupadd -g $GROUPID $USERNAME && \
  useradd -u $USERID -g $GROUPID --create-home --home-dir /home/$USERNAME -s /bin/bash $USERNAME && \
  chown -R $USERNAME:$USERNAME /home/$USERNAME

USER $USERNAME

# JMeter and Custom Thread Groups plugin
# Must be installed as user, not root, otherwise plugin manager won't work with Taurus.
RUN \
  mkdir -p $HOME/.local/bin && \
  cd $HOME/.local && \
  curl -L https://dlcdn.apache.org/jmeter/binaries/apache-jmeter-5.6.3.tgz | \
    tee >(tar xz --no-same-owner -f-) | \
    sha512sum -c <(echo "5978a1a35edb5a7d428e270564ff49d2b1b257a65e17a759d259a9283fc17093e522fe46f474a043864aea6910683486340706d745fcdf3db1505fd71e689083 -") && \
  cd apache-jmeter-* && \
  JMETERHOME=$(pwd) && \
  cd $HOME/.local/bin && \
  ln -s ${JMETERHOME}/bin/jmeter jmeter && \
  cd ${JMETERHOME}/lib/ext && \
  curl -L https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/1.10/jmeter-plugins-manager-1.10.jar --output jmeter-plugins-manager-1.10.jar && \
  sha512sum -c <(echo "38af806a7c78473c032ba93c7a2e522674871f01616985a0b0522483977d58afdc444d18bd5590b8036c344ccf11d2fe61be807501d5edb6d4bdebc9050c43ae jmeter-plugins-manager-1.10.jar") && \
  cd ${JMETERHOME}/lib && \
  curl -L https://repo1.maven.org/maven2/kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar --output cmdrunner-2.3.jar && \
  sha512sum -c <(echo "7f71fe42f4ead4ccddd68148e97a46b9262bdb05fe5e590a725331513549122dc64d4cb524635b2f0e3e7d3ee4bb3c2807738cd3c7e2d0d7a503ea78234dab51 cmdrunner-2.3.jar") && \
  java -cp ${JMETERHOME}/lib/ext/jmeter-plugins-manager-1.10.jar org.jmeterplugins.repository.PluginManagerCMDInstaller && \
  ${JMETERHOME}/bin/PluginsManagerCMD.sh install jpgc-casutg=2.10

# Use JMeter's SolarizedDarkTheme
RUN \
  javauserprefadd "/org/apache/jmeter/gui/action" "laf.command" "com.github.weisj.darklaf.DarkLaf:com.github.weisj.darklaf.theme.SolarizedDarkTheme"

# Taurus
RUN \
  pip install bzt

# Taurus settings
# Taurus doesn't handle symlinks to jmeter well, so we need to specify the real path to jmeter
RUN \
  touch ~/.bzt-rc && \
  chmod 600 ~/.bzt-rc && \
  echo $'modules:\n\
  jmeter:\n\
    path: '$(readlink -f $HOME/.local/bin/jmeter)$'\n' >> ~/.bzt-rc

# Suppress sudo warning when starting terminal
RUN \
  touch ~/.sudo_as_admin_successful

# Beautiful default monospace font and no menubar in the terminal
RUN \
  dbus-launch gsettings set org.gnome.desktop.interface monospace-font-name "'DejaVu Sans Mono 14'" && \
  dbus-launch gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false

# Solarized color theme
#
# I'm checking out a specific gitsha of the gnome-terminal-colors-solarized repo to protect against supply chain
# attacks. Likewise, I'm downloading a specific gitsha of dircolors-solarized to be sure what I'm getting.
#
RUN \
  cd /tmp && \
  git clone https://github.com/aruhier/gnome-terminal-colors-solarized.git && \
  cd gnome-terminal-colors-solarized && \
  git reset --hard 9651c41df0f89e87feee0c798779abba0f9395e0 && \
  dbus-launch ./install.sh --skip-dircolors -s light -p $(gsettings get org.gnome.Terminal.ProfilesList list | sed "s/.*'\([^']\{1,\}\)'.*/\1/") && \
  cd /tmp && \
  rm -rf /tmp/gnome-terminal-colors-solarized && \
  mkdir ~/.dir_colors && \
  chmod 700 ~/.dir_colors && \
  mkdir dircolors-solarized && \
  cd dircolors-solarized && \
  curl -L https://raw.github.com/seebi/dircolors-solarized/664dd4e91ff9600a8e8640ef59bc45dd7c86f18f/dircolors.ansi-light >> ~/.dir_colors/dircolors && \
  cd /tmp && \
  rm -rf dircolors-solarized

# Make podman connect to the podman running on the host by default
RUN \
  podman system connection add host unix:///run/user/1000/podman/podman.sock

# Jekyll
RUN \
  export GEM_HOME="/home/$USERNAME/gems" && \
  gem install jekyll bundler

# Nice .bashrc and .profile
RUN \
  touch ~/.bashrc && \
  chmod 700 ~/.bashrc && \
  echo 'export SHELL="/bin/bash"' >> ~/.bashrc && \
  echo 'eval `dircolors /home/'$USERNAME'/.dir_colors/dircolors`' >> ~/.profile && \
  echo 'export CHEESE_WEDGE=$(echo -e '"'"'\U1f9c0'"'"')' >> ~/.bashrc && \
  echo 'export COW_FACE=$(echo -e '"'"'\U1f42e'"'"')' >> ~/.bashrc && \
  echo 'export SPIRAL_SHELL=$(echo -e '"'"'\U1f41a'"'"')' >> ~/.bashrc && \
  echo 'export WEBKIT_DISABLE_COMPOSITING_MODE=1' >> ~/.bashrc  && \
  echo 'export TZ="Europe/Stockholm"' >> ~/.bashrc  && \
  echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc && \
  echo 'export PATH="$HOME/.local/bin:$HOME/gems/bin:$PATH"' >> ~/.bashrc && \
  echo 'export SSH_AUTH_SOCK=/run/user/'$USERID'/keyring/ssh' >> ~/.bashrc && \
  echo 'PS1='"'"'${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\] $CHEESE_WEDGE '"'"'' >> ~/.bashrc && \
  echo 'cd $HOME' >> ~/.bashrc

# Git config
RUN \
  git config --global user.name "$FULLNAME" && \
  git config --global user.email "$EMAIL"

# Mount points
RUN \
  mkdir ~/Downloads && \
  chmod 755 ~/Downloads && \
  mkdir ~/.ssh && \
  chmod 700 ~/.ssh && \
  mkdir ~/.m2 && \
  chmod 700 ~/.m2 && \
  mkdir ~/.m2/repository && \
  chmod 700 ~/.m2/repository && \
  mkdir ~/.eclipse && \
  chmod 700 ~/.eclipse && \
  mkdir ~/eclipse-workspace && \
  chmod 700 ~/eclipse-workspace && \
  mkdir ~/source && \
  chmod 700 ~/source

# Eclipse preferences
RUN \
  mkdir -p                                            ~/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/
COPY org.eclipse.ui.workbench.prefs     /home/$USERNAME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.ui.workbench.prefs
COPY org.eclipse.ui.ide.prefs.workspace /home/$USERNAME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.ui.ide.prefs
COPY org.eclipse.jdt.ui.prefs           /home/$USERNAME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.jdt.ui.prefs
COPY org.eclipse.ui.editors.prefs       /home/$USERNAME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.ui.editors.prefs
COPY org.eclipse.wst.xml.core.prefs     /home/$USERNAME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.wst.xml.core.prefs
RUN \
  mkdir -p                                            ~/.eclipse/org.eclipse.platform_4.31.0_1473617060_linux_gtk_x86_64/configuration/.settings/
COPY org.eclipse.ui.ide.prefs           /home/$USERNAME/.eclipse/org.eclipse.platform_4.31.0_1473617060_linux_gtk_x86_64/configuration/.settings/org.eclipse.ui.ide.prefs
RUN \
  sed -i "s/%username%/$USERNAME/"      /home/$USERNAME/.eclipse/org.eclipse.platform_4.31.0_1473617060_linux_gtk_x86_64/configuration/.settings/org.eclipse.ui.ide.prefs

# Prevent gnome-terminal from looking for accessibility tools
ENV NO_AT_BRIDGE=1

CMD ["gnome-terminal", "--disable-factory"]
