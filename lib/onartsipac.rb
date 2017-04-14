require "onartsipac/version"

load File.expand_path("../capistrano/tasks/buildhost.rake", __FILE__)

module Onartsipac
  def self.on_build_host(&block)
    hosts = roles(:build)

    if hosts.none?
      raise "No build host available."
    end

    if hosts.length > 1
      raise "There can only be one build host."
    end

    on hosts do |host|
      instance_eval(&block)
    end
  end

  module Buildhost
    def self.git
      Capistrano::SCM::Git.new
    end

    def self.build_path
      fetch(:build_path) { raise "no build_path configured" }
    end
  end
end
