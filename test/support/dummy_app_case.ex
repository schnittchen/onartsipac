defmodule DummyAppCase do
  use ExUnit.CaseTemplate

  defmodule Dummy do
    defstruct [
      :name,
      :version,

      :root_path, # root directory for the dummy test executions
      :hex_package_path, # where the dummy points to us as a mix dep
      :gem_path, # where the dummy points to us as a gem

      :remote, # git remote / dummy repository, used by build steps
      :capistrano_wd, # working dir when executing bundler and capistrano

      :build_path, # like in the dummy's deploy config, but absolute
      :app_path, # like in the dummy's deploy config, but absolute
      :distillery_env
    ]

    def new(name) do
      build_path = "/home/user/build_path"
      app_path = "/home/user/#{name}_app_path"

      %__MODULE__{
        name: name,
        version: "0.1.0",
        build_path: build_path,
        app_path: app_path,

        distillery_env: "prod" # fixed
      }
    end

    def kill_stray_processes(%__MODULE__{app_path: app_path} = dummy) do
      Enamel.new(as: "user", good_exits: [0, 1])
      |> Enamel.command([~w{pkill -f}, "^#{app_path |> Regex.escape}.*run_erl"])
      |> Enamel.run!

      dummy
    end

    def prepare_root_path(%__MODULE__{name: name} = dummy) do
      root_path = ["/tmp/working_paths", name] |> Path.join |> Path.expand

      File.rm_rf! root_path
      File.mkdir_p! root_path

      %{ dummy | root_path: root_path }
    end

    def prepare_gem_and_hex_package(%__MODULE__{root_path: root_path} = dummy, from: ".") do
      hex_package_path = [root_path, "hex_package"] |> Path.join
      File.mkdir_p! hex_package_path

      from = System.cwd |> Path.expand

      Enamel.new
      |> Enamel.command(~w{mix hex.build})
      |> Enamel.command(~w{tar xf #{from}/onartsipac-0.1.0.tar contents.tar.gz}, dir: hex_package_path)
      |> Enamel.command(~w{tar xf contents.tar.gz}, dir: hex_package_path)
      |> Enamel.run!

      gem_path = [root_path, "gem"] |> Path.join
      File.mkdir_p! gem_path

      Enamel.new
      |> Enamel.command(~w{rake build})
      |> Enamel.command(~w{tar xf #{from}/pkg/onartsipac-0.1.0.gem data.tar.gz}, dir: gem_path)
      |> Enamel.command(~w{tar xf data.tar.gz}, dir: gem_path)
      |> Enamel.run!

      %{ dummy | hex_package_path: hex_package_path, gem_path: gem_path }
    end

    def prepare_working_directory(
        %__MODULE__{
          name: name,
          root_path: root_path,
          hex_package_path: hex_package_path,
          gem_path: gem_path
        } = dummy) when is_binary(hex_package_path) and is_binary(gem_path) do
      capistrano_wd = [root_path, "wd"] |> Path.join

      File.mkdir_p! capistrano_wd
      File.cp_r! "./dummies/#{name}", capistrano_wd

      # We use "future" knowledge here, because we keep setup
      # simple by having the remote at the capistrano_wd
      remote_path = capistrano_wd

      Enamel.new
      |> Enamel.command([:find, capistrano_wd, ~w<-name mix.exs -exec sed -i
        s|__HEX_PACKAGE_PATH__|#{hex_package_path}| {} ;>])
      |> Enamel.command([:find, capistrano_wd, ~w<-name Gemfile -exec sed -i
        s|__GEM_PATH__|#{gem_path}| {} ;>])
      |> Enamel.command([:find, capistrano_wd, ~w<-name deploy.rb -exec sed -i
        s|__REMOTE__|#{remote_path}| {} ;>])
      |> Enamel.command([:bundle], dir: capistrano_wd)
      |> Enamel.run!

      %{ dummy | capistrano_wd: capistrano_wd, remote: remote_path }
    end

    def initialize_remote(%__MODULE__{remote: remote} = dummy) when is_binary(remote) do
      Enamel.command([~w{git -C}, remote, :init])
      |> Enamel.command([~w{git -C}, remote, ~w{config user.name}, "onartsipac test user"])
      |> Enamel.command([~w{git -C}, remote, ~w{config user.email onartsipac@example.com}])
      |> Enamel.command([~w{git -C}, remote, ~w{add .}])
      |> Enamel.command([~w{git -C}, remote, ~w{commit -m bogus}])
      |> Enamel.run!

      dummy
    end
  end

  using do
    quote do
      import DummyAppCase

      setup do
        "" <> name = @dummy_name
        dummy =
          Dummy.new(name)
          |> Dummy.kill_stray_processes
          |> Dummy.prepare_root_path
          |> Dummy.prepare_gem_and_hex_package(from: ".")
          |> Dummy.prepare_working_directory
          |> Dummy.initialize_remote

        {:ok, %{dummy: dummy}}
      end
    end
  end

  def assert_psuccess(%{err: nil, status: 0} = result) do
    result
  end

  def assert_psuccess({:error, reason}) do
    flunk "Error: #{reason}"
  end

  def assert_psuccess(%{err: nil, status: status} = result) do
    flunk "Error: Exit status #{status}"
  end

  def assert_psuccess(result) do
    flunk "Error: #{result.err}"
  end

  def assert_pfailure(%{status: 0}) do
    flunk "Error: status code was 0"
  end

  def assert_pfailure(%{status: status} = result) when is_integer(status) do
    result
  end
end
