FROM centos:7
LABEL maintainer="github.com/nishi-hi"

# Define editable variables
ARG GROUP_NAME="bar"
ARG USER_NAME="foo"
ARG PASSWORD="password"
ARG TIMEZONE="Asia/Tokyo"
# Define uneditable variables
ARG HOME_DIRECTORY="/home/${USER_NAME}"
ARG NOVNC_VERSION="1.0.0"
ARG WEBSOCKIFY_VERSION="0.6.1"
ARG SOFTWARE_ROOT="/usr/local/sw"
ARG NOVNC_ROOT="${SOFTWARE_ROOT}/novnc"
ARG CERTIFICATE_ROOT="${NOVNC_ROOT}/certs"
ARG SSH_PORT="22"
ARG VNC_PORT="5901"
ARG NOVNC_PORT="6901"

# Set listen ports
EXPOSE ${SSH_PORT} ${VNC_PORT} ${NOVNC_PORT}

# Change working directory
WORKDIR /root

# Construct software environment
RUN set -o pipefail -x && \
    : Change timezone && \
    rm -f /etc/localtime && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    : Add Japanese locale, enable man installation && \
    sed -i -e 's:^\(override_install_langs=en_US\.utf8\)$:\1,ja_JP.utf8:' -e 's:^\(tsflags=nodocs\)$:#\1:' /etc/yum.conf && \
    yum -y reinstall glibc-common && \
    : Install packages && \
    yum -y update && \
    yum -y groupinstall "Development Tools" && \
    yum -y install chrony epel-release man-db man-pages numpy tigervnc-server wget openssh-server openssl net-tools vim ibus-kkc firefox && \
    yum -y install google-noto-sans-japanese-fonts && \
    yum -y groupinstall "Xfce" && \
    yum clean all && \
    : Prohibit root login && \
    sed -i -e 's:^\s*#\s*\(PermitRootLogin\)\s\+yes:\1 no:' /etc/ssh/sshd_config && \
    : Set root password && \
    echo "root:${PASSWORD}" | chpasswd && \
    : Register group, user && \
    groupadd ${GROUP_NAME} && \
    useradd -g ${GROUP_NAME} -m ${USER_NAME} && \
    : Write ${HOME_DIRECTORY}/.bash_profile && \
    echo "${USER_NAME}:${PASSWORD}" | chpasswd && \
    { echo "# Environment variables #"; \
      echo; \
      echo "# Source ~/.bashrc #"; \
      echo "if [[ -f ~/.bashrc ]]; then"; \
      echo "  source ~/.bashrc"; \
      echo "fi"; } | tee ${HOME_DIRECTORY}/.bash_profile && \
    chmod 640 ${HOME_DIRECTORY}/.bash_profile && \
    : Write ${HOME_DIRECTORY}/.bashrc && \
    { echo "# Shell Variables #"; \
      echo "if [[ \"\$(id -u)\" = \"0\" ]]; then"; \
      echo "  COLOR=\"38;05;1\""; \
      echo "else"; \
      echo "  COLOR=\"38;05;2\""; \
      echo "  umask 0027"; \
      echo "fi"; \
      echo "PS1=\"\\[\\e[\${COLOR}m\\][\\u@\\h \\W]\\\\$\\[\\e[0m\\] \""; \
      echo "unset COLOR"; \
      echo; \
      echo "# Aliases #"; \
      echo "alias cp='cp -i'"; \
      echo "alias mv='mv -i'"; \
      echo "alias rm='rm -i'"; \
      echo "alias ls='ls --color=auto --time-style=+\"%Y-%m-%d %T\"'"; \
      echo "alias vi='vim'"; } | tee ${HOME_DIRECTORY}/.bashrc && \
    chmod 640 ${HOME_DIRECTORY}/.bashrc && \
    : Create ${HOME_DIRECTORY}/.vnc && \
    mkdir -m 750 ${HOME_DIRECTORY}/.vnc && \
    : Put ${HOME_DIRECTORY}/.vnc/xstartup && \
    { echo "#!/bin/bash"; \
      echo; \
      echo "unset SESSION_MANAGER"; \
      echo "unset DBUS_SESSION_BUS_ADDRESS"; \
      echo "export GTK_IM_MODULE=ibus"; \
      echo "export XMODIFIERS=@im=ibus"; \
      echo "export QT_IM_MODULE=ibus"; \
      echo "ibus-daemon -drx"; \
      echo "exec xfce4-session &"; } |tee ${HOME_DIRECTORY}/.vnc/xstartup && \
    chmod 750 ${HOME_DIRECTORY}/.vnc/xstartup && \
    : Set VNC password && \
    echo "${PASSWORD}" | vncpasswd -f > ${HOME_DIRECTORY}/.vnc/passwd && \
    chmod 600 ${HOME_DIRECTORY}/.vnc/passwd && \
    : Equalize owner of entire home directory && \
    chown -Rh ${USER_NAME}:${GROUP_NAME} ${HOME_DIRECTORY} && \
    : Copy .bash_profile, .bashrc && \
    cp ${HOME_DIRECTORY}/{.bash_profile,.bashrc} /root && \
    : Disable Firefox menu access key && \
    echo "pref(\"ui.key.menuAccessKey\", 0);" |tee /etc/firefox/pref/all-user.js && \
    : Enable TigerVNC server service && \
    sed -i -e 's:^\(\(ExecStart\|PIDFile\)=.*\)<USER>\(.*\):\1'${USER_NAME}'\3:' /lib/systemd/system/vncserver\@.service && \
    sed -i -e 's:^\(ExecStart=.*\)\s\+"\(.*\)"$:\1 "\2 \&\& ( '${NOVNC_ROOT}'/utils/launch.sh --listen '${NOVNC_PORT}' --vnc localhost\:'${VNC_PORT}' --cert '${CERTIFICATE_ROOT}'/self.pem --ssl-only > ~/start.log 2>\&1 \& )":' /lib/systemd/system/vncserver\@.service && \
    sed -i -e '/^\(ExecStartPre\|ExecStop\)=/s:\(/usr/bin/vncserver\s\+-kill\s\+%i\):( pkill -U '${USER_NAME}' -u '${USER_NAME}' -f "'${NOVNC_ROOT}'/utils/launch.sh" ; pkill -U '${USER_NAME}' -u '${USER_NAME}' -f "'${NOVNC_ROOT}'/utils/websockify/run" ; \1 ):' /lib/systemd/system/vncserver\@.service && \
    systemctl enable vncserver\@:1.service && \
    : Create noVNC install directory && \
    mkdir -m 755 -p ${NOVNC_ROOT} && \
    : Download and extract noVNC source code archive && \
    curl -sL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar oxz -C ${NOVNC_ROOT} --strip=1 --no-same-permissions && \
    : Create websockify install directory && \
    mkdir -m 755 ${NOVNC_ROOT}/utils/websockify && \
    : Download and extract websockify source code archive && \
    curl -sL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | \
    tar oxz -C ${NOVNC_ROOT}/utils/websockify --strip=1 --no-same-permissions && \
    : Put index.html && \
    ln -s ${NOVNC_ROOT}/vnc_lite.html ${NOVNC_ROOT}/index.html && \
    : Create certificate file && \
    mkdir ${NOVNC_ROOT}/certs && \
    openssl req -new -newkey rsa:2048 -x509 -days 365 -nodes -subj '/CN=localhost' -out ${CERTIFICATE_ROOT}/self.pem -keyout ${CERTIFICATE_ROOT}/self.pem
