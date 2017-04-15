defmodule OnartsipacTest do
  @dummy_name "dummy1"
  use DummyAppCase, async: false

  setup %{dummy: dummy} do
    File.rm_rf! dummy.base
    File.mkdir_p! dummy.base
    File.cp_r! ".", dummy.base
    File.rm_rf! Path.join(dummy.base, ".git")

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

  test "preparing the build path", %{dummy: dummy} do
    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?([dummy.build_path, "mix.exs"] |> Path.join)
  end

  test "executing mix deps.get", %{dummy: dummy} do
    # buildhost:mix:deps.get does not depend on :prepare_build_path to make debugging easier
    %{status: 0} =
      Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:prepare_build_path}, dummy.poptions)

    Porcelain.exec("bundle", ~w{exec cap --trace production buildhost:mix:deps.get}, dummy.poptions)
    |> assert_psuccess

    assert File.exists?([dummy.build_path, "deps/plug"] |> Path.join)
  end

end
