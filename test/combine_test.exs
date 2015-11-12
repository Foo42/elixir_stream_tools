defmodule StreamTools.CombineTests do
  use ExUnit.Case
  alias StreamTools.Combine

  test "should begin with a map of nils for each stream" do
     {:ok, event_manager_a} = GenEvent.start_link
     {:ok, event_manager_b} = GenEvent.start_link
     stream_map = %{a: GenEvent.stream(event_manager_a), b: GenEvent.stream(event_manager_b)}
     {:ok, combined} = Combine.start_link stream_map

     assert Combine.last_value(combined) == %{a: nil, b: nil}
  end

  test "should update last_value with values from input streams when they emit values" do
     {:ok, event_manager_a} = GenEvent.start_link
     {:ok, event_manager_b} = GenEvent.start_link
     stream_map = %{a: GenEvent.stream(event_manager_a), b: GenEvent.stream(event_manager_b)}
     {:ok, combined} = Combine.start_link stream_map

     :timer.sleep(100)
     GenEvent.notify(event_manager_b, 5)
     :timer.sleep(100)
     assert Combine.last_value(combined) == %{a: nil, b: 5}
  end
end