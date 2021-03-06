defmodule StreamWeaver.ObservableTests do
  use ExUnit.Case
  alias StreamWeaver.Observable

  test "can start with name" do
    {:ok, _pid} = Observable.start_link [name: :foo]
    assert Observable.get_current_value(:foo) == :unset
  end

  test "value should initially be :unset" do
    {:ok, observable} = Observable.start_link
    assert Observable.get_current_value(observable) == :unset
  end

  test "setting value should change it when queried" do
    {:ok, observable} = Observable.start_link
    Observable.set(observable, 5)
    assert Observable.get_current_value(observable) == 5
  end

  test "stream_from_current_value should return a stream with current value in and any changes in value" do
    test_pid = self()
    {:ok, observable} = Observable.start_link
    Observable.set(observable, 5)

    spawn_link fn ->
      stream_values =
        observable
        |> Observable.stream_from_current_value
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
    {:ok, observable} = Observable.start_link [follow: GenEvent.stream(events)]
    :timer.sleep(50)

    spawn_link fn ->
      stream_values =
        observable
        |> Observable.stream_from_current_value
        |> Stream.take(2)
        |> Enum.to_list

      send test_pid, {:stream_values, stream_values}
    end
    :timer.sleep(50)
    GenEvent.notify(events, 5)
    assert_receive {:stream_values, [:unset, 5]}
  end

  test "dies when stream it is following dies" do
    {:ok, source} = Observable.start
    {:ok, sink} = Observable.start [follow: Observable.stream_from_current_value(source)]
    :timer.sleep(50)
    sink_monitor = Process.monitor(sink)
    Process.exit(source, :kill)
    assert_receive {:DOWN, ^sink_monitor, _, _, :killed}

    Process.exit(sink, :kill) #Just to clean up if it fails
  end
end