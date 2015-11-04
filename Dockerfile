FROM centos:6.6
## update packages and install dependencies
##    csh, tar, perl needed for cctbx
##    gcc, zlib-devel needed to build mp4ipy
##    bunch of things for psana
RUN yum --enablerepo=updates clean metadata && \
    yum upgrade -y && \
    yum install -y \
        csh \
        gcc \
        gcc-c++ \
        patch \
        perl \
        tar \
        which \
        zlib-devel && \
    yum install -y \
        alsa-lib atk compat-libf2c-34 fontconfig freetype gsl libgfortran \
        libgomp libjpeg libpng libpng-devel pango postgresql-libs unixODBC \
        libICE libSM libX11 libXext libXft libXinerama libXpm libXrender libXtst \
        libXxf86vm mesa-libGL mesa-libGLU gtk2 xorg-x11-fonts-Type1 \
        xorg-x11-fonts-base xorg-x11-fonts-100dpi xorg-x11-fonts-truetype \
        xorg-x11-fonts-75dpi xorg-x11-fonts-misc

WORKDIR /
## setup SLAC software stack
# apt-get install psdm-release-ana-0.13.18-x86_64-rhel6-gcc44-opt && \
ADD http://pswww.slac.stanford.edu/psdm-repo/dist_scripts/site-setup.sh /usr/src/
ENV SIT_ROOT /reg/g/psdm
ENV PATH /reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
ENV APT_CONFIG /reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/etc/apt/apt.conf
RUN cd /usr/src && \
    chmod a+rx /usr/src/site-setup.sh && \
    /usr/src/site-setup.sh /reg/g/psdm && \
    apt-get update && \
    apt-get install psdm-release-ana-0.15.0-x86_64-rhel6-gcc44-opt -y && \
    /reg/g/psdm/bin/relcurrent $(ls -tr /reg/g/psdm/sw/releases/ | grep -v current | tail -n 1) && \
    source /reg/g/psdm/etc/ana_env.sh && \
    echo $( echo $LD_LIBRARY_PATH | awk -F: '{print $1}' ) >> /etc/ld.so.conf && \
    ldconfig && \
    printf "export SIT_ROOT=/reg/g/psdm\n" > /etc/profile.d/00_psana_site.sh && \
    printf "#!/bin/csh -f\nsetenv SIT_ROOT /reg/g/psdm\n" > /etc/profile.d/00_psana_site.csh && \
    printf "export PATH=/reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/bin:\$PATH\n" >> /etc/profile.d/00_psana_site.sh && \
    printf "setenv PATH /reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/bin:\$PATH\n" >> /etc/profile.d/00_psana_site.csh && \
    printf "export APT_CONFIG=/reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/etc/apt/apt.conf\n" >> /etc/profile.d/00_psana_site.sh && \
    printf "setenv APT_CONFIG /reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/etc/apt/apt.conf\n" >> /etc/profile.d/00_psana_site.csh && \
    printf "source /reg/g/psdm/etc/ana_env.sh\n" >> /etc/profile.d/01_psana.sh && \
    printf "#!/bin/csh -f\nsource /reg/g/psdm/etc/ana_env.csh\n" >> /etc/profile.d/01_psana.csh

## INSTALL CRAY DEPENDENCIES
ADD optcray_alva.tar /
RUN printf "/opt/cray/mpt/default/gni/mpich2-gnu/48/lib\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/pmi/default/lib64\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/ugni/default/lib64\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/udreg/default/lib64\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/xpmem/default/lib64\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/alps/default/lib64\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/wlm_detect/default/lib64\n" >> /etc/ld.so.conf && \
    printf "/opt/cray/wlm_detect/default/lib64/libwlm_detect.so.0" >> /etc/ld.so.preload && \
    ldconfig

### replace psdm mpi4py with cray-tuned one
### TODO it would be nice if this could use the existing scons build system
ADD https://bitbucket.org/mpi4py/mpi4py/downloads/mpi4py-1.3.1.tar.gz /usr/src/
ADD mpi.cfg /usr/src/
RUN source /reg/g/psdm/etc/ana_env.sh && \
    cd /usr/src && \
    mkdir -p mpi4py && \
    tar xf mpi4py-1.3.1.tar.gz -C mpi4py --strip-components=1 && \
    mv mpi.cfg mpi4py && \
    cd mpi4py && \
    mv /reg/g/psdm/sw/external/mpi4py/1.3.1b /reg/g/psdm/sw/external/mpi4py/1.3.1b.orig && \
    mkdir -p /reg/g/psdm/sw/external/mpi4py/1.3.1b/x86_64-rhel6-gcc44-opt && \
    python setup.py build && \
    python setup.py install --prefix=/reg/g/psdm/sw/external/mpi4py/1.3.1b/x86_64-rhel6-gcc44-opt && \
    cd / && rm -rf /usr/src/mpi4py

