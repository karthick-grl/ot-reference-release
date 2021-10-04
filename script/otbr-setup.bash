#!/bin/bash
#
#  Copyright (c) 2021, The OpenThread Authors.
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  3. Neither the name of the copyright holder nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.
#

set -euxo pipefail

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
export PATH=$PATH:/usr/local/bin

REFERENCE_RELEASE_TYPE=$1
IN_CHINA=$2

if [ "${REFERENCE_RELEASE_TYPE?}" = "certification" ]; then
  readonly BUILD_OPTIONS=(
    'INFRA_IF_NAME=eth0'
    'RELEASE=1'
    'REFERENCE_DEVICE=1'
    'BACKBONE_ROUTER=1'
    'BORDER_ROUTING=0'
    'NETWORK_MANAGER=0'
    'NAT64=0'
    'DNS64=0'
    'DHCPV6_PD=0'
    'WEB_GUI=0'
    'REST_API=0'
    'OTBR_OPTIONS="-DOTBR_DUA_ROUTING=ON -DOT_DUA=ON -DOT_MLR=ON -DOTBR_DNSSD_DISCOVERY_PROXY=OFF -DOTBR_SRP_ADVERTISING_PROXY=OFF -DOT_TREL=OFF"'
  )
elif [ "${REFERENCE_RELEASE_TYPE?}" = "1.3" ]; then
  readonly BUILD_OPTIONS=(
    'RELEASE=1'
    'NETWORK_MANAGER=0'
    'REFERENCE_DEVICE=1'
  )
fi

configure_apt_source() {
  if [ "$IN_CHINA" = 1 ]; then
    echo 'deb http://mirrors.tuna.tsinghua.edu.cn/raspbian/raspbian/ buster main non-free contrib rpi
deb-src http://mirrors.tuna.tsinghua.edu.cn/raspbian/raspbian/ buster main non-free contrib rpi' | sudo tee /etc/apt/sources.list
    echo 'deb http://mirrors.tuna.tsinghua.edu.cn/raspberrypi/ buster main ui' | sudo tee /etc/apt/sources.list.d/raspi.list
  fi
}
configure_apt_source

echo "127.0.0.1 $(hostname)" >>/etc/hosts
chown -R pi:pi /home/pi/repo
cd /home/pi/repo/ot-br-posix
apt-get update --allow-releaseinfo-change
apt-get install -y --no-install-recommends git python3-pip
su -c "${BUILD_OPTIONS[*]} script/bootstrap" pi

rm -rf /home/pi/repo/ot-br-posix/third_party/openthread/repo
cp -r /home/pi/repo/openthread /home/pi/repo/ot-br-posix/third_party/openthread/repo

# Pin CMake version to 3.10.3 for issue https://github.com/openthread/ot-br-posix/issues/728.
# For more background, see https://gitlab.kitware.com/cmake/cmake/-/issues/20568.
apt-get purge -y cmake
pip3 install scikit-build
pip3 install cmake==3.10.3
cmake --version

su -c "${BUILD_OPTIONS[*]} script/setup" pi || true

if [ "$REFERENCE_RELEASE_TYPE" = "certification" ]; then
  cd /home/pi/repo/
  ./script/make-commissioner.bash
fi

sync
