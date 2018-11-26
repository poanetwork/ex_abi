defmodule ABI.TypeDecoder do
  @moduledoc """
  `ABI.TypeDecoder` is responsible for decoding types to the format
  expected by Solidity. We generally take a function selector and binary
  data and decode that into the original arguments according to the
  specification.
  """

  alias ABI.FunctionSelector

  @doc """
  Decodes the given data based on the function selector.

  Note, we don't currently try to guess the function name?

  ## Examples

      iex> "00000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          {:uint, 32},
      ...>          :bool
      ...>        ],
      ...>        returns: [:bool]
      ...>      }
      ...>    )
      [69, true]

      iex> "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd6"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          {:int, 8}
      ...>        ],
      ...>        returns: [:int]
      ...>      }
      ...>    )
      [-42]


      iex> ABI.TypeEncoder.encode(["hello world"],[:string]) 
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          :string
      ...>        ]
      ...>      }
      ...>    )
      ["hello world"]

      iex> "00000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [{:uint, 32}, :bool]}
      ...>        ]
      ...>      }
      ...>    )
      [{17, true}]

      iex> ABI.TypeEncoder.encode([[17,1]],[{:array,{:uint,32}}]) 
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}}
      ...>        ]
      ...>      }
      ...>    )
      [[17, 1]]

      iex> ABI.TypeEncoder.encode([[17, 1], true, <<16, 32>>], [{:array, {:uint, 32}},:bool,{:bytes, 2}])
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}},
      ...>          :bool,
      ...>          {:bytes, 2}
      ...>        ]
      ...>      }
      ...>    )
      [[17, 1], true, <<16, 32>>]

      iex> ABI.TypeEncoder.encode([{"awesome", true}], [{:tuple, [:string, :bool]}]) 
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [:string, :bool]}
      ...>        ]
      ...>      }
      ...>    )
      [{"awesome", true}]

      iex> ABI.TypeEncoder.encode([{[]}],[{:tuple, [{:array, :address}]}])
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [{:array, :address}]}
      ...>        ]
      ...>      }
      ...>    )
      [{[]}]

      iex> ABI.TypeEncoder.encode( [{
      ...>  "Unauthorized",
      ...>  [
      ...>    184341788326688649239867304918349890235378717380,
      ...>    765664983403968947098136133435535343021479462042,
      ...>  ]
      ...> }], [{:tuple,[:string, {:array, {:uint, 256}}]}])
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [{:tuple,[
      ...>          :string,
      ...>          {:array, {:uint, 256}}
      ...>        ]}]
      ...>      }
      ...>    )
      [{
        "Unauthorized",
        [
          184341788326688649239867304918349890235378717380,
          765664983403968947098136133435535343021479462042,
        ]
      }]
  """

  def decode(encoded_data, %FunctionSelector{types: types, method_id: method_id})
      when is_binary(method_id) do
    {:ok, ^method_id, rest} = ABI.Util.split_method_id(encoded_data)
    {[result], <<>>} = decode_raw(rest, [{:tuple, types}])
    Tuple.to_list(result)
  end

  def decode(encoded_data, %FunctionSelector{types: types}) do
    decode(encoded_data, types)
  end

  def decode(encoded_data, types) do
    {result, <<>>} = decode_raw(encoded_data, types)
    result
  end

  @doc """
  Similar to `ABI.TypeDecoder.decode/2` except accepts a list of types instead
  of a function selector.

  ## Examples

      iex> ABI.TypeEncoder.encode([{"awesome", true}], [{:tuple, [:string, :bool]}]) 
      ...> |> ABI.TypeDecoder.decode_raw([{:tuple, [:string, :bool]}])
      {[{"awesome", true}], <<>>}
  """
  def decode_raw(binary_data, types) do
    {reversed_result, binary_rest} =
      Enum.reduce(types, {[], binary_data}, fn type, {acc, binary} ->
        {value, rest} = decode_type(type, binary)
        {[value | acc], rest}
      end)

    {Enum.reverse(reversed_result), binary_rest}
  end

  @spec decode_type(ABI.FunctionSelector.type(), binary()) :: {any(), binary()}
  defp decode_type({:uint, size_in_bits}, data), do: decode_uint(data, size_in_bits)

  defp decode_type({:int, size_in_bits}, data), do: decode_int(data, size_in_bits)

  defp decode_type({:array, type}, data) do
    {count, bytes} = decode_uint(data, 256)
    decode_type({:array, type, count}, bytes)
  end

  defp decode_type({:array, type, size}, data) do
    types = List.duplicate(type, size)
    {tuple, bytes} = decode_type({:tuple, types}, data)
    {Tuple.to_list(tuple), bytes}
  end

  defp decode_type({:tuple, types}, data) do
    {reversed_result, reversed_dynamic_types, binary} =
      Enum.reduce(types, {[], [], data}, fn type, {acc, dynamic, binary} ->
        if ABI.FunctionSelector.is_dynamic?(type) do
          {_, binary} = decode_uint(binary, 256)
          {[:dynamic | acc], [type | dynamic], binary}
        else
          {val, binary} = decode_type(type, binary)
          {[val | acc], dynamic, binary}
        end
      end)

    {reversed_result_dynamic, binary} = decode_raw(binary, Enum.reverse(reversed_dynamic_types))
    result_dynamic = Enum.reverse(reversed_result_dynamic)

    {result, _} =
      Enum.reduce(reversed_result, {[], result_dynamic}, fn
        :dynamic, {acc, [value | dynamic]} -> {[value | acc], dynamic}
        value, {acc, dynamic} -> {[value | acc], dynamic}
      end)

    {List.to_tuple(result), binary}
  end

  defp decode_type(:address, data), do: decode_bytes(data, 20, :left)

  defp decode_type(:bool, data) do
    {encoded_value, rest} = decode_uint(data, 8)

    value =
      case encoded_value do
        1 -> true
        0 -> false
      end

    {value, rest}
  end

  defp decode_type(:string, data), do: decode_type(:bytes, data)

  defp decode_type(:bytes, data) do
    {byte_size, rest} = decode_uint(data, 256)
    decode_bytes(rest, byte_size, :right)
  end

  defp decode_type({:bytes, 0}, data), do: {<<>>, data}

  defp decode_type({:bytes, size}, data) when size > 0 and size <= 32 do
    decode_bytes(data, size, :right)
  end

  defp decode_type(els, _) do
    raise "Unsupported decoding type: #{inspect(els)}"
  end

  @spec decode_uint(binary(), integer()) :: {integer(), binary()}
  defp decode_uint(data, size_in_bits) do
    # TODO: Create `left_pad` repo, err, add to `ExthCrypto.Math`
    total_bit_size = size_in_bits + ExthCrypto.Math.mod(256 - size_in_bits, 256)
    <<value::integer-size(total_bit_size), rest::binary>> = data
    {value, rest}
  end

  defp decode_int(data, _size_in_bits) do
    <<value::signed-256, rest::binary>> = data
    {value, rest}
  end

  # TODO change to ExthCrypto.Math.mod when it's fixed ( mod(-75,32) == 21 ) 
  def mod(x, n) do
    remainder = rem(x, n)

    if remainder < 0,
      do: n + remainder,
      else: remainder
  end

  @spec decode_bytes(binary(), integer(), atom()) :: {binary(), binary()}
  def decode_bytes(data, size_in_bytes, padding_direction) do
    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    case padding_direction do
      :left ->
        <<_padding::binary-size(padding_size_in_bytes), value::binary-size(size_in_bytes),
          rest::binary()>> = data

        {value, rest}

      :right ->
        <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes),
          rest::binary()>> = data

        {value, rest}
    end
  end
end
