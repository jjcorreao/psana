FROM centos:6
MAINTAINER "bkpoon" bkpoon@lbl.gov
ENV container docker

# link mysql libraries in /usr/lib64/mysql to psdm


# TODO:
#   1) use environment variables
#   2) use WORKDIR instead of cd
#   3) make symbolic links in /usr/lib64/mysql for libmysqlclient.so.16
#   4) fix skip_event in __init__.py

# install base packages for psdm
# https://confluence.slac.stanford.edu/display/PSDM/System+packages+for+rhel6
RUN yum -y install alsa-lib atk compat-libf2c-34 fontconfig freetype gsl \
    libgfortran libgomp libjpeg libpng libpng-devel pango postgresql-libs \
    unixODBC libICE libSM libX11 libXext libXft libXinerama libXpm \
    libXrender libXtst libXxf86vm mesa-libGL mesa-libGLU gtk2 \
    xorg-x11-fonts-Type1 xorg-x11-fonts-base xorg-x11-fonts-100dpi \
    xorg-x11-fonts-truetype xorg-x11-fonts-75dpi xorg-x11-fonts-misc \
    tar xz which gcc gcc-c++

# install psdm
# https://confluence.slac.stanford.edu/display/PSDM/Software+Distribution
#RUN mkdir -p /reg/g/psdm
ADD http://pswww.slac.stanford.edu/psdm-repo/dist_scripts/site-setup.sh \
    /reg/g/psdm/
RUN sh /reg/g/psdm/site-setup.sh /reg/g/psdm
ENV SIT_ROOT=/reg/g/psdm
ENV PATH=/reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/bin:$PATH
ENV APT_CONFIG=/reg/g/psdm/sw/dist/apt-rpm/rhel6-x86_64/etc/apt/apt.conf
RUN apt-get -y update; apt-get -y install \
            psdm-release-ana-0.17.4-x86_64-rhel6-gcc44-opt &&\
    ln -s /reg/g/psdm/sw/releases/ana-0.17.4 \
          /reg/g/psdm/sw/releases/ana-current

# use old HDF5 (1.8.6) for compatibility with cctbx.xfel
ADD https://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8.6/bin/linux-x86_64/hdf5-1.8.6-linux-x86_64-shared.tar.gz .
RUN rm -fr /reg/g/psdm/sw/external/hdf5/* &&\
    tar -xf hdf5-1.8.6-linux-x86_64-shared.tar.gz &&\
    mkdir -p /reg/g/psdm/sw/external/hdf5/1.8.6 &&\
    mv hdf5-1.8.6-linux-x86_64-shared \
       /reg/g/psdm/sw/external/hdf5/1.8.6/x86_64-rhel6-gcc44-opt

# build myrelease
RUN cd /reg/g &&\
    source /reg/g/psdm/etc/ana_env.sh &&\
    newrel ana-0.17.4 myrelease &&\
    cd myrelease &&\
    sit_setup.sh -orhel6 -cgcc44 &&\
    newpkg my_ana_pkg

# copy cctbx.xfel from local tarball
RUN mkdir -p /reg/g/cctbx
COPY ./xfel.tar.xz /reg/g/cctbx/xfel.tar.xz
RUN cd /reg/g/cctbx &&\
    tar -Jxf ./xfel.tar.xz

# build cctbx.xfel
# make needs to be run multiple times to ensure complete build (bug)
ENV CPATH=/reg/g/psdm/sw/external/openmpi/1.8.6/x86_64-rhel6-gcc44-opt/include
ENV LD_LIBRARY_PATH=/reg/g/psdm/sw/external/openmpi/1.8.6/x86_64-rhel6-gcc44-opt/lib
RUN source /reg/g/psdm/etc/ana_env.sh &&\
    cd /reg/g/myrelease &&\
    sit_setup.sh -orhel6 -cgcc44 &&\
    cd /reg/g/cctbx &&\
    python ./modules/cctbx_project/libtbx/auto_build/bootstrap.py build \
    --builder=xfel --with-python=`which python` --nproc=8 &&\
    cd build &&\
    make -j 8 &&\
    make -j 8
