package = "lapis-annotate"
version = "dev-1"

source = {
  url = "git://github.com/leafo/lapis-annotate.git"
}

description = {
  summary = "Annotate Lapis models with a comment describing schema",
  license = "MIT",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
}

dependencies = {
  "lua == 5.1",
  "lapis",
}

build = {
  type = "builtin",
  modules = {
    ["lapis.cmd.actions.annotate"] = "lapis/cmd/actions/annotate.lua",
  }
}

