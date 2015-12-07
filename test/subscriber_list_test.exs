defmodule TestRegistry do
  def whereis_name([pid_to_return: pid]) do
    pid
  end
end

defmodule StreamTools.SubscriberListTests do
  alias StreamTools.SubscriberList
  alias StreamTools.Subscriber
  use ExUnit.Case

  test "add adds subscriber to list when subscriber is a pid" do
    assert SubscriberList.add(SubscriberList.new, self(), make_ref) |> Map.values
    # assert = ref
  end

  test "add adds subscriber to list when subscriber is a via_tuple" do
    expected = %{} |> Map.put(self, %Subscriber{pid: self})
    name = {:via, TestRegistry, [pid_to_return: self()]}
    assert [subscriber | []] = SubscriberList.add(SubscriberList.new, name, make_ref) |> Map.values
  end
end