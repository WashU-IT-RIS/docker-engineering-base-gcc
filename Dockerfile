FROM centos:7.7.1908 as build

COPY ./rc/bashrc /etc/bashrc
COPY ./rc/zshenv /etc/zshenv

# Set MOFED version, OS version and platform
ENV MOFED_VERSION 4.7-3.2.9.0
ENV OS_VERSION rhel7.7
ENV PLATFORM x86_64

RUN yum groupinstall -y 'Development Tools' \
&&  yum install -y epel-release \
&&  yum -y install  https://repo.ius.io/ius-release-el7.rpm \
&&  yum -y remove git* && yum -y --enablerepo=ius-archive install  git2u-all \
&&  yum install -y zsh wget vim cmake3 sssd gcc c++ g++ \
&&  ln -s /usr/bin/cmake3 /usr/bin/cmake \
&&  export ZSH=/usr/share/oh-my-zsh \
&&  wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh \
&&  yum clean -y all \
&&  chmod 755 /etc/bashrc /etc/zshenv
RUN cd /opt && git clone https://github.com/spack/spack.git


# Download and install Mellanox OFED 4.5-1.0.1.0

RUN wget http://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VERSION}/MLNX_OFED_LINUX-${MOFED_VERSION}-${OS_VERSION}-${PLATFORM}.tgz

RUN yum install -y deltarpm tzdata lsb-release bison tcl dpatch chrpath flex gfortran autoconf kmod tk ethtool graphviz lsof swig libgfortran3 automake pciutils \
                   openssl-devel.x86_64 openssl-libs.x86_64 numactl-libs.x86_64 numactl-devel.x86_64 libtool-ltdl.x86_64 libtool-ltdl-devel.x86_64 libmnl.x86_64 \
                   libnl3 gcc-gfortran tcsh mesa-libOSMesa.x86_64 mesa-libOSMesa-devel.x86_64 logrotate \
                   cmake openmpi2.x86_64 openmpi2-devel.x86_64 libtiff-devel.x86_64 fftw-devel.x86_64 libsss_nss_idmap.x86_64 gcc-c++ gcc-gfortran \
                   autoconf automake flex bison make python environment-modules patch libsigsegv libtool texinfo findutils \
                   xorg-x11-util-macros libpciaccess-devel numactl libxml2-devel gettext help2man libuuid-devel libjpeg* && \
    yum install -y centos-release-scl && \
    yum-config-manager --enable rhel-server-rhscl-7-rpms && \
    yum install -y devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-gcc-gfortran devtoolset-8-gcc devtoolset-8-gcc-c++ devtoolset-8-gcc-gfortran \
    yum clean all

RUN tar -xvf MLNX_OFED_LINUX-${MOFED_VERSION}-${OS_VERSION}-${PLATFORM}.tgz && \
    MLNX_OFED_LINUX-${MOFED_VERSION}-${OS_VERSION}-${PLATFORM}/mlnxofedinstall --user-space-only --without-fw-update -q && \
    cd .. && \
    rm -rf ${MOFED_DIR} && \
    rm -rf *.tgz

# Allow OpenSSH to talk to containers without asking for confirmation
RUN cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new && \
    mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

ENV SPACK_ROOT /opt/spack
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/bin:/opt/spack/bin

# Setup LSF link libraries
COPY lsf/ /opt/ibm/lsfsuite/lsf/
ENV LSF_ENVDIR /opt/ibm/lsfsuite/lsf/conf
ENV LSF_LIBDIR /opt/ibm/lsfsuite/lsf/10.1/linux2.6-glibc2.3-x86_64/lib
COPY spack/etc/spack/packages.yaml $SPACK_ROOT/etc/spack/packages.yaml
COPY spack/etc/spack/compilers.yaml /etc/spack/compilers.yaml

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/bin:$SPACK_ROOT/bin
# Install ESMF
RUN for i in $(spack find target=x86_64 | grep -v "^--" | grep -v "^=="); do spack uninstall --dependents -y $i target=x86_64; done && \
    spack install -v netcdf-c ^hdf5 +fortran ^openmpi schedulers=lsf fabrics=ucx +thread_multiple ^ucx@1.6.1+thread_multiple && \
    spack install -v netcdf-fortran ^hdf5 +fortran ^openmpi schedulers=lsf fabrics=ucx +thread_multiple ^ucx@1.6.1+thread_multiple

