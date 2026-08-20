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
      toHCLString arg
    else if lib.isAttrs arg then
      toHCLDict arg
    else
      toString arg;
  toHCLArgs = args: lib.concatStringsSep ", " (map toHCLArg args);
in
{
  # String Functions
  chomp = string: "\${chomp(${toHCLString string})}";
  format = spec: values: "\${format(${toHCLString spec}, ${toHCLArgs values})}";
  formatlist = spec: values: "\${formatlist(${toHCLString spec}, ${toHCLArgs values})}";
  indent = num_spaces: string: "\${indent(${toString num_spaces}, ${toHCLString string})}";
  join = separator: list: "\${join(${toHCLString separator}, ${toHCLArg list})}";
  lower = string: "\${lower(${toHCLString string})}";
  regex = pattern: string: "\${regex(${toHCLString pattern}, ${toHCLString string})}";
  regexall = pattern: string: "\${regexall(${toHCLString pattern}, ${toHCLString string})}";
  replace =
    string: substring: replacement:
    "\${replace(${toHCLString string}, ${toHCLString substring}, ${toHCLString replacement})}";
  split = separator: string: "\${split(${toHCLString separator}, ${toHCLString string})}";
  strrev = string: "\${strrev(${toHCLString string})}";
  substr =
    string: offset: length:
    "\${substr(${toHCLString string}, ${toString offset}, ${toString length})}";
  title = string: "\${title(${toHCLString string})}";
  trim = string: cutset: "\${trim(${toHCLString string}, ${toHCLString cutset})}";
  trimprefix = string: prefix: "\${trimprefix(${toHCLString string}, ${toHCLString prefix})}";
  trimsuffix = string: suffix: "\${trimsuffix(${toHCLString string}, ${toHCLString suffix})}";
  trimspace = string: "\${trimspace(${toHCLString string})}";
  upper = string: "\${upper(${toHCLString string})}";

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
    "\${lookup(${toHCLArg map}, ${toHCLString key}, ${toHCLArg default})}";
  matchkeys =
    values: keys: search_keys:
    "\${matchkeys(${toHCLArg values}, ${toHCLArg keys}, ${toHCLArg search_keys})}";
  merge = maps: "\${merge(${toHCLArgs maps})}";
  range =
    start: limit: step:
    "\${range(${toString start}, ${toString limit}, ${toString step})}";
  reverse = list: "\${reverse(${toHCLArg list})}";
  setintersection = sets: "\${setintersection(${toHCLArgs sets})}";
  setproduct = sets: "\${setproduct(${toHCLArgs sets})}";
  setunion = sets: "\${setunion(${toHCLArgs sets})}";
  slice =
    list: start: end:
    "\${slice(${toHCLArg list}, ${toString start}, ${toString end})}";
  sort = list: "\${sort(${toHCLArg list})}";
  transpose = map: "\${transpose(${toHCLArg map})}";
  values = map: "\${values(${toHCLArg map})}";
  zipmap = keys_list: values_list: "\${zipmap(${toHCLArg keys_list}, ${toHCLArg values_list})}";

  # Numeric & Math Functions
  abs = number: "\${abs(${toString number})}";
  ceil = number: "\${ceil(${toString number})}";
  floor = number: "\${floor(${toString number})}";
  log = number: base: "\${log(${toString number}, ${toString base})}";
  max = numbers: "\${max(${lib.concatStringsSep ", " (map toString numbers)})}";
  min = numbers: "\${min(${lib.concatStringsSep ", " (map toString numbers)})}";
  pow = number: exponent: "\${pow(${toString number}, ${toString exponent})}";
  signum = number: "\${signum(${toString number})}";

  # Encoding & Decoding Functions
  base64decode = string: "\${base64decode(${toHCLString string})}";
  base64encode = string: "\${base64encode(${toHCLString string})}";
  base64gzip = string: "\${base64gzip(${toHCLString string})}";
  csvdecode = string: "\${csvdecode(${toHCLString string})}";
  jsondecode = string: "\${jsondecode(${toHCLString string})}";
  jsonencode = value: "\${jsonencode(${toHCLArg value})}";
  urlencode = string: "\${urlencode(${toHCLString string})}";
  yamldecode = string: "\${yamldecode(${toHCLString string})}";
  yamlencode = value: "\${yamlencode(${toHCLArg value})}";

  # Filesystem & Path Functions
  abspath = path: "\${abspath(${toHCLString path})}";
  basename = path: "\${basename(${toHCLString path})}";
  dirname = path: "\${dirname(${toHCLString path})}";
  file = path: "\${file(${toHCLString path})}";
  filebase64 = path: "\${filebase64(${toHCLString path})}";
  fileexists = path: "\${fileexists(${toHCLString path})}";
  fileglob = pattern: "\${fileglob(${toHCLString pattern})}";
  fileset = path: pattern: "\${fileset(${toHCLString path}, ${toHCLString pattern})}";
  pathexpand = path: "\${pathexpand(${toHCLString path})}";
  templatefile = path: vars: "\${templatefile(${toHCLString path}, ${toHCLArg vars})}";

  # Crypto & Hash Functions
  bcrypt = string: cost: "\${bcrypt(${toHCLString string}, ${toString cost})}";
  md5 = string: "\${md5(${toHCLString string})}";
  rsadecrypt =
    ciphertext: private_key: "\${rsadecrypt(${toHCLString ciphertext}, ${toHCLString private_key})}";
  sha1 = string: "\${sha1(${toHCLString string})}";
  sha256 = string: "\${sha256(${toHCLString string})}";
  sha512 = string: "\${sha512(${toHCLString string})}";
  uuid = "\${uuid()}";
  uuidv5 = namespace: name: "\${uuidv5(${toHCLString namespace}, ${toHCLString name})}";

  # Date & Time Functions
  formatdate = spec: timestamp: "\${formatdate(${toHCLString spec}, ${toHCLString timestamp})}";
  timeadd = timestamp: duration: "\${timeadd(${toHCLString timestamp}, ${toHCLString duration})}";
  timestamp = "\${timestamp()}";
}
