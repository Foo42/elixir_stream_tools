defmodule TestRegistry do
  def whereis_name([pid_to_return: pid]) do
    pid
  end
end

defmodule StreamWeaver.SubscriberListTests do
  alias StreamWeaver.SubscriberList
  alias StreamWeaver.Subscriber
  use ExUnit.Case

  test "add adds subscriber to list when subscriber is a pid" do
    assert SubscriberList.add(SubscriberList.new, self(), make_ref) |> Map.values
  end

  test "add adds subscriber to list when subscriber is a via_tuple" do
    name = {:via, TestRegistry, [pid_to_return: self()]}
    assert [subscriber | []] = SubscriberList.add(SubscriberList.new, name, make_ref) |> Map.values
  end
end