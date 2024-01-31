defmodule ABI do
  @moduledoc """
  Documentation for ABI, the function interface language for Solidity.
  Generally, the ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

  alias ABI.FunctionSelector
  alias ABI.Parser
  alias ABI.TypeDecoder
  alias ABI.TypeEncoder
  alias ABI.Util

  @doc """
  Encodes the given data into the function signature or tuple signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
      ...> |> Base.encode16(case: :lower)
      "a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("(address[])", [{[]}] ) |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"

      iex> ABI.encode("baz(uint8)", [9999])
      ** (RuntimeError) Data overflow encoding uint, data `9999` cannot fit in 8 bits

      iex> ABI.encode("(uint,address)", [{50, <<1::160>> |> :binary.decode_unsigned}])
      ...> |> Base.encode16(case: :lower)
      "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("(string)", [{"Ether Token"}])
      ...> |> Base.encode16(case: :lower)
      "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"

      iex> ABI.encode("test(uint[], uint[])", [[1], [2]])
      ...> |> Base.encode16(case: :lower)
      "f0d7f6eb000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002"

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.encode([<<1::160>> |> :binary.decode_unsigned, true])
      ...> |> Base.encode16(case: :lower)
      "b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
  """

  def encode(function_signature, data, data_type \\ :input)

  def encode(function_signature, data, data_type) when is_binary(function_signature) do
    function_signature
    |> Parser.parse!()
    |> encode(data, data_type)
  end

  def encode(%FunctionSelector{} = function_selector, data, data_type) do
    TypeEncoder.encode(data, function_selector, data_type, :standard)
  end

  @doc """
  Encodes the given data into the given types in packed encoding mode.

  Note that packed encoding mode is ambiguous and cannot be decoded (there are no decode_packed functions).
  Also, tuples (structs) and nester arrays are not supported.

  More info https://docs.soliditylang.org/en/latest/abi-spec.html#non-standard-packed-mode

  ## Examples

      iex> ABI.encode_packed([{:uint, 16}], [0x12])
      ...> |> Base.encode16(case: :lower)
      "0012"

      iex> ABI.encode_packed([:string, {:uint, 16}], ["Elixir ABI", 0x12])
      ...> |> Base.encode16(case: :lower)
      "456c69786972204142490012"

      iex> ABI.encode_packed([{:int, 16}, {:bytes, 1}, {:uint, 16}, :string], [-1, <<0x42>>, 0x03, "Hello, world!"])
      ...> |> Base.encode16(case: :lower)
      "ffff42000348656c6c6f2c20776f726c6421"
  """
  def encode_packed(types, data) when is_list(types) do
    TypeEncoder.encode(data, types, :input, :packed)
  end

  @doc """
  Decodes the given data based on the function or tuple
  signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.decode("baz(uint,address)", "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [50, <<1::160>>]

      iex> ABI.decode("(address[])", "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{[]}]

      iex> ABI.decode("(string)", "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{"Ether Token"}]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.decode("b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [<<1::160>>, true]
  """

  def decode(function_signature, data, data_type \\ :input)

  def decode(function_signature, data, data_type) when is_binary(function_signature) do
    function_signature
    |> Parser.parse!()
    |> decode(data, data_type)
  end

  def decode(%FunctionSelector{} = function_selector, data, data_type) do
    TypeDecoder.decode(data, function_selector, data_type)
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
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> ABI.find_and_decode("b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      {%ABI.FunctionSelector{type: :function, function: "bark", input_names: ["at", "loudly"], method_id: <<184, 93, 11, 210>>, returns: [], types: [:address, :bool], state_mutability: :non_payable}, [<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>, true]}
  """
  def find_and_decode(function_selectors, data, data_type \\ :input) do
    with {:ok, method_id, _rest} <- Util.split_method_id(data),
         {:ok, selector} when not is_nil(selector) <-
           Util.find_selector_by_method_id(function_selectors, method_id) do
      {selector, decode(selector, data, data_type)}
    end
  end

  @doc """
  Parses the given ABI specification document into an array of `ABI.FunctionSelector`s.

  Non-function entries (e.g. constructors) in the ABI specification are skipped. Fallback function entries are accepted.

  This function can be used in combination with a JSON parser, e.g. [`Jason`](https://hex.pm/packages/Jason), to parse ABI specification JSON files.

  Opts:

    * `:include_events?` - Include events in the output list (as `%FunctionSelector{}` with a type of `:event`). Defaults to `false`
                           for backwards compatibility reasons.

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{type: :function, function: "bark", input_names: ["at", "loudly"], method_id: <<184, 93, 11, 210>>, returns: [], types: [:address, :bool], state_mutability: :non_payable},
       %ABI.FunctionSelector{type: :function, function: "rollover", method_id: <<176, 86, 180, 154>>, returns: [:bool], return_names: ["is_a_good_boy"], types: [], state_mutability: :non_payable}]

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
      [%ABI.FunctionSelector{type: :function, function: "bark", method_id: <<184, 93, 11, 210>>, input_names: ["at", "loudly"], returns: [], types: [:address, :bool], state_mutability: :non_payable}]

      iex> [%{
      ...>   "inputs" => [
      ...>      %{"name" => "_numProposals", "type" => "uint8"}
      ...>   ],
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "constructor"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: nil, input_names: ["_numProposals"], inputs_indexed: nil, method_id: <<99, 53, 230, 34>>, returns: [], type: :constructor, types: [uint: 8]}]

      iex> [%{
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "fallback"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{type: :function, function: nil, returns: [], types: [], method_id: nil}]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification(include_events?: true)
      ...> |> Enum.filter(&(&1.type == :event))
      [%ABI.FunctionSelector{type: :event, function: "WantsPets", input_names: ["_from_human", "_number", "_belly"], inputs_indexed: [true, false, true], method_id: <<235, 155, 60, 76, 236, 41, 90, 133, 158, 131, 71, 199, 88, 206, 85, 83, 36, 105, 140, 112, 231, 125, 249, 63, 87, 99, 121, 242, 184, 82, 161, 19>>, types: [:string, {:uint, 256}, :bool]}]

      iex> File.read!("priv/example1.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification(include_events?: true)
  """
  def parse_specification(doc, opts \\ []) do
    if opts[:include_events?] do
      doc
      |> Enum.map(&FunctionSelector.parse_specification_item/1)
      |> Enum.reject(&is_nil/1)
    else
      doc
      |> Enum.map(&FunctionSelector.parse_specification_item/1)
      |> Enum.reject(fn item -> is_nil(item) || item.type == :event end)
    end
  end
end
