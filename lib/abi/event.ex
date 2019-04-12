defmodule ABI.Event do
  @moduledoc """
  Tools for decoding event data and topics given a list of function selectors.
  """

  alias ABI.Util
  alias ABI.FunctionSelector

  @type topic :: binary | nil

  @type event_value ::
          {name :: String.t(), type :: String.t(), indexed? :: boolean, value :: term}

  @doc """
  Finds the function selector in the ABI, and decodes the event data accordingly.

  Ensure that you included events when parsing the ABI, via `include_events?: true`

  You'll need to have the data separate from the topics, and pass each topic in
  separately. It isn't possible to properly decode the topics + data of an event
  without knowing the exact order of the topics, and having those topics
  separated from the data itself. That is why this function takes each topic
  (even if that topic value is nil) as a separate explicit argument.

  The first topic will be the keccak 256 hash of the function signature of the
  event. You should not have to calculate this, it should be present as the
  first topic of the event.

  If any of the topics are dynamic types, you will not be able to get the actual
  value of the string. Indexed arguments are placed in topics, and indexed
  dynamic types are actually indexed by their keccak 256 hash. The only way for
  a contract to provide that value *and* index the argument is to pass the same
  value into the event as two separate arguments, one that is indexed and one
  that is not. To signify this, those values are returned in a special tuple:
  `{:dynamic, value}`.

  Examples:

      iex> topic1 = :keccakf1600.hash(:sha3_256, "WantsPets(string,uint256,bool)")
      # first argument is indexed, so it is a topic
      ...> topic2 = :keccakf1600.hash(:sha3_256, "bob")
      # third argument is indexed, so it is also a topic
      ...> topic3 = "0000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!()
      # there are only two indexed arguments, so the fourth topic is `nil`
      ...> topic4 = nil
      # second argument is not, so it is in data
      ...> data = "0000000000000000000000000000000000000000000000000000000000000000" |> Base.decode16!()
      ...> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!()
      ...> |> ABI.parse_specification(include_events?: true)
      ...> |> ABI.Event.find_and_decode(topic1, topic2, topic3, topic4, data)
      {%ABI.FunctionSelector{
          type: :event,
          function: "WantsPets",
          input_names: ["_from_human", "_number", "_belly"],
          inputs_indexed: [true, false, true],
          method_id: <<235, 155, 60, 76>>,
          types: [:string, {:uint, 256}, :bool]
        },
        [
          {"_from_human", "string", true, {:dynamic, :keccakf1600.hash(:sha3_256, "bob")}},
          {"_number", "uint256", false, 0},
          {"_belly", "bool", true, true}
        ]
      }
  """
  @spec find_and_decode([FunctionSelector.t()], topic, topic, topic, topic, binary) ::
          {FunctionSelector.t(), [event_value]} | {:error, any}
  def find_and_decode(function_selectors, topic1, topic2, topic3, topic4, data) do
    with {:ok, method_id, _rest} <- Util.split_method_id(topic1),
         {:ok, selector} when not is_nil(selector) <-
           Util.find_selector_by_method_id(function_selectors, method_id) do
      input_topics = [topic2, topic3, topic4]

      args = Enum.zip([selector.input_names, selector.types, selector.inputs_indexed])

      {indexed_args, unindexed_args} =
        Enum.split_with(args, fn {_name, _type, indexed?} -> indexed? end)

      indexed_arg_values = indexed_arg_values(indexed_args, input_topics)

      unindexed_arg_types = Enum.map(unindexed_args, &elem(&1, 1))

      unindexed_arg_values = ABI.TypeDecoder.decode(data, unindexed_arg_types)

      {selector, format_event_values(args, indexed_arg_values, unindexed_arg_values)}
    end
  end

  defp indexed_arg_values(args, topics, acc \\ [])
  defp indexed_arg_values([], _, acc), do: Enum.reverse(acc)

  defp indexed_arg_values([{_, type, _} | rest_args], [topic | rest_topics], acc) do
    value =
      if ABI.FunctionSelector.is_dynamic?(type) do
        {bytes, _} = ABI.TypeDecoder.decode_bytes(topic, 32, :left)

        # This is explained in the docstring. The caller will almost certainly
        # need to know that they don't have an actual encoded value of that type
        # but rather they have a 32 bit hash of the value.

        {:dynamic, bytes}
      else
        topic
        |> ABI.TypeDecoder.decode([type])
        |> List.first()
      end

    indexed_arg_values(rest_args, rest_topics, [value | acc])
  end

  defp format_event_values(args, indexed_arg_values, unindexed_arg_values, acc \\ [])
  defp format_event_values([], _, _, acc), do: Enum.reverse(acc)

  defp format_event_values(
         [{name, type, _indexed? = true} | rest_args],
         [indexed_arg_value | indexed_args_rest],
         unindexed_arg_values,
         acc
       ) do
    encoded_type = ABI.FunctionSelector.encode_type(type)

    format_event_values(rest_args, indexed_args_rest, unindexed_arg_values, [
      {name, encoded_type, true, indexed_arg_value} | acc
    ])
  end

  defp format_event_values(
         [{name, type, _} | rest_args],
         indexed_arg_values,
         [unindexed_arg_value | unindexed_args_rest],
         acc
       ) do
    encoded_type = ABI.FunctionSelector.encode_type(type)

    format_event_values(rest_args, indexed_arg_values, unindexed_args_rest, [
      {name, encoded_type, false, unindexed_arg_value} | acc
    ])
  end
end
