defmodule OnartsipacTest do
  @dummy_name "dummy1"
  use DummyAppCase, async: false

  setup %{dummy: dummy} do
    # Kill leftover processes
    %{status: status} =
      Porcelain.exec("sudo", ~w{su - user -c} ++ ["pkill -f ^#{dummy.app_path |> Regex.escape}.*run_erl"])
    if !(status in [0,1]) do
      raise "failed to pkill old processes"
    end

    File.rm_rf! dummy.onartsipac_path
    File.mkdir_p! dummy.onartsipac_path
    File.cp_r! ".", dummy.onartsipac_path
    File.rm_rf! Path.join(dummy.onartsipac_path, ".git")

    %{status: 0} =
      Porcelain.exec("find", ~w<#{dummy.remote} -name mix.exs -exec sed -i
        s|__ONARTSIPAC_PATH__|#{dummy.onartsipac_path}| {} ;>)

    %{status: 0} =
      Porcelain.exec("git", ~w{-C #{dummy.remote} init})

    %{status: 0} =
      Porcelain.exec("git", ~w{-C #{dummy.remote} config user.name} ++ ["onartsipac test user"])

    %{status: 0} =
      Porcelain.exec("git", ~w{-C #{dummy.remote} config user.email onartsipac@example.com})

    %{status: 0} =
      Porcelain.exec("git", ~w{-C #{dummy.remote} add .})

    %{status: 0} =
      Porcelain.exec("git", ~w{-C #{dummy.remote} commit -m bogus})

    %{status: 0} =
      Porcelain.exec("bundle", [], dummy.poptions)

    :ok
  end

  test "updating the repo cache", %{dummy: dummy} do
    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:repo:update}, dummy.poptions)
    |> assert_psuccess

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:repo:update}, dummy.poptions)
    |> assert_psuccess
  end

  test "cleaning the build path", %{dummy: dummy} do
    %{status: 0} =
      Porcelain.exec("sudo", ~w{su - user -c} ++ ["touch build_path"])

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:clean}, dummy.poptions)
    |> assert_psuccess

    assert !File.exists?(dummy.build_path)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:clean}, dummy.poptions)
    |> assert_psuccess
  end

  test "cleaning the build path partially", %{dummy: dummy} do
    %{status: 0} =
      Porcelain.exec("sudo", ~w{su - user -c} ++ ["mkdir -p build_path/foo"])

    %{status: 0} =
      Porcelain.exec("sudo", ~w{su - user -c} ++ ["mkdir -p build_path/deps/foo"])

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:clean:keepdeps}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?([dummy.build_path, "deps/foo"] |> Path.join)
    assert !File.exists?([dummy.build_path, "foo"] |> Path.join)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:clean:keepdeps}, dummy.poptions)
    |> assert_psuccess
  end

  test "preparing the build path and compiling", %{dummy: dummy} do
    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?([dummy.build_path, "mix.exs"] |> Path.join)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:compile}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?([dummy.build_path, "_build/prod/lib/dummy1"] |> Path.join)
  end

  test "executing mix release", %{dummy: dummy} do
    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:compile}, dummy.poptions)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:mix:release}, dummy.poptions)
    |> assert_psuccess

    distillery_env = dummy.name # TODO: make this configurable
    assert File.exists?(
      [dummy.build_path,
       "rel/#{distillery_env}/releases/#{dummy.version}/#{distillery_env}.tar.gz"] |> Path.join)
  end

  test "downloading a release archive", %{dummy: dummy} do
    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:compile}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:mix:release}, dummy.poptions)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:archive:download}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?(
      [dummy.remote, "archive.tar.gz"] |> Path.join)
  end

  test "uploading and unpacking a release archive", %{dummy: dummy} do
    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:compile}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:mix:release}, dummy.poptions)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:archive:download node:archive:upload_and_unpack}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?(
      [dummy.app_path, "bin/#{dummy.name}"] |> Path.join)
  end

  test "basic interaction with nodes", %{dummy: dummy} do
    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:compile}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:mix:release}, dummy.poptions)

    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:archive:download node:archive:upload_and_unpack}, dummy.poptions)

    Porcelain.exec("bundle", ~w{exec cap --trace production node:ping}, dummy.poptions)
    |> assert_pfailure

    Porcelain.exec("bundle", ~w{exec cap --trace production node:start}, dummy.poptions)
    |> assert_psuccess

    Porcelain.exec("bundle", ~w{exec cap --trace production node:start}, dummy.poptions)
    |> assert_psuccess

    Porcelain.exec("bundle", ~w{exec cap --trace production node:ping}, dummy.poptions)
    |> assert_psuccess

    Porcelain.exec("bundle", ~w{exec cap --trace production node:stop}, dummy.poptions)
    |> assert_psuccess

    Porcelain.exec("bundle", ~w{exec cap --trace production node:stop}, dummy.poptions)
    |> assert_pfailure

    Porcelain.exec("bundle", ~w{exec cap --trace production node:ping}, dummy.poptions)
    |> assert_pfailure

    Porcelain.exec("bundle", ~w{exec cap --trace production node:full_restart}, dummy.poptions)
    |> assert_psuccess

    Porcelain.exec("bundle", ~w{exec cap --trace production node:full_restart}, dummy.poptions)
    |> assert_psuccess
  end
end
