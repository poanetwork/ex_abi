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

    [result] = decode_raw(rest, [{:tuple, types}])
    Tuple.to_list(result)
  end

  def decode(encoded_data, %FunctionSelector{types: types}) do
    decode(encoded_data, types)
  end

  def decode(encoded_data, types) do
    decode_raw(encoded_data, types)
  end

  @doc """
  Similar to `ABI.TypeDecoder.decode/2` except accepts a list of types instead
  of a function selector.

  ## Examples

      iex> ABI.TypeEncoder.encode([{"awesome", true}], [{:tuple, [:string, :bool]}])
      ...> |> ABI.TypeDecoder.decode_raw([{:tuple, [:string, :bool]}])
      [{"awesome", true}]
  """
  def decode_raw(binary_data, types) do
    {result, _} = do_decode_raw(binary_data, types, true)
    result
  end

  def do_decode_raw(binary_data, full_type, prefix_dynamic_tuple \\ false)

  def do_decode_raw(binary_data, full_type = [type = {:tuple, _}], true) do
    prefixed_tuple_data =
      if ABI.FunctionSelector.is_dynamic?(type) do
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 32>> <> binary_data
      else
        binary_data
      end

    do_decode_raw(prefixed_tuple_data, full_type, false)
  end

  def do_decode_raw(binary_data, full_type, true) do
    do_decode_raw(binary_data, full_type, false)
  end

  def do_decode_raw(binary_data, types, false) do
    {reversed_result, binary_rest} =
      Enum.reduce(types, {[], binary_data}, fn type, {acc, binary} ->
        {value, rest} =
          if ABI.FunctionSelector.is_dynamic?(type) do
            decode_type(type, binary, binary_data)
          else
            decode_type(type, binary)
          end

        {[value | acc], rest}
      end)

    {Enum.reverse(reversed_result), binary_rest}
  end

  # TODO change to ExthCrypto.Math.mod when it's fixed ( mod(-75,32) == 21 )
  def mod(x, n) do
    remainder = rem(x, n)

    if (remainder < 0 and n > 0) or (remainder > 0 and n < 0),
      do: n + remainder,
      else: remainder
  end

  @spec decode_bytes(binary(), non_neg_integer(), :left) ::
          {binary(), binary()}
  def decode_bytes(data, size_in_bytes, :left) do
    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    <<_padding::binary-size(padding_size_in_bytes), value::binary-size(size_in_bytes),
      rest::binary()>> = data

    {value, rest}
  end

  @spec decode_bytes(binary(), non_neg_integer(), :right, binary(), binary()) ::
          {binary(), binary()}
  def decode_bytes(_, size_in_bytes, :right, full_data, _) do
    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes),
      rest2::binary()>> = full_data

    {value, rest2}
  end

  @spec decode_bytes(binary(), non_neg_integer(), :right, binary()) ::
          {binary(), binary()}
  def decode_bytes(data, size_in_bytes, :right, rest) do
    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes),
      _rest::binary()>> = data

    {value, rest}
  end

  @spec decode_type(ABI.FunctionSelector.type(), binary(), binary()) ::
          {any(), binary(), binary()}
  defp decode_type({:uint, size_in_bits}, data) do
    decode_uint(data, size_in_bits)
  end

  defp decode_type({:int, size_in_bits}, data) do
    decode_int(data, size_in_bits)
  end

  defp decode_type({:bytes, size}, data) when size > 0 and size <= 32 do
    decode_bytes(data, size, :right, data, data)
  end

  defp decode_type({:array, type, size}, data) do
    types = List.duplicate(type, size)
    {tuple, bytes} = decode_type({:tuple, types}, data)

    {Tuple.to_list(tuple), bytes}
  end

  defp decode_type({:tuple, types}, data) do
    {reversed_result, _, binary} =
      Enum.reduce(types, {[], [], data}, fn type, {acc, dynamic, binary} ->
        if ABI.FunctionSelector.is_dynamic?(type) do
          {val, binary} = decode_type(type, binary, data)
          {[val | acc], [type | dynamic], binary}
        else
          {val, binary} = decode_type(type, binary)
          {[val | acc], dynamic, binary}
        end
      end)

    result_dynamic = []

    {result, _} =
      Enum.reduce(reversed_result, {[], result_dynamic}, fn
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

  defp decode_type(:string, data) do
    decode_type(:bytes, data)
  end

  defp decode_type({:array, type}, data, full_data) do
    {offset, rest_bytes} = decode_uint(data, 256)
    <<_padding::binary-size(offset), rest_data::binary>> = full_data
    {count, bytes} = decode_uint(rest_data, 256)

    types = List.duplicate(type, count)

    {tuple, _bytes} = decode_type({:tuple, types}, bytes)
    {Tuple.to_list(tuple), rest_bytes}
  end

  defp decode_type({:array, type, size}, data, full_data) do
    {offset, rest_bytes} = decode_uint(data, 256)
    <<_padding::binary-size(offset), rest_data::binary>> = full_data

    types = List.duplicate(type, size)

    {tuple, _} = decode_type({:tuple, types}, rest_data)

    {Tuple.to_list(tuple), rest_bytes}
  end

  defp decode_type({:tuple, types}, data, full_data) do
    {offset, rest_bytes} = decode_uint(data, 256)
    <<_padding::binary-size(offset), tuple_data::binary>> = full_data

    {reversed_result, _, _binary} =
      Enum.reduce(types, {[], [], tuple_data}, fn type, {acc, dynamic, binary} ->
        if ABI.FunctionSelector.is_dynamic?(type) do
          {val, binary} = decode_type(type, binary, tuple_data)
          {[val | acc], [type | dynamic], binary}
        else
          {val, binary} = decode_type(type, binary)
          {[val | acc], dynamic, binary}
        end
      end)

    result_dynamic = []

    {result, _} =
      Enum.reduce(reversed_result, {[], result_dynamic}, fn
        value, {acc, dynamic} -> {[value | acc], dynamic}
      end)

    {List.to_tuple(result), rest_bytes}
  end

  defp decode_type(:string, data, full_data) do
    decode_type(:bytes, data, full_data)
  end

  defp decode_type(:bytes, data, full_data) do
    {offset, rest} = decode_uint(data, 256)
    <<_padding::binary-size(offset), rest_data::binary>> = full_data
    {byte_size, dynamic_length_data} = decode_uint(rest_data, 256)
    decode_bytes(dynamic_length_data, byte_size, :right, rest)
  end

  defp decode_type({:bytes, 0}, data, _),
    do: {<<>>, data}

  defp decode_type(els, _, _) do
    raise "Unsupported decoding type: #{inspect(els)}"
  end

  @spec decode_uint(binary(), integer()) :: {integer(), binary()}
  def decode_uint(data, size_in_bits) do
    # TODO: Create `left_pad` repo, err, add to `ExthCrypto.Math`
    total_bit_size = size_in_bits + ExthCrypto.Math.mod(256 - size_in_bits, 256)
    <<value::integer-size(total_bit_size), rest::binary>> = data
    {value, rest}
  end

  defp decode_int(data, _size_in_bits) do
    <<value::signed-256, rest::binary>> = data
    {value, rest}
  end
end
