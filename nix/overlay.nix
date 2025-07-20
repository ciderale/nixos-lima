final: prev: {
  # support SIGHUP for portmapping update
  lima = prev.lima.overrideAttrs (old: {
    patches = [./lima-sighup.patch];
  });
}
