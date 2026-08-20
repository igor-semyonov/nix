{
  # The wine-tts prefix: a ~685 MiB zip that modules/tts unpacks into
  # ~/.wine32-tts. It is git-LFS-tracked in this repo, but is deliberately NOT
  # pulled in via `inputs.self.lfs = true` anymore.
  #
  # Why: that flag makes nix LFS-fetch this asset whenever *anything* evaluates
  # this flake as an input, even a consumer that only wants homeModules.zsh. So
  # every downstream repo paid a 685 MiB fetch for a file almost none of them
  # use, and a failing LFS request (e.g. GitHub answering the batch endpoint
  # with HTTP 422) broke evaluation entirely rather than just the tts module.
  #
  # As a fixed-output derivation instead, the fetch happens only when something
  # actually references this package, and it is cacheable and hash-pinned. The
  # LFS object cannot be fetched with plain fetchurl: GitHub hands out signed
  # S3 URLs from /info/lfs/objects/batch that expire in an hour, so go through
  # git-lfs (fetchgit's fetchLFS) which negotiates that per fetch.
  fetchgit,
}:
fetchgit {
  url = "https://github.com/igor-semyonov/nix";
  # Pin the commit that introduced/last changed the asset rather than tracking a
  # branch, so the hash below stays valid. Bump both together if the zip changes.
  rev = "bab62481baca6cecda347159c67f5ebd72c41a07";
  fetchLFS = true;
  sparseCheckout = ["assets/wine-tts.zip"];
  # NAR hash of the sparse checkout, not the zip's own sha256.
  hash = "sha256-yQOTYUhLiXVr0/ZP3wwoLJhP/QvK7xShktFIxpcIGoA=";
}
