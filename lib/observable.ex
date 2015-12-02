defmodule StreamTools.Observable do
  def start_link(stream) do
    {:ok, event_manager} = GenEvent.start_link
    result = {:ok, agent} = Agent.start_link(fn -> %{events: event_manager, value: :unset} end)
    start_follower(stream, agent)
    result
  end

  def start_link do
    {:ok, event_manager} = GenEvent.start_link
    Agent.start_link(fn -> %{events: event_manager, value: :unset} end)
  end

  def value(observable), do: Agent.get(observable, fn state -> state.value end)
  def set(observable, value) do
    Agent.update(observable, fn state ->
      GenEvent.notify(state.events, value)
      Map.put(state, :value, value)
    end)
  end
  def stream_from_previous(observable), do: [value(observable)] |> Stream.concat(get_update_stream(observable))

  defp get_update_stream(observable), do: observable |> Agent.get(&Map.get(&1, :events)) |> GenEvent.stream

  defp start_follower(stream, target) do
    IO.puts("following #{inspect target}")
    spawn_link(fn -> stream |> Stream.each(&set(target,&1)) |> Stream.run() end)
  end
end
