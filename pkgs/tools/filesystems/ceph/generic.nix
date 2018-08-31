{ stdenv, ensureNewerSourcesHook, cmake, pkgconfig
, which, git
, boost, python2Packages
, libxml2, zlib, lz4
, openldap, lttngUst
, babeltrace, gperf
, cunit, snappy
, rocksdb, makeWrapper
, leveldb, oathToolkit
#, nodejs, phantomjs2 #dashboard

# Optional Dependencies
, yasm ? null, fcgi ? null, expat ? null
, curl ? null, fuse ? null, libibverbs, librdmacm ? null
, libedit ? null, libatomic_ops ? null, kinetic-cpp-client ? null
, libs3 ? null

# Mallocs
, jemalloc ? null, gperftools ? null

# Crypto Dependencies
, cryptopp ? null
, nss ? null, nspr ? null

# Linux Only Dependencies
, linuxHeaders, libuuid, udev, keyutils, libaio ? null, libxfs ? null
, zfs ? null, utillinux

# Version specific arguments
, version, src, patches ? [], buildInputs ? []
, ...
}:

# We must have one crypto library
assert cryptopp != null || (nss != null && nspr != null);

with stdenv; with stdenv.lib;

let
  shouldUsePkg = pkg: if pkg != null && pkg.meta.available then pkg else null;

  optYasm = shouldUsePkg yasm;
  optFcgi = shouldUsePkg fcgi;
  optExpat = shouldUsePkg expat;
  optCurl = shouldUsePkg curl;
  optFuse = shouldUsePkg fuse;
  optLibibverbs = shouldUsePkg libibverbs;
  optLibrdmacm = shouldUsePkg librdmacm;
  optLibedit = shouldUsePkg libedit;
  optLibatomic_ops = shouldUsePkg libatomic_ops;
  optKinetic-cpp-client = shouldUsePkg kinetic-cpp-client;
  optLibs3 = if versionAtLeast version "10.0.0" then null else shouldUsePkg libs3;

  optJemalloc = shouldUsePkg jemalloc;
  optGperftools = shouldUsePkg gperftools;

  optCryptopp = shouldUsePkg cryptopp;
  optNss = shouldUsePkg nss;
  optNspr = shouldUsePkg nspr;

  optLibaio = shouldUsePkg libaio;
  optLibxfs = shouldUsePkg libxfs;
  optZfs = shouldUsePkg zfs;

  hasMon = true;
  hasMds = true;
  hasOsd = true;
  hasRadosgw = optFcgi != null && optExpat != null && optCurl != null && optLibedit != null;

  hasKinetic = versionAtLeast version "9.0.0" && optKinetic-cpp-client != null;

  # Malloc implementation (can be jemalloc, tcmalloc or null)
  malloc = if optJemalloc != null then optJemalloc else optGperftools;

  # We prefer nss over cryptopp
  cryptoStr = if optNss != null && optNspr != null then "nss" else
    if optCryptopp != null then "cryptopp" else "none";
  cryptoLibsMap = {
    nss = [ nss nspr ];
    cryptopp = [ optCryptopp ];
    none = [ ];
  };

  ceph-python-env = python2Packages.python.withPackages (ps: [
    ps.sphinx
    ps.flask
    ps.argparse
    ps.cython
    ps.setuptools
    ps.virtualenv
    # Libraries needed by the python tools
    ps.Mako
    ps.cherrypy
    ps.pecan
    ps.prettytable
    ps.webob
    ps.bcrypt
  ]);

#  node-env = (import ./dashboard-node-env {}).package;
in

stdenv.mkDerivation {
  name="ceph-${version}";

  inherit src;

  patches = [
    ./0000-fix-SPDK-build-env.patch
    #./0000-dashboard-rm-deps.patch

    # TODO: remove when https://github.com/ceph/ceph/pull/21289 is merged
    ./0000-ceph-volume-allow-loop.patch
    # TODO: remove when https://github.com/ceph/ceph/pull/20938 is merged
    ./0000-dont-hardcode-bin-paths.patch
  ];

  nativeBuildInputs = [
    cmake
    pkgconfig which git python2Packages.wrapPython makeWrapper
    (ensureNewerSourcesHook { year = "1980"; })
  ];

  buildInputs = buildInputs ++ cryptoLibsMap.${cryptoStr} ++ [
    boost ceph-python-env libxml2 optYasm optLibatomic_ops optLibs3
    malloc zlib openldap lttngUst babeltrace gperf cunit
    snappy rocksdb lz4 oathToolkit leveldb optLibibverbs optLibrdmacm
#    node-env nodejs phantomjs2 #dashboard
  ] ++ optionals stdenv.isLinux [
    linuxHeaders utillinux libuuid udev keyutils optLibaio optLibxfs optZfs
  ] ++ optionals hasRadosgw [
    optFcgi optExpat optCurl optFuse optLibedit
  ] ++ optionals hasKinetic [
    optKinetic-cpp-client
  ];

  preConfigure =''
    # require LD_LIBRARY_PATH for pybind/rgw to find internal dep
    export LD_LIBRARY_PATH="$PWD/build/lib:$LD_LIBRARY_PATH"
#    export HOME=$(mktemp -d) # dashboard
    patchShebangs src/spdk
  '';

  cmakeFlags = [
    "-DWITH_SYSTEM_ROCKSDB=ON"
    "-DROCKSDB_INCLUDE_DIR=${rocksdb}/include/rocksdb"
    "-DWITH_SYSTEM_BOOST=OFF" # TODO can't find boost_python on mimic, but works on master branch
    "-DBOOST_LIBRARYDIR=${boost}/lib"
    "-DWITH_SYSTEMD=OFF"
    "-DWITH_TESTS=OFF"

    "-DWITH_SYSTEM_NPM=ON"
    "-DWITH_MGR_DASHBOARD_FRONTEND=OFF"
  ];

#  buildPhase = ''
#    export PATH=$PATH:${node-env}/lib/node_modules/ceph-dashboard/node_modules/.bin
#    make -f CMakeFiles/Makefile2 src/pybind/mgr/all
#  '';

  postFixup = ''
    wrapPythonPrograms
    wrapProgram $out/bin/ceph-mgr --prefix PYTHONPATH ":" "$out/lib/ceph/mgr:$out/lib/python2.7/site-packages/"
  '';

  enableParallelBuilding = true;

  outputs = [ "out" "dev" "doc" ];

  meta = {
    homepage = http://ceph.com/;
    description = "Distributed storage system";
    license = licenses.lgpl21;
    maintainers = with maintainers; [ adev ak wkennington ];
    platforms = platforms.unix;
  };

  passthru.version = version;
}
