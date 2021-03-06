# config valid only for current version of Capistrano
## disabled so a regular CI build should catch incompatibilities
# lock "~> 3.8.0"

set :application, "top"
set :repo_url, "__REMOTE__"
set :distillery_release, :dummy2

set :repo_path, "dummy1_repo"
set :build_path, "build_path"
server "localhost", user: "user", roles: %w{build}
