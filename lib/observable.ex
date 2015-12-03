defmodule StreamTools.Observable do
  use GenServer

  def start_link(stream) do
    GenServer.start_link __MODULE__, %{value: :unset, following: stream, subscribers: %{}}
  end

  def start_link do
    GenServer.start_link __MODULE__, %{value: :unset,  subscribers: %{}}
  end

  def start(stream) do
    GenServer.start __MODULE__, %{value: :unset, following: stream, subscribers: %{}}
  end

  def start do
    GenServer.start __MODULE__, %{value: :unset,  subscribers: %{}}
  end

  def init(args) do
    case Map.get(args, :following) do
      nil -> nil
      stream ->
        start_follower(stream, self)
    end
    {:ok, args}
  end

  def value(observable), do: GenServer.call(observable, {:value})
  def set(observable, value), do: GenServer.call(observable, {:set, value})

  def stream_from_previous(observable) do
    updates = Stream.resource(
      fn -> begin_stream(observable) end,
      &get_next_stream_item(&1),
      &close_stream(observable,&1))
    Stream.concat([value(observable)], updates)
  end
  ########################################################

  def handle_call({:value}, _from, %{value: value} = state), do: {:reply, value, state}

  def handle_call({:set, value}, _from, state) do
    IO.puts "setting value from #{inspect state.value} to #{inspect value}"
    case state.value do
      ^value -> {:reply, :unchanged, state}
      _old_value ->
        publish(value, state.subscribers)
        {:reply, :changed, %{state | value: value}}
    end
  end

  def handle_call({:subscribe, pid, ref}, _from, state) do
    monitor = Process.monitor(pid)
    subscribers = state.subscribers |> Map.put(pid, %{subscriber_monitor: monitor, subscriber_ref: ref})
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_cast({:unsubscribe, pid, ref}, state) do
    case Map.get(state.subscribers, pid) do
      nil -> nil
      %{subscriber_monitor: monitor} -> Process.demonitor(monitor)
    end
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, pid)}}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state = %{subscribers: subscribers}) do
    {:noreply, %{state | subscribers: Map.delete(subscribers, pid)}}
  end

  ########################################################

  defp start_follower(stream, target) do
    IO.puts("following #{inspect target}")
    spawn_link(fn -> stream |> Stream.each(&set(target,&1)) |> Stream.run() end)
  end

  defp get_next_stream_item(ref) do
    receive do
        {:new_stream_item, ref, item} -> {[item], ref}
        {:eos, ^ref} -> {:halt, ref}
        {:DOWN, ^ref, :process, _, reason} ->
          Process.exit(self(), reason)
          {:halt, ref}
    end
  end

  defp begin_stream(observable) do
    ref = Process.monitor(observable)
    :ok = GenServer.call(observable, {:subscribe, self(), ref})
    ref
  end

  defp close_stream(observable, ref) do
    Process.demonitor(ref)
    GenServer.cast(observable, {:unsubscribe, self(), ref})
  end

  defp publish(value, subscribers) do
    IO.puts "publishing #{inspect value} to subscribers"
    subscribers
    |> Enum.each(fn {pid, %{subscriber_ref: ref}} -> send(pid, {:new_stream_item, ref, value}) end)
  end
end
