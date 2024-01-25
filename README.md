# dotspack for Dagobah

This is a collection of .spack files for dagobah

## Clone spack

First, we need spack. Below we assume we clone spack into `$HOME/spack`.

```bash
git clone -c feature.manyFiles=true https://github.com/spack/spack.git
```

## Environment

### .zshenv

```
export SPACK_ROOT=$HOME/spack
```

### .zshrc

```
# Only run these if SPACK_ROOT is defined
if [ ! -z ${SPACK_ROOT} ]
then
   . ${SPACK_ROOT}/share/spack/setup-env.sh

   # Next, we need to determine our macOS by *name*. So, we need to have a
   # variable that resolves to "ventura" or "sonoma".

   OS_VERSION=$(sw_vers --productVersion | cut -d. -f1)
   if [[ $OS_VERSION == 13 ]]
   then
      OS_NAME='ventura'
   elif [[ $OS_VERSION == 14 ]]
   then
      OS_NAME='sonoma'
   else
      OS_NAME='unknown'
   fi

   module use ${SPACK_ROOT}/share/spack/lmod/darwin-$OS_NAME-aarch64/Core
fi
```

We need the OS_NAME variable to determine which lmod files to use as a laptop might be on 
either ventura or sonoma.

## Homebrew

These are based on those from spack-stack

```bash
brew install coreutils
brew install gcc@12
brew install git
brew install git-lfs
brew install lmod
brew install wget
brew install bash
brew install curl
brew install cmake
brew install openssl
brew install qt@5
brew install mysql
```

## Spack

### config

Set the number of build_jobs to 6 (or whatever you want)

```bash
spack config add config:build_jobs:6
```

### compilers

Now we have Spack find the compilers on our system:
```bash
spack compiler find
```

For example, I got:
```bash
❯ spack compiler find
==> Added 4 new compilers to /Users/mathomp4/.spack/darwin/compilers.yaml
    gcc@13.2.0  gcc@12.3.0  gcc@12.2.0  apple-clang@15.0.0
==> Compilers are defined in the following files:
    /Users/mathomp4/.spack/darwin/compilers.yaml
```

Of these, we will focus on apple-clang. So now we need to fix up the compilers.yaml file to
point to `gfortran-12` from brew. So first, run `which gfortran-12` to get the path to the
gfortran-12 executable. On dagobah it is:
```bash
❯ which gfortran-12
/Users/mathomp4/.homebrew/brew/bin/gfortran-12
```

Then, edit the compilers.yaml file with `spack config edit compilers` and change:

```yaml
- compiler:
    spec: apple-clang@=15.0.0
    paths:
      cc: /usr/bin/clang
      cxx: /usr/bin/clang++
      f77: /usr/local/bin/gfortran
      fc: /usr/local/bin/gfortran
    flags: {}
    operating_system: sonoma
    target: aarch64
    modules: []
    environment: {}
    extra_rpaths: []
```
to:
```yaml
- compiler:
    spec: apple-clang@=15.0.0
    paths:
      cc: /usr/bin/clang
      cxx: /usr/bin/clang++
      f77: /Users/mathomp4/.homebrew/brew/bin/gfortran-12
      fc: /Users/mathomp4/.homebrew/brew/bin/gfortran-12
    flags: {}
    operating_system: sonoma
    target: aarch64
    modules: []
    environment: {}
    extra_rpaths: []
```

### packages

Now we can use `spack external find` to find the packages we need already in homebrew. But,
we want to exclude some packages that experimentation has found should be built by spack.


```bash
spack external find --exclude bison --exclude openssl \
   --exclude gmake --exclude m4 --exclude curl --exclude python \
   --exclude gettext
```

#### Additional settings

Now edit the packages.yaml file with `spack config edit packages` and add the following:

```yaml
  all:
    compiler: [apple-clang@15.0.0]
    providers:
      mpi: [openmpi]
      blas: [openblas]
      lapack: [openblas]
  hdf5:
    variants: +fortran +szip +hl +threadsafe +mpi
    # Note that cdo requires threadsafe, but hdf5 doesn't
    # seem to want that with parallel. Hmm.
  netcdf-c:
    variants: +hdf4 +dap
  esmf:
    variants: ~pnetcdf ~xerces ~external-parallelio
  cdo:
    variants: ~proj ~fftw3
    # cdo wanted a lot of extra stuff for proj and fftw3. Turn off for now
  pflogger:
    variants: +mpi
  pfunit:
    variants: +mpi +fhamcrest
  fms:
    variants: ~gfs_phys +pic ~quad_precision +yaml constants=GEOS precision=32,64
  mapl:
    variants: +extdata2g +fargparse +pflogger +pfunit ~pnetcdf
```

These are based on how we expect libraries to be built for GEOS and MAPL.

### modules

Next setup the `modules.yaml` file to look like:

```yaml
modules:
  default:
    'enable:':
    - lmod
    lmod:
      core_compilers:
      - apple-clang@15.0.0
      hierarchy:
      - mpi
      hash_length: 0
      include:
      - apple-clang
      all:
        suffixes:
          +debug: 'debug'
          build_type=Debug: 'debug'
      hdf5:
        suffixes:
          ~shared: 'static'
      esmf:
        suffixes:
          ~shared: 'static'
          esmf_pio=OFF: 'nopio'
  prefix_inspections:
    lib64: [LD_LIBRARY_PATH]
    lib:
    - LD_LIBRARY_PATH
```


