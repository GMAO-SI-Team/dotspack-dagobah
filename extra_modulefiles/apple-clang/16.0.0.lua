-- -*- lua -*-

whatis([[Name : apple-clang]])
whatis([[Version : 16.0.0]])
whatis([[Target : m2]])
whatis([[Short description : Apple's Clang compiler]])
whatis([[Configure options : unknown, software installed outside of Spack]])

help([[Name   : apple-clang]])
help([[Version: 16.0.0]])
help([[Target : m2]])
help()
help([[Apple's Clang compiler]])

-- Services provided by the package
family("compiler")

-- Loading this module unlocks the path below unconditionally
prepend_path("MODULEPATH", "/Users/mathomp4/spack/share/spack/lmod/darwin-sonoma-aarch64/Core")

-- set the compiler environment variables
setenv("CC","/usr/bin/clang")
setenv("CXX","/usr/bin/clang++")
local homedir = os.getenv("HOME")
local homebrewdir = pathJoin(homedir, ".homebrew/brew")
setenv("FC",pathJoin(homebrewdir, "bin/gfortran-14"))
setenv("F90",pathJoin(homebrewdir, "bin/gfortran-14"))

-- per scivision, set OpenMP_ROOT for clang: https://gist.github.com/scivision/16c2ca1dc250f54d34f1a1a35596f4a0
setenv("OpenMP_ROOT",pathJoin(homebrewdir, "opt/libomp"))

