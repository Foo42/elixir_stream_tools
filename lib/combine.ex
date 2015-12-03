defmodule StreamTools.Combine do
    use GenServer

    def start_link(stream_map, options \\ []), do: GenServer.start_link(__MODULE__, %{streams: stream_map}, options)
    def start(stream_map, options \\ []), do: GenServer.start(__MODULE__, %{streams: stream_map}, options)

    def last_value(combined), do: GenServer.call(combined, {:last_value})

    def stream_linked(combined) do
      stream(combined, true)
    end
    def stream(combined, linked? \\ false) do
      Stream.resource(
        fn -> begin_stream(combined) end,
        &get_next_stream_item(&1, linked?),
        &close_stream(combined,&1))
    end

    ###################################################

    def init(%{streams: streams}) do
        start_followers streams
        initial_values = streams |> Map.keys |> Enum.into(%{}, &{&1 ,nil} )
        {:ok, %{streams: streams, last_value: initial_values, subscribers: %{}}}
    end

    def handle_call({:last_value}, _from, state = %{last_value: last_value}), do: {:reply, last_value, state}

    def handle_call({:update, stream_name, value}, _from, state = %{last_value: last_value}) do
        updated_values = Map.put last_value, stream_name, value
        publish_to_all_subscribers state.subscribers, updated_values
        {:reply, last_value, %{state | last_value: updated_values}}
    end

    def handle_call({:subscribe, subscriber_pid, subscriber_ref}, _from, state) do
      monitor = Process.monitor(subscriber_pid)
      updated_subscribers = state.subscribers |> Map.put(subscriber_pid, %{subscriber_monitor: monitor, subscriber_ref: subscriber_ref})
      {:reply, :ok, %{state | subscribers: updated_subscribers}}
    end

    def handle_cast({:unsubscribe, pid, ref}, state = %{subscribers: subscribers}) do
      case Map.get(state.subscribers, pid) do
        nil -> nil
        %{subscriber_monitor: monitor} -> Process.demonitor(monitor)
      end
      {:noreply, %{state | subscribers: Map.delete(subscribers, pid)}}
    end

    def handle_info({:DOWN, ref, :process, pid, _reason}, state = %{subscribers: subscribers}) do
      {:noreply, %{state | subscribers: Map.delete(subscribers, pid)}}
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

    defp publish_to_all_subscribers(subscribers, message), do: subscribers |> Enum.each(&publish_to_subscriber(&1, message))
    defp publish_to_subscriber({pid, %{subscriber_ref: ref}}, item), do: send(pid, {:new_stream_item, ref, item})

    defp get_next_stream_item(ref, linked? \\ false) do
      receive do
          {:new_stream_item, ref, item} -> {[item], ref}
          {:eos, ^ref} -> {:halt, ref}
          {:DOWN, ^ref, :process, _, _} ->
            if linked? do
              Process.exit(self(),:kill)
            end
            {:halt, ref}
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