RUN . /opt/spack/share/spack/setup-env.sh && \
    spack load hdf5 && \
    spack load netcdf-c && \
    spack load netcdf-fortran && \
    spack install  --no-checksum esmf@8.0.0 -lapack -pio -pnetcdf -xerces ^hdf5 +fortran ^openmpi schedulers=lsf fabrics=ucx +thread_multiple ^ucx@1.6.1+thread_multiple
RUN  yum install -y zsh wget vim cmake3 sssd gcc c++ g++ \
&&  rm /usr/bin/cmake && ln -s /usr/bin/cmake3 /usr/bin/cmake

# Install gFTL
RUN git clone https://github.com/Goddard-Fortran-Ecosystem/gFTL.git /gFTL \
&&  cd /gFTL \
&&  mkdir build \
&&  cd build \
&&  cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gFTL \
&&  make -j install \
&&  rm -rf /gFTL

RUN mkdir -p /opt/ibm/lsfsuite/lsf/conf/ && \
    touch /opt/ibm/lsfsuite/lsf/conf/profile.lsf && \
    . /etc/bashrc && spack install nco ^hdf5 +fortran ^openmpi schedulers=lsf fabrics=ucx +thread_multiple ^ucx@1.6.1+thread_multiple

RUN rm -fr /opt/ibm

FROM centos:7.7.1908
COPY --from=build /opt /opt
COPY --from=build /etc/ssh/ssh_config /etc/ssh/ssh_config
COPY --from=build /etc/bashrc /etc/bashrc
COPY --from=build /etc/zshenv /etc/zshenv

RUN yum groupinstall -y 'Development Tools' \
&& yum install -y epel-release \
&& yum -y install  https://repo.ius.io/ius-release-el7.rpm \
&& yum -y remove git* && yum -y --enablerepo=ius-archive install  git2u-all \
&& yum install -y zsh wget vim cmake3 sssd gcc c++ g++ \
&& ln -s /usr/bin/cmake3 /usr/bin/cmake \
&& export ZSH=/usr/share/oh-my-zsh \
&& wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh \
&& yum install -y centos-release-scl \
&& yum-config-manager --enable rhel-server-rhscl-7-rpms \
&& yum install -y devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-gcc-gfortran devtoolset-8-gcc devtoolset-8-gcc-c++ devtoolset-8-gcc-gfortran \
&& yum install -y tzdata lsb-release bison tcl dpatch chrpath flex gfortran autoconf kmod tk ethtool graphviz lsof swig libgfortran3 automake pciutils \
                   openssl-devel.x86_64 openssl-libs.x86_64 numactl-libs.x86_64 numactl-devel.x86_64 libtool-ltdl.x86_64 libtool-ltdl-devel.x86_64 libmnl.x86_64 \
                   libnl3 gcc-gfortran tcsh mesa-libOSMesa.x86_64 mesa-libOSMesa-devel.x86_64 logrotate \
                   openmpi2.x86_64 openmpi2-devel.x86_64 libtiff-devel.x86_64 fftw-devel.x86_64 libsss_nss_idmap.x86_64 gcc-c++ gcc-gfortran \
                   autoconf automake flex bison make python environment-modules patch libsigsegv libtool texinfo findutils \
                   xorg-x11-util-macros libpciaccess-devel numactl libxml2-devel gettext help2man libuuid-devel libjpeg* && \
    yum clean all
