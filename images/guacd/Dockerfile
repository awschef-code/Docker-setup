#
# Copyright (C) 2015 Glyptodon LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

#
# Dockerfile for guacamole-server
#

# CentOS6 Base Image
FROM centos:centos6
MAINTAINER Michael Jumper <mike.jumper@guac-dev.org>

# Environment variables
ENV \
    GUAC_VERSION=0.9.3 \
    LC_ALL=en_US.UTF-8

# Bring environment up-to-date, install guacamole-server build dependencies
RUN yum -y update i             && \
    yum -y install epel-release && \
    yum -y install             \
        cairo-devel            \
        dejavu-sans-mono-fonts \
        freerdp-devel          \
        freerdp-plugins        \
        gcc                    \
        ghostscript            \
        libjpeg-turbo-devel    \
        libssh2-devel          \
        liberation-mono-fonts  \
        libtelnet-devel        \
        libvorbis-devel        \
        libvncserver-devel     \
        libwebp-devel          \
        make                   \
        pango-devel            \
        pulseaudio-libs-devel  \
        tar                    \
        wget                   \
        terminus-fonts         \
        mkfontscale            \
        uuid-devel              && \
    yum clean all

# Install Monaco fonts
COPY  Monaco_Linux.ttf /usr/share/fonts/monaco/
CMD chmod 644 /usr/share/fonts/monaco/Monaco_Linux.ttf
RUN cd /usr/share/fonts/monaco && mkfontscale && mkfontdir
RUN cd /usr/share/fonts && fc-cache

# Add configuration scripts
COPY bin /opt/guacd/bin

# Download and install latest guacamole-server
RUN /opt/guacd/bin/download-guacd.sh "$GUAC_VERSION"


# Start guacd, listening on port 0.0.0.0:4822
EXPOSE 4822
CMD [ "/usr/local/sbin/guacd", "-b", "0.0.0.0", "-f" ]
