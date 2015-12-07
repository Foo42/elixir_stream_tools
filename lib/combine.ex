defmodule StreamTools.Combine do
    use GenServer
    alias StreamTools.SubscriberList
    alias StreamTools.Subscriber

    def start_link(options \\ []) do
      args = case Keyword.get(options, :follow) do
        nil -> %{streams: %{}}
        follow -> %{streams: follow}
      end
      GenServer.start_link(__MODULE__, args, options)
    end

    def start(options \\ []) do
      args = case Keyword.get(options, :follow) do
        nil -> %{streams: %{}}
        follow -> %{streams: follow}
      end
      GenServer.start(__MODULE__, args, options)
    end

    def last_value(combined), do: GenServer.call(combined, {:last_value})

    def stream_latest_values(combined) do
      Stream.resource(
        fn -> begin_stream(combined) end,
        &get_next_stream_item(&1),
        &close_stream(combined,&1))
    end

    ###################################################

    def init(%{streams: streams}) do
        start_followers streams
        initial_values = streams |> Map.keys |> Enum.into(%{}, &{&1 ,nil} )
        {:ok, %{streams: streams, last_value: initial_values, subscribers: SubscriberList.new}}
    end

    def handle_call({:last_value}, _from, state = %{last_value: last_value}), do: {:reply, last_value, state}

    def handle_call({:update, stream_name, value}, _from, state = %{last_value: last_value}) do
        updated_values = Map.put last_value, stream_name, value
        SubscriberList.publish(state.subscribers, updated_values)
        {:reply, last_value, %{state | last_value: updated_values}}
    end

    def handle_call({:subscribe, subscriber_pid, subscriber_ref}, _from, state) do
      updated_subscribers = SubscriberList.add(state.subscribers, subscriber_pid, subscriber_ref)
      {:reply, :ok, %{state | subscribers: updated_subscribers}}
    end

    def handle_cast({:unsubscribe, pid, _ref}, state = %{subscribers: subscribers}) do
      updated_subscribers = SubscriberList.remove(subscribers, pid)
      {:noreply, %{state | subscribers: updated_subscribers}}
    end

    def handle_info({:DOWN, _ref, :process, pid, _reason}, state = %{subscribers: subscribers}) do
      updated_subscribers = SubscriberList.remove(subscribers, pid)
      {:noreply, %{state | subscribers: updated_subscribers}}
    end

    ###################################################

    defp start_followers streams do
        streams |> Enum.each &start_follower(&1)
    end

    defp start_follower(stream_details) do
        target = self
        spawn_link fn -> follow(stream_details, target) end
    end

    defp follow({name, stream}, target) do
        stream |> Stream.each(fn x -> update_value(target, name,x) end) |> Stream.run
    end

    defp update_value(combined, stream_name, value), do: GenServer.call(combined, {:update, stream_name, value})

    defp get_next_stream_item(ref) do
      case Subscriber.get_next_message(ref) do
        {:message, item} -> {[item],ref}
        {:end, {:DOWN, ^ref, _, _, reason}} ->
          Process.exit(self(), reason)
          {:halt, ref}
        {:end, :eos} -> {:halt, ref}
      end
    end

    defp begin_stream(combined) do
      ref = Process.monitor(combined)
      :ok = GenServer.call(combined, {:subscribe, self(), ref})
      ref
    end

    defp close_stream(combined, ref) do
      Process.demonitor(ref)
      GenServer.cast(combined, {:unsubscribe, self(), ref})
    end
end
