defmodule StreamWeaver.Observable do
  use GenServer
  alias StreamWeaver.SubscriberList
  alias StreamWeaver.Subscriber

  def start_link(options \\ []) when is_list(options) do
    defaults = %{value: :unset, subscribers: SubscriberList.new}
    state = case Keyword.get(options, :follow) do
      nil -> defaults
      stream -> defaults |> Map.put(:follow, stream)
    end
    GenServer.start_link __MODULE__, state, options
  end

  def start(options \\ []) when is_list(options) do
    defaults = %{value: :unset, subscribers: SubscriberList.new}
    state = case Keyword.get(options, :follow) do
      nil -> defaults
      stream -> defaults |> Map.put(:follow, stream)
    end
    GenServer.start __MODULE__, state, options
  end

  def init(args) do
    case Map.get(args, :follow) do
      nil -> nil
      stream ->
        start_follower(stream, self)
    end
    {:ok, args}
  end

  def get_current_value(observable), do: GenServer.call(observable, {:value})
  def set(observable, value), do: GenServer.call(observable, {:set, value})

  def stream_from_current_value(observable) do
    Stream.resource(
      fn -> begin_stream(observable) end,
      &get_next_stream_item(&1),
      &close_stream(observable,&1))
  end
  ########################################################

  def handle_call({:value}, _from, %{value: value} = state), do: {:reply, value, state}

  def handle_call({:set, value}, _from, state) do
    case state.value do
      ^value -> {:reply, :unchanged, state}
      _old_value ->
        SubscriberList.publish(state.subscribers, value)
        {:reply, :changed, %{state | value: value}}
    end
  end

  def handle_call({:subscribe, pid, ref}, _from, state) do
    subscribers = SubscriberList.add(state.subscribers, pid, ref)
    {:reply, {:ok, state.value}, %{state | subscribers: subscribers}}
  end

  def handle_cast({:unsubscribe, pid, _ref}, state) do
    subscribers = SubscriberList.remove(state.subscribers, pid)
    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state = %{subscribers: subscribers}) do
    {:noreply, %{state | subscribers: SubscriberList.remove(subscribers, pid)}}
  end

  ########################################################

  defp start_follower(stream, target) do
    spawn_link(fn -> stream |> Stream.each(&set(target,&1)) |> Stream.run() end)
  end

  defp get_next_stream_item({ref, first_item}) do
    {[first_item], ref}
  end

  defp get_next_stream_item(ref) do
    case Subscriber.get_next_message(ref) do
      {:message, item} -> {[item],ref}
      {:end, {:DOWN, ^ref, _, _, reason}} ->
        Process.exit(self(), reason)
        {:halt, ref}
      {:end, :eos} -> {:halt, ref}
    end
  end

  defp begin_stream(observable) do
    pid = GenServer.whereis(observable)
    ref = Process.monitor(pid)
    {:ok, start_value} = GenServer.call(observable, {:subscribe, self(), ref})
    {ref, start_value}
  end

  defp close_stream(combined, {ref,_value}), do: close_stream(combined, ref)
  defp close_stream(observable, ref) do
    Process.demonitor(ref)
    GenServer.cast(observable, {:unsubscribe, self(), ref})
  end
end
