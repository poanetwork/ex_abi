defmodule ABI do
  @moduledoc """
  Documentation for ABI, the function interface language for Solidity.
  Generally, the ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

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

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification
      ...> |> ABI.find_and_decode("b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      {%ABI.FunctionSelector{function: "bark", input_names: ["at", "loudly"], method_id: <<184, 93, 11, 210>>, returns: [], types: [:address, :bool]}, [<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>, true]}
  """
  def find_and_decode(function_selectors, data) do
    with {:ok, method_id, rest} <- split_method_id(data),
         {:ok, selector} when not is_nil(selector) <-
           find_selector_by_method_id(function_selectors, method_id) do
      {selector, decode(selector, rest)}
    end
  end

  @doc """
  Parses the given ABI specification document into an array of `ABI.FunctionSelector`s.

  Non-function entries (e.g. constructors) in the ABI specification are skipped. Fallback function entries are accepted.

  This function can be used in combination with a JSON parser, e.g. [`Poison`](https://hex.pm/packages/poison), to parse ABI specification JSON files.

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: "bark", input_names: ["at", "loudly"], method_id: <<184, 93, 11, 210>>, returns: [], types: [:address, :bool]},
       %ABI.FunctionSelector{function: "rollover", method_id: <<176, 86, 180, 154>>, returns: [:bool], types: []}]

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
      [%ABI.FunctionSelector{function: "bark", method_id: <<184, 93, 11, 210>>, input_names: ["at", "loudly"], returns: [], types: [:address, :bool]}]

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
      [%ABI.FunctionSelector{function: nil, returns: [], types: [], method_id: nil}]
  """
  def parse_specification(doc) do
    doc
    |> Enum.map(&ABI.FunctionSelector.parse_specification_item/1)
    |> Enum.reject(&is_nil/1)
  end

  defp find_selector_by_method_id(function_selectors, method_id_target) do
    function_selector =
      Enum.find(function_selectors, fn %{method_id: method_id} ->
        method_id == method_id_target
      end)

    if function_selector do
      {:ok, function_selector}
    else
      {:error, :no_matching_function}
    end
  end

  defp split_method_id(<<method_id::binary-size(4), rest::binary>>) do
    {:ok, method_id, rest}
  end

  defp split_method_id(_) do
    {:error, :invalid_data}
  end
end
