{ callPackage, fetchurl, fetchpatch, ... } @ args:

callPackage ./generic.nix (args // rec {
  version = "13.2.1";

  src = fetchurl {
    url = "http://download.ceph.com/tarballs/ceph-${version}.tar.gz";
    sha256 = "0g4h2r2y21g005ydrn3vi6mfx4phwafr3kazz1jdyzq0saa6421j";
  };

})
