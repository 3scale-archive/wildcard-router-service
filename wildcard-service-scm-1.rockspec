rockspec_format = "1.1"
package = "wildcard-service"
version = "scm-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   summary = "*** please specify description summary ***",
   detailed = "*** please specify description description ***",
   homepage = "*** please specify description homepage ***",
   license = "MIT"
}
dependencies = {
   "apicast == scm-1"
}
build = {
   type = "builtin",
   modules = {
      ["wildcard-service.config.development"] = "config/development.lua",
      ["wildcard-service.config.production"] = "config/production.lua",
      ["wildcard-service.init"] = "src/wildcard-service/init.lua"
   },
   install = {}
}
