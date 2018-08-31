{ callPackage, fetchgit, fetchpatch, ... } @ args:

#! Not for inclusion in nixpkgs

callPackage ./generic.nix (args // rec {
  version = "git";

  # This keeps changing sha256 sum
  src = fetchgit {
    "url" = "git://github.com/ceph/ceph";
    "rev" = "04b7d3db49d4bb6ce81ce373daebc4ebf05ba990";
    "sha256" = "0swmim5112550z8lxvbcv62pgph9kh0rdy0bfjhkg5qvz3s7c68i";
    "fetchSubmodules" = true;
    "leaveDotGit" = true; # TODO write .git-version
  };
 

})
