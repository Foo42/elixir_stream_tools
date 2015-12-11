defmodule StreamWeaver.Subscriber do
  defstruct monitor: nil, subscriber_ref: nil, pid: nil
  def publish(%{pid: pid, subscriber_ref: subscriber_ref}, message) do
    send(pid, {:new_stream_item, subscriber_ref, message})
  end

  def get_next_message(subscriber_ref) do
    receive do
      {:new_stream_item, ^subscriber_ref, item} -> {:message, item}
      {:eos, ^subscriber_ref} -> {:end, :eos}
      {:DOWN, ^subscriber_ref, :process, _, reason} = down -> {:end, down}
    end
  end
end

defmodule StreamWeaver.SubscriberList do
  def new, do: %{}
  def add(subscriber_list, name, subscriber_ref) do
    pid = GenServer.whereis(name)
    monitor = Process.monitor(pid)
    subscriber = %StreamWeaver.Subscriber{pid: pid, monitor: monitor, subscriber_ref: subscriber_ref}
    subscriber_list |> Map.put(pid, subscriber)
  end

  def remove(subscriber_list, name) do
    pid = GenServer.whereis(name)
    case Map.pop(subscriber_list, pid) do
      {nil, _list} -> subscriber_list
      {%{monitor: monitor}, updated_subscribers} ->
        Process.demonitor(monitor)
        updated_subscribers
    end
  end

  def publish(subscriber_list, message) do
    subscriber_list
      |> Map.values
      |> Enum.each(&StreamWeaver.Subscriber.publish(&1, message))
  end
end