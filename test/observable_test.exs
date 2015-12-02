defmodule StreamTools.ObservableTests do
  use ExUnit.Case
  alias StreamTools.Observable

  test "value should initially be :unset" do
    {:ok, observable} = Observable.start_link
    assert Observable.value(observable) == :unset
  end

  test "setting value should change it when queried" do
    {:ok, observable} = Observable.start_link
    Observable.set(observable, 5)
    assert Observable.value(observable) == 5
  end

  test "stream_from_previous should return a stream with current value in and any changes in value" do
    test_pid = self()
    {:ok, observable} = Observable.start_link
    Observable.set(observable, 5)

    spawn_link fn ->
      stream_values =
        observable
        |> Observable.stream_from_previous
        |> Stream.take(2)
        |> Enum.to_list

      send test_pid, {:stream_values, stream_values}
    end

    :timer.sleep(50)
    Observable.set(observable, 6)

    assert_receive {:stream_values, [5, 6]}
  end

  test "giving a stream on start causes observable to follow it" do
    test_pid = self
    {:ok, events} = GenEvent.start_link
    {:ok, observable} = Observable.start_link GenEvent.stream(events)
    :timer.sleep(50)

    spawn_link fn ->
      stream_values =
        observable
        |> Observable.stream_from_previous
        |> Stream.take(2)
        |> Enum.to_list

      send test_pid, {:stream_values, stream_values}
    end
    :timer.sleep(50)
    GenEvent.notify(events, 5)
    assert_receive {:stream_values, [:unset, 5]}
  end
end