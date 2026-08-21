{
  lib ? import <nixpkgs> { }.lib,
}:

let
  # Helpers to double-quote and escape strings
  toQuoted = s: "\"${toString s}\"";
  toEscaped =
    s:
    builtins.replaceStrings [ "\\" "\"" "\n" "\r" "\t" ] [ "\\\\" "\\\"" "\\n" "\\r" "\\t" ] (
      toString s
    );
  toHCLString = s: "${toQuoted (toEscaped s)}";

  # Janky helper for HCL dictionary format
  toHCLDict =
    attrs:
    "{ "
    + lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${toHCLString k} = ${toHCLString v}") attrs)
    + " }";

  # Helpers for formatting arguments
  toHCLArg =
    arg:
    if builtins.isString arg then
      # Quote and escape the string
      toHCLString arg
    else if builtins.isPath arg then
      # Copy the file to make sure it gets added to the build source
      toHCLString (builtins.toFile (builtins.baseNameOf arg) (builtins.readFile arg))
    else if lib.isAttrs arg then
      # Serialize using a custom HCL2-format dictionary builder
      toHCLDict arg
    else
      toString arg;
  toHCLArgs = args: lib.concatStringsSep ", " (map toHCLArg args);
in
{
  # String Functions
  chomp = string: "\${chomp(${toHCLArg string})}";
  format = spec: values: "\${format(${toHCLArg spec}, ${toHCLArgs values})}";
  formatlist = spec: values: "\${formatlist(${toHCLArg spec}, ${toHCLArgs values})}";
  indent = num_spaces: string: "\${indent(${toHCLArg num_spaces}, ${toHCLArg string})}";
  join = separator: list: "\${join(${toHCLArg separator}, ${toHCLArg list})}";
  lower = string: "\${lower(${toHCLArg string})}";
  regex = pattern: string: "\${regex(${toHCLArg pattern}, ${toHCLArg string})}";
  regexall = pattern: string: "\${regexall(${toHCLArg pattern}, ${toHCLArg string})}";
  replace =
    string: substring: replacement:
    "\${replace(${toHCLArg string}, ${toHCLArg substring}, ${toHCLArg replacement})}";
  split = separator: string: "\${split(${toHCLArg separator}, ${toHCLArg string})}";
  strrev = string: "\${strrev(${toHCLArg string})}";
  substr =
    string: offset: length:
    "\${substr(${toHCLArg string}, ${toString offset}, ${toString length})}";
  title = string: "\${title(${toHCLArg string})}";
  trim = string: cutset: "\${trim(${toHCLArg string}, ${toHCLArg cutset})}";
  trimprefix = string: prefix: "\${trimprefix(${toHCLArg string}, ${toHCLArg prefix})}";
  trimsuffix = string: suffix: "\${trimsuffix(${toHCLArg string}, ${toHCLArg suffix})}";
  trimspace = string: "\${trimspace(${toHCLArg string})}";
  upper = string: "\${upper(${toHCLArg string})}";

  # Collection & List Functions
  chunklist = list: size: "\${chunklist(${toHCLArg list}, ${toString size})}";
  coalesce = vals: "\${coalesce(${toHCLArgs vals})}";
  coalescelist = lists: "\${coalescelist(${toHCLArgs lists})}";
  compact = list: "\${compact(${toHCLArg list})}";
  concat = lists: "\${concat(${toHCLArgs lists})}";
  contains = list: value: "\${contains(${toHCLArg list}, ${toHCLArg value})}";
  distinct = list: "\${distinct(${toHCLArg list})}";
  element = list: index: "\${element(${toHCLArg list}, ${toString index})}";
  flatten = list: "\${flatten(${toHCLArg list})}";
  index = list: value: "\${index(${toHCLArg list}, ${toHCLArg value})}";
  keys = map: "\${keys(${toHCLArg map})}";
  length = container: "\${length(${toHCLArg container})}";
  lookup =
    map: key: default:
    "\${lookup(${toHCLArg map}, ${toHCLArg key}, ${toHCLArg default})}";
  matchkeys =
    values: keys: search_keys:
    "\${matchkeys(${toHCLArg values}, ${toHCLArg keys}, ${toHCLArg search_keys})}";
  merge = maps: "\${merge(${toHCLArgs maps})}";
  range =
    start: limit: step:
    "\${range(${toHCLArg start}, ${toHCLArg limit}, ${toHCLArg step})}";
  reverse = list: "\${reverse(${toHCLArg list})}";
  setintersection = sets: "\${setintersection(${toHCLArgs sets})}";
  setproduct = sets: "\${setproduct(${toHCLArgs sets})}";
  setunion = sets: "\${setunion(${toHCLArgs sets})}";
  slice =
    list: start: end:
    "\${slice(${toHCLArg list}, ${toHCLArg start}, ${toHCLArg end})}";
  sort = list: "\${sort(${toHCLArg list})}";
  transpose = map: "\${transpose(${toHCLArg map})}";
  values = map: "\${values(${toHCLArg map})}";
  zipmap = keys_list: values_list: "\${zipmap(${toHCLArg keys_list}, ${toHCLArg values_list})}";

  # Numeric & Math Functions
  abs = number: "\${abs(${toHCLArg number})}";
  ceil = number: "\${ceil(${toHCLArg number})}";
  floor = number: "\${floor(${toHCLArg number})}";
  log = number: base: "\${log(${toHCLArg number}, ${toHCLArg base})}";
  max = numbers: "\${max(${lib.concatStringsSep ", " (map toHCLArg numbers)})}";
  min = numbers: "\${min(${lib.concatStringsSep ", " (map toHCLArg numbers)})}";
  pow = number: exponent: "\${pow(${toHCLArg number}, ${toHCLArg exponent})}";
  signum = number: "\${signum(${toHCLArg number})}";

  # Encoding & Decoding Functions
  base64decode = string: "\${base64decode(${toHCLArg string})}";
  base64encode = string: "\${base64encode(${toHCLArg string})}";
  base64gzip = string: "\${base64gzip(${toHCLArg string})}";
  csvdecode = string: "\${csvdecode(${toHCLArg string})}";
  jsondecode = string: "\${jsondecode(${toHCLArg string})}";
  jsonencode = value: "\${jsonencode(${toHCLArg value})}";
  urlencode = string: "\${urlencode(${toHCLArg string})}";
  yamldecode = string: "\${yamldecode(${toHCLArg string})}";
  yamlencode = value: "\${yamlencode(${toHCLArg value})}";

  # Filesystem & Path Functions
  abspath = path: "\${abspath(${toHCLArg path})}";
  basename = path: "\${basename(${toHCLArg path})}";
  dirname = path: "\${dirname(${toHCLArg path})}";
  file = path: "\${file(${toHCLArg path})}";
  filebase64 = path: "\${filebase64(${toHCLArg path})}";
  fileexists = path: "\${fileexists(${toHCLArg path})}";
  fileglob = pattern: "\${fileglob(${toHCLArg pattern})}";
  fileset = path: pattern: "\${fileset(${toHCLArg path}, ${toHCLArg pattern})}";
  pathexpand = path: "\${pathexpand(${toHCLArg path})}";
  templatefile = path: vars: "\${templatefile(${toHCLArg path}, ${toHCLArg vars})}";

  # Crypto & Hash Functions
  bcrypt = string: cost: "\${bcrypt(${toHCLArg string}, ${toString cost})}";
  md5 = string: "\${md5(${toHCLArg string})}";
  rsadecrypt =
    ciphertext: private_key: "\${rsadecrypt(${toHCLArg ciphertext}, ${toHCLArg private_key})}";
  sha1 = string: "\${sha1(${toHCLArg string})}";
  sha256 = string: "\${sha256(${toHCLArg string})}";
  sha512 = string: "\${sha512(${toHCLArg string})}";
  uuid = "\${uuid()}";
  uuidv5 = namespace: name: "\${uuidv5(${toHCLArg namespace}, ${toHCLArg name})}";

  # Date & Time Functions
  formatdate = spec: timestamp: "\${formatdate(${toHCLArg spec}, ${toHCLArg timestamp})}";
  timeadd = timestamp: duration: "\${timeadd(${toHCLArg timestamp}, ${toHCLArg duration})}";
  timestamp = "\${timestamp()}";
}
