defmodule ABI do
  @moduledoc """
  Documentation for ABI, the function interface language for Solidity.
  Generally, the ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

  alias ABI.Util

  @doc """
  Encodes the given data into the function signature or tuple signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
      ...> |> Base.encode16(case: :lower)
      "a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("baz(uint8)", [9999])
      ** (RuntimeError) Data overflow encoding uint, data `9999` cannot fit in 8 bits

      iex> ABI.encode("(uint,address)", [{50, <<1::160>> |> :binary.decode_unsigned}])
      ...> |> Base.encode16(case: :lower)
      "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("(string)", [{"Ether Token"}])
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.encode([<<1::160>> |> :binary.decode_unsigned, true])
      ...> |> Base.encode16(case: :lower)
      "b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
  """
  def encode(function_signature, data) when is_binary(function_signature) do
    encode(ABI.Parser.parse!(function_signature), data)
  end

  def encode(%ABI.FunctionSelector{} = function_selector, data) do
    ABI.TypeEncoder.encode(data, function_selector)
  end

  @doc """
  Decodes the given data based on the function or tuple
  signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.decode("baz(uint,address)", "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [50, <<1::160>>]

      iex> ABI.decode("(address[])", "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{[]}]

      iex> ABI.decode("(string)", "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{"Ether Token"}]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.decode("00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [<<1::160>>, true]
  """
  def decode(function_signature, data) when is_binary(function_signature) do
    decode(ABI.Parser.parse!(function_signature), data)
  end

  def decode(%ABI.FunctionSelector{} = function_selector, data) do
    ABI.TypeDecoder.decode(data, function_selector)
  end

  @doc """
  Finds and decodes the correct function from a list of `ABI.FunctionSelector`s

  The function is found based on the `method_id`, which is generated from the
  keccak hash of the function head. More information can be found here:

  https://solidity.readthedocs.io/en/develop/abi-spec.html

  Keep in mind, you must include the method identifier in the passed in data
  otherwise this won't work as expected. If you are decoding transaction input data
  the identifier is the first four bytes and should already be there.

  To find and decode events instead of functions, see `find_and_decode_event/6`

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification
      ...> |> ABI.find_and_decode("b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      {%ABI.FunctionSelector{type: :function, function: "bark", input_names: ["at", "loudly"], method_id: <<184, 93, 11, 210>>, returns: [], types: [:address, :bool]}, [<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>, true]}
  """
  def find_and_decode(function_selectors, data) do
    with {:ok, method_id, rest} <- Util.split_method_id(data),
         {:ok, selector} when not is_nil(selector) <-
           Util.find_selector_by_method_id(function_selectors, method_id) do
      {selector, decode(selector, rest)}
    end
  end

  @doc """
  Parses the given ABI specification document into an array of `ABI.FunctionSelector`s.

  Non-function entries (e.g. constructors) in the ABI specification are skipped. Fallback function entries are accepted.

  This function can be used in combination with a JSON parser, e.g. [`Poison`](https://hex.pm/packages/poison), to parse ABI specification JSON files.

  Opts:

    * `:include_events?` - Include events in the output list (as `%FunctionSelector{}` with a type of `:event`). Defaults to `false`
                           for backwards compatibility reasons.

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{type: :function, function: "bark", input_names: ["at", "loudly"], method_id: <<184, 93, 11, 210>>, returns: [], types: [:address, :bool]},
       %ABI.FunctionSelector{type: :function, function: "rollover", method_id: <<176, 86, 180, 154>>, returns: [:bool], types: []}]

      iex> [%{
      ...>   "constant" => true,
      ...>   "inputs" => [
      ...>     %{"name" => "at", "type" => "address"},
      ...>     %{"name" => "loudly", "type" => "bool"}
      ...>   ],
      ...>   "name" => "bark",
      ...>   "outputs" => [],
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "function"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{type: :function, function: "bark", method_id: <<184, 93, 11, 210>>, input_names: ["at", "loudly"], returns: [], types: [:address, :bool]}]

      iex> [%{
      ...>   "inputs" => [
      ...>      %{"name" => "_numProposals", "type" => "uint8"}
      ...>   ],
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "constructor"
      ...> }]
      ...> |> ABI.parse_specification
      []

      iex> [%{
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "fallback"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{type: :function, function: nil, returns: [], types: [], method_id: nil}]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification(include_events?: true)
      ...> |> Enum.filter(&(&1.type == :event))
      [%ABI.FunctionSelector{type: :event, function: "WantsPets", input_names: ["_from_human", "_number", "_belly"], inputs_indexed: [true, false, true], method_id: <<235, 155, 60, 76>>, types: [:string, {:uint, 256}, :bool]}]
  """
  def parse_specification(doc, opts \\ []) do
    if opts[:include_events?] do
      doc
      |> Enum.map(&ABI.FunctionSelector.parse_specification_item/1)
      |> Enum.reject(&is_nil/1)
    else
      doc
      |> Enum.map(&ABI.FunctionSelector.parse_specification_item/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1.type == :event))
    end
  end
end
