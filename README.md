# dotspack for Dagobah

This is a collection of .spack files for dagobah

## Homebrew

These are based on those from spack-stack

```bash
brew install coreutils
brew install gcc@13
brew install git
brew install lmod
brew install wget
brew install bash
brew install curl
brew install cmake
brew install openssl
```

### .zshenv

Add to .zshenv:
```bash 
. $(brew --prefix)/opt/lmod/init/zsh
```
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
   export SPACK_SKIP_MODULES=1
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


## Spack Configuration

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
point to `gfortran-13` from brew. So first, run `which gfortran-13` to get the path to the
gfortran-13 executable. On dagobah it is:
```bash
❯ which gfortran-13
/Users/mathomp4/.homebrew/brew/bin/gfortran-13
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
      f77: /Users/mathomp4/.homebrew/brew/bin/gfortran-13
      fc: /Users/mathomp4/.homebrew/brew/bin/gfortran-13
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
   --exclude gettext --exclude perl
```

#### Additional settings

Now edit the packages.yaml file with `spack config edit packages` and add the following:

```yaml
packages:
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
    variants: ~pnetcdf ~xerces
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

Next setup the `modules.yaml` file to look like this by running `spack config edit modules`:

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
        environment:
          set:
            '{name}_ROOT': '{prefix}'
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


## Spack Install

Now we install packages.

```bash
spack install python py-numpy py-pyyaml py-ruamel-yaml
spack install openmpi
spack install esmf
spack install gftl gftl-shared fargparse pfunit pflogger yafyaml
```

### Regenerate Modules

Sometimes spack needs a nudge to generate lmod files. This can be done (at any time) with:

```bash
spack module lmod refresh --delete-tree -y
```

### Extra apple-clang module

Spack is not able to create a modulefile for apple-clang since it is a
builtin compiler or something. But, we want to have a modulefile for it
so we can have `FC`, `CC` etc. set in the environment. So we make one. There
is a copy in the `extra_modulefiles` directory. Copy it to the right place:

```bash
cp -a extra_modulefiles/apple-clang $SPACK_ROOT/share/spack/lmod/darwin-sonoma-aarch64/Core/
```

Note that the Spack lmod directory won't be created until you run a first `spack install` command.


## Building GEOS and MAPL

### Loading lmodules (recommended)

If you are using the module way of loading spack, you need to do:

```bash
module load apple-clang openmpi esmf python py-pyyaml py-numpy pfunit pflogger fargparse zlib-ng
```

This might be too much, but it works.

### spack load

If you do `spack load` you need to do:

```bash
spack load openmpi esmf python py-pyyaml py-numpy pfunit pflogger fargparse zlib-ng
```

### Build command

The usual CMake commmand can be used to build GEOS or MAPL:

```bash
cmake -B build -S . --install-prefix=$(pwd)/install --fresh
cmake --build build --target install -j 6
```

NOTE: If you used `spack load` you'll need to supply the compilers to the first command:
```
cmake -B build -S . --install-prefix=$(pwd)/install --fresh -DCMAKE_Fortran_COMPILER=gfortran-13 -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
```
as `spack load` does not populate `FC`, `CC` and `CXX`.

### MAPL

No changes were needed for MAPL

### GEOS

#### Running

You'll need to update the `gcm_run.j` to not use `g5_modules` and instead use the spack modules.

So comment out:

```csh
#source $GEOSBIN/g5_modules
#setenv DYLD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${BASEDIR}/${ARCH}/lib:${GEOSDIR}/lib
```
and add:

```csh
source $LMOD_PKG/init/csh
module use -a $SPACK_ROOT/share/spack/lmod/darwin-sonoma-aarch64/Core
module load apple-clang openmpi esmf python py-pyyaml py-numpy pfunit pflogger fargparse zlib-ng
module list
setenv DYLD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${GEOSDIR}/lib
```

Note that `LMOD_PKG` seems to be defined by the brew lmod installation...though not sure.
You might just need to put in a full path or something.
