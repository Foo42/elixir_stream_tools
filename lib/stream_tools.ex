defmodule StreamTools.Combine do
    use GenServer

    def start_link(stream_map, options \\ []), do: GenServer.start_link(__MODULE__, %{streams: stream_map}, options)

    def last_value(combined), do: GenServer.call(combined, {:last_value})

    ###################################################

    def init(%{streams: streams}) do
        start_followers streams
        initial_values = streams |> Map.keys |> Enum.into(%{}, &{&1 ,nil} )
        {:ok, %{streams: streams, last_value: initial_values}}
    end

    def handle_call({:last_value}, _from, state = %{last_value: last_value}), do: {:reply, last_value, state}
    def handle_call({:update, stream_name, value}, _from, state = %{last_value: last_value}) do
        updated_values = Map.put last_value, stream_name, value
        {:reply, last_value, %{state | last_value: updated_values}}
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
end
