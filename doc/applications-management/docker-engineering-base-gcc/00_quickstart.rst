===========
Quick Start
===========

.. contents::
   :local:

Overview
--------

This is a quick start guide for managing engineering base docker
image with gcc.

Capabilities
------------

Compile program with gcc, gfortran, and openmpi.  Shown below are a list of libraries included.

* hdf5
* netcdf-c
* netcdf-fortran
* gFTL
* ESMF 
* Mellanox OFED

Build Docker Image
------------------

Checkout this repository::

  git clone ssh://git@bitbucket.ris.wustl.edu:7999/appeng/docker-engineering-base-gcc.git

Build a docker image::

  docker build --tag registry.gsc.wustl.edu/sleong/base-engineering-gcc .

Run Docker Container
--------------------

Shown below are steps to run the docker image locally or on compute1.

Locally
~~~~~~~

Run the following command to get an interactive container instance::

  docker run --rm -it registry.gsc.wustl.edu/sleong/base-engineering-gcc /bin/bash

Compute1
~~~~~~~~

Login to compute1 client host::

  ssh compute1-client-1

Run the following command to get an interactive container instance.  Please
replace "sleong" with your wustlkey to access your storage1 allocation.  You
can add other paths to be visible in your docker images by adding
another path separated by a white space character.  For example,
"/storage1/fs1/sleong/Active/:/my-projects /scratch1/fs1/sleong:/scratch1/fs1/sleong"
to the LSF_DOCKER_VOLUMES variable below::

  LSF_DOCKER_SHM_SIZE=20G LSF_DOCKER_VOLUMES="/storage1/fs1/sleong/Active:/my-projects" bsub -q general-interactive -Is -a "docker(registry.gsc.wustl.edu/sleong/base-engineering-gcc)" /bin/bash

Test Docker Image
-----------------

Shown below are the tests that can be used to test the docker image.

Fortran
~~~~~~~

This is an MPI job that can be used to test on compute1.

Login to compute1::

   ssh compute1-client-1

Get an LSF interactive job::

  LSF_DOCKER_SHM_SIZE=20G LSF_DOCKER_VOLUMES="/your/intel/licenses/path:/opt/licenses" bsub -q general-interactive -Is -a "docker(registry.gsc.wustl.edu/sleong/base-engineering-gcc)" /bin/bash

Run the test::

  wget https://computing.llnl.gov/tutorials/mpi/samples/Fortran/mpi_ringtopo.f
  mpifort mpi_ringtopo.f
  mpirun -np 6 ./a.out