### replace hdf5 to link against cray mpich
### TODO it would be nice if this could use the existing scons build system
ADD https://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8.14/src/hdf5-1.8.14.tar.gz /usr/src/
RUN source /reg/g/psdm/etc/ana_env.sh && \
    mv /reg/g/psdm/sw/external/openmpi /reg/g/psdm/sw/external/openmpi.break && \
    mv /reg/g/psdm/sw/external/hdf5/1.8.14 /reg/g/psdm/sw/external/hdf5/1.8.14.orig && \
    mkdir -p /usr/src/hdf5 && \
    tar xf /usr/src/hdf5-1.8.14.tar.gz -C /usr/src/hdf5 --strip-components=1  && \
    cd /usr/src/hdf5 && \
    export CPPFLAGS="-I/opt/cray/mpt/default/gni/mpich2-gnu/48/include" && \
    export LDFLAGS="-L/opt/cray/mpt/default/gni/mpich2-gnu/48/lib -L/opt/cray/pmi/default/lib64 -L/opt/cray/ugni/default/lib64 -L/opt/cray/udreg/default/lib64 -L/opt/cray/xpmem/default/lib64 -lmpich -lugni -lpmi -ludreg -lxpmem" && \
    export MPICC=gcc && \
    export CC=gcc && \
    ./configure --prefix=/reg/g/psdm/sw/external/hdf5/1.8.14/x86_64-rhel6-gcc44-opt \
                --with-szlib=/reg/g/psdm/sw/external/szip/2.1/x86_64-rhel6-gcc44-opt \
                --enable-shared \
                --enable-hl \
                --enable-parallel \
                --enable-cxx \
                --enable-production \
                --enable-threadsafe \
                --enable-unsupported && \
    make && \
    make install && \
    cd / && rm -rf /usr/src/hdf5

### replace h5py to link against rebuilt hdf5 library
### TODO it would be nice if this could use the existing scons build system
ADD https://pypi.python.org/packages/source/h/h5py/h5py-2.3.1.tar.gz /usr/src/
ADD h5py_setup.patch /usr/src/
RUN source /reg/g/psdm/etc/ana_env.sh && \
    mv /reg/g/psdm/sw/external/h5py/2.3.1c /reg/g/psdm/sw/external/h5py/2.3.1c.old && \
    mkdir -p /usr/src/h5py && \
    tar xf /usr/src/h5py-2.3.1.tar.gz -C /usr/src/h5py --strip-components=1 && \
    export CPPFLAGS="-I/opt/cray/mpt/default/gni/mpich2-gnu/48/include" && \
    export LDFLAGS="-L/opt/cray/mpt/default/gni/mpich2-gnu/48/lib -L/opt/cray/pmi/default/lib64 -L/opt/cray/ugni/default/lib64 -L/opt/cray/udreg/default/lib64 -L/opt/cray/xpmem/default/lib64 -lmpich -lugni -lpmi -ludreg -lxpmem" && \
    export MPICC=gcc && \
    export CC=gcc && \
    export PYTHONPATH=/reg/g/psdm/sw/external/h5py/2.3.1c/x86_64-rhel6-gcc44-opt/lib/python2.7/site-packages:$PYTHONPATH && \
    mkdir -p /reg/g/psdm/sw/external/h5py/2.3.1c/x86_64-rhel6-gcc44-opt/lib/python2.7/site-packages && \
    cd /usr/src/h5py && \
    patch < ../h5py_setup.patch && \
    python setup.py build --mpi --hdf5=/reg/g/psdm/sw/external/hdf5/1.8.14/x86_64-rhel6-gcc44-opt && \
    python setup.py install --prefix=/reg/g/psdm/sw/external/h5py/2.3.1c/x86_64-rhel6-gcc44-opt --old-and-unmanageable && \
    cd / && rm -rf /usr/src/h5py
	
