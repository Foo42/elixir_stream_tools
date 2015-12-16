defmodule StreamWeaver.CombineTests do
  use ExUnit.Case
  alias StreamWeaver.Combine

  test "can start with name" do
    {:ok, _pid} = Combine.start_link name: :foo, follow: %{}
    assert Combine.get_current_value(:foo) == %{}
  end

  test "should begin with a map of nils for each stream" do
     {:ok, event_manager_a} = GenEvent.start_link
     {:ok, event_manager_b} = GenEvent.start_link
     stream_map = %{a: GenEvent.stream(event_manager_a), b: GenEvent.stream(event_manager_b)}
     {:ok, combined} = Combine.start_link follow: stream_map

     assert Combine.get_current_value(combined) == %{a: nil, b: nil}
  end

  test "should update get_current_value with values from input streams when they emit values" do
     {:ok, event_manager_a} = GenEvent.start_link
     {:ok, event_manager_b} = GenEvent.start_link
     stream_map = %{a: GenEvent.stream(event_manager_a), b: GenEvent.stream(event_manager_b)}
     {:ok, combined} = Combine.start_link follow: stream_map

     :timer.sleep(100)
     GenEvent.notify(event_manager_b, 5)
     :timer.sleep(100)
     assert Combine.get_current_value(combined) == %{a: nil, b: 5}
  end

  test "should stream combined value" do
     {:ok, event_manager_a} = GenEvent.start_link
     {:ok, event_manager_b} = GenEvent.start_link
     stream_map = %{a: GenEvent.stream(event_manager_a), b: GenEvent.stream(event_manager_b)}
     {:ok, combined} = Combine.start_link follow: stream_map
     test_pid = self
     spawn_link fn ->
         Combine.stream_from_current_value(combined) |> Stream.each(&send(test_pid,&1)) |> Stream.run
     end
     :timer.sleep(100)
     GenEvent.notify(event_manager_b, 5)
     assert_receive %{a: nil, b: 5}
  end

  test "should die when combiner process dies if streaming with stream_linked" do
     {:ok, event_manager_a} = GenEvent.start_link
     stream_map = %{a: GenEvent.stream(event_manager_a)}
     {:ok, combined} = Combine.start follow: stream_map
     test_pid = self
     follower = spawn fn ->
         Combine.stream_from_current_value(combined) |> Stream.each(&send(test_pid,&1)) |> Enum.into([])
         send test_pid, "exited nicely"
     end
     :timer.sleep(100)
     assert Process.alive? follower
     Process.exit(combined, :kill)
     :timer.sleep(100)
     refute Process.alive? follower
     refute_received "exited nicely"
  end

  test "should die when producer process dies if streaming with stream_linked" do
     {:ok, event_manager_a} = GenEvent.start
     stream_map = %{a: GenEvent.stream(event_manager_a)}
     {:ok, combined} = Combine.start follow: stream_map
     test_pid = self
     follower = spawn fn ->
         Combine.stream_from_current_value(combined) |> Stream.each(&send(test_pid,&1)) |> Enum.into([])
         send test_pid, "exited nicely"
     end
     :timer.sleep(100)
     assert Process.alive? follower
     Process.exit(combined, :kill)
     :timer.sleep(100)
     refute Process.alive? follower
     refute_received "exited nicely"
  end
end
