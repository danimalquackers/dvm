{
  lib,
  ...
}:

let
  # Curryable function for generating variable references
  # Can be curried with the root name and a list of valid properties
  ref =
    root: valid: path:
    assert (valid == [ ] || lib.elem path valid);
    "\${${root}.${path}}";
in
{
  # ref.var "foo" becomes ${var.foo}
  var = ref "var" [ ];

  # ref.local "foo" becomes ${local.foo}
  local = ref "local" [ ];

  # ref.env "foo" becomes ${env.foo}
  env = ref "env" [ ];

  # ref.path "cwd" becomes ${path.cwd}
  path = ref "path" [
    "cwd"
    "root"
  ];
}
