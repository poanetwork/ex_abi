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
    IO.inspect("####################### DECODING STARTED #######################")
    IO.inspect("decode 1:")
    {:ok, ^method_id, rest} = ABI.Util.split_method_id(encoded_data)
    [result] = decode_raw(rest, [{:tuple, types}])
    Tuple.to_list(result)
  end

  def decode(encoded_data, %FunctionSelector{types: types}) do
    IO.inspect("####################### DECODING STARTED #######################")
    IO.inspect("decode 2:")
    decode(encoded_data, types)
  end

  def decode(encoded_data, types) do
    IO.inspect("####################### DECODING STARTED #######################")
    IO.inspect("decode 3:")
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
    {result, _} = do_decode_raw(binary_data, types)
    result
  end

  def do_decode_raw(binary_data, types) do
    IO.inspect("do_decode_raw: ")

    {reversed_result, binary_rest} =
      Enum.reduce(types, {[], binary_data}, fn type, {acc, binary} ->
        IO.inspect("{acc, binary}")
        IO.inspect({acc, binary})

        {value, rest} =
          if ABI.FunctionSelector.is_dynamic?(type) do
            IO.inspect("Dynamic type")
            IO.inspect(type)
            decode_type(type, binary, binary_data)
            # decode_type(type, binary)
          else
            IO.inspect("Static type")
            IO.inspect(type)
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
    IO.inspect("decode_bytes left: ")
    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    IO.inspect("DATA:")
    IO.inspect(Base.encode16(data, case: :lower))

    IO.inspect("SIZE_IN_BYTES:")
    IO.inspect(size_in_bytes)

    IO.inspect("TOTAL_SIZE_IN_BYTES:")
    IO.inspect(total_size_in_bytes)

    IO.inspect("PADDING_SIZE_IN_BYTES:")
    IO.inspect(padding_size_in_bytes)

    <<_padding::binary-size(padding_size_in_bytes), value::binary-size(size_in_bytes),
      rest::binary()>> = data

    IO.inspect("{VALUE, REST}: 2 rows (decode_bytes left)")
    IO.inspect(value)
    IO.inspect(rest)

    {value, rest}
  end

  @spec decode_bytes(binary(), non_neg_integer(), :right, binary(), binary()) ::
          {binary(), binary()}
  def decode_bytes(data, size_in_bytes, :right, full_data, rest) do
    IO.inspect("DECODE_BYTES RIGHT: ")

    IO.inspect("DATA:")
    IO.inspect(Base.encode16(data, case: :lower))

    IO.inspect("FULL_DATA:")
    IO.inspect(Base.encode16(full_data, case: :lower))

    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    IO.inspect("SIZE_IN_BYTES:")
    IO.inspect(size_in_bytes)

    IO.inspect("TOTAL_SIZE_IN_BYTES:")
    IO.inspect(total_size_in_bytes)

    IO.inspect("PADDING_SIZE_IN_BYTES:")
    IO.inspect(padding_size_in_bytes)

    IO.inspect("rest")
    IO.inspect(Base.encode16(rest, case: :lower))

    # <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes),
    #   _rest::binary()>> = data

    <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes),
      rest2::binary()>> = full_data

    # IO.inspect("_rest")
    # IO.inspect(Base.encode16(_rest, case: :lower))

    IO.inspect("rest2")
    IO.inspect(Base.encode16(rest2, case: :lower))

    IO.inspect("{VALUE, REST}: 2 rows (decode_bytes right)")
    IO.inspect(Base.encode16(value, case: :lower))
    {value, rest2}
  end

  @spec decode_bytes(binary(), non_neg_integer(), :right, binary()) ::
          {binary(), binary()}
  def decode_bytes(data, size_in_bytes, :right, rest) do
    IO.inspect("DECODE_BYTES RIGHT: ")

    IO.inspect("DATA:")
    IO.inspect(Base.encode16(data, case: :lower))

    total_size_in_bytes = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    IO.inspect("SIZE_IN_BYTES:")
    IO.inspect(size_in_bytes)

    IO.inspect("TOTAL_SIZE_IN_BYTES:")
    IO.inspect(total_size_in_bytes)

    IO.inspect("PADDING_SIZE_IN_BYTES:")
    IO.inspect(padding_size_in_bytes)

    IO.inspect("REST:")
    IO.inspect(Base.encode16(rest, case: :lower))

    <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes),
      _rest::binary()>> = data

    # IO.inspect("_rest")
    # IO.inspect(Base.encode16(_rest, case: :lower))

    IO.inspect("{VALUE, REST}: 2 rows (decode_bytes right)")
    IO.inspect(Base.encode16(value, case: :lower))
    {value, rest}
  end

  @spec decode_type(ABI.FunctionSelector.type(), binary(), binary()) ::
          {any(), binary(), binary()}
  defp decode_type({:uint, size_in_bits}, data) do
    {value, rest} = decode_uint(data, size_in_bits)
    IO.inspect("{VALUE, REST}: 2 rows (decode_type uint)")
    IO.inspect(value)
    IO.inspect(Base.encode16(rest, case: :lower))
    {value, rest}
  end

  defp decode_type({:int, size_in_bits}, data) do
    {value, rest} = decode_int(data, size_in_bits)
    {value, rest}
  end

  defp decode_type({:array, type}, data) do
    IO.inspect("array data STATIC")
    IO.inspect(Base.encode16(data, case: :lower))
    {offset, rest_bytes} = decode_uint(data, 256)
    IO.inspect("array OFFSET STATIC")
    IO.inspect(offset)
    <<_padding::binary-size(offset), rest_data::binary>> = data
    {count, bytes} = decode_uint(rest_data, 256)
    IO.inspect("array COUNT STATIC")
    IO.inspect(count)
    IO.inspect("array bytes STATIC")
    IO.inspect(bytes)
    array_elements_bytes = 32 * count
    <<final_bytes::binary-size(array_elements_bytes), _rest_data::binary>> = bytes
    IO.inspect("array BYTES STATIC")
    IO.inspect(Base.encode16(rest_bytes, case: :lower))
    IO.inspect(Base.encode16(final_bytes, case: :lower))
    decode_type({:array, type, count}, final_bytes, rest_bytes)
  end

  defp decode_type({:bytes, size}, data) when size > 0 and size <= 32 do
    IO.inspect("decode_type bytes 2")
    decode_bytes(data, size, :right, data, data)
  end

  defp decode_type({:array, type, size}, data) do
    IO.inspect("DECODE_TYPE ARRAY STATIC:")
    IO.inspect(type)
    IO.inspect(size)
    types = List.duplicate(type, size)
    {tuple, bytes} = decode_type({:tuple, types}, data)
    IO.inspect("bytes STATIC:")
    IO.inspect(Base.encode16(bytes, case: :lower))
    IO.inspect("data STATIC:")
    IO.inspect(Base.encode16(data, case: :lower))
    IO.inspect("{VALUE, REST}: 2 rows (decode_type array STATIC)")
    IO.inspect(Tuple.to_list(tuple))
    IO.inspect(Base.encode16(bytes, case: :lower))
    {Tuple.to_list(tuple), bytes}
  end

  defp decode_type(:bytes, data) do
    IO.inspect("decode_type bytes simpilfied")
    IO.inspect("DATA")
    IO.inspect(Base.encode16(data, case: :lower))
    {byte_size, bytes} = decode_uint(data, 256)
    IO.inspect("BYTE_SIZE:")
    IO.inspect(byte_size)
    decode_bytes(bytes, byte_size, :right, <<>>)
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

    IO.inspect("REVERSED_RESULT STATIC:")
    IO.inspect(reversed_result)

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
    IO.inspect("decode_type string")
    decode_type(:bytes, data)
  end

  defp decode_type({:array, type}, data, full_data) do
    IO.inspect("array data DYNAMIC")
    IO.inspect(Base.encode16(data, case: :lower))
    {offset, rest_bytes} = decode_uint(data, 256)
    IO.inspect("array OFFSET DYNAMIC")
    IO.inspect(offset)
    <<_padding::binary-size(offset), rest_data::binary>> = full_data
    {count, bytes} = decode_uint(rest_data, 256)
    IO.inspect("array COUNT DYNAMIC")
    IO.inspect(count)
    IO.inspect("array BYTES DYNAMIC")
    IO.inspect(Base.encode16(bytes, case: :lower))
    array_elements_bytes = 32 * count
    <<final_bytes::binary-size(array_elements_bytes), _rest_data::binary>> = bytes
    IO.inspect("array REST_BYTES DYNAMIC")
    IO.inspect(Base.encode16(rest_bytes, case: :lower))
    IO.inspect("array FINAL_BYTES DYNAMIC")
    IO.inspect(Base.encode16(final_bytes, case: :lower))
    decode_type({:array, type, count}, final_bytes, rest_bytes)
  end

  defp decode_type({:array, type, size}, data, full_data) do
    IO.inspect("DECODE_TYPE ARRAY DYNAMIC:")
    IO.inspect(type)
    IO.inspect(size)
    types = List.duplicate(type, size)
    # ???
    IO.inspect("data DYNAMIC:")
    IO.inspect(Base.encode16(data, case: :lower))
    IO.inspect("full_data DYNAMIC:")
    IO.inspect(Base.encode16(full_data, case: :lower))
    {tuple, bytes} = decode_type({:tuple, types}, data, full_data)
    IO.inspect("tuple DYNAMIC:")
    IO.inspect(tuple)
    IO.inspect("bytes DYNAMIC:")
    IO.inspect(Base.encode16(bytes, case: :lower))
    IO.inspect("{VALUE, REST}: 2 rows (decode_type array DYNAMIC)")
    IO.inspect(Tuple.to_list(tuple))
    IO.inspect(full_data)
    {Tuple.to_list(tuple), full_data}
  end

  defp decode_type({:tuple, types}, data, full_data) do
    IO.inspect("DECODE TUPLE")
    IO.inspect("FULL_DATA:")
    IO.inspect(Base.encode16(full_data, case: :lower))
    IO.inspect("DATA:")
    IO.inspect(Base.encode16(data, case: :lower))
    # repairs 64, brokes ~8 tests
    # {offset, rest} = decode_uint(full_data, 256)
    # IO.inspect("OFFSET:")
    # IO.inspect(offset)
    # IO.inspect("REST:")
    # IO.inspect(Base.encode16(rest))
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

    IO.inspect("REVERSED_RESULT DYNAMIC:")
    IO.inspect(reversed_result)

    result_dynamic = []

    {result, _} =
      Enum.reduce(reversed_result, {[], result_dynamic}, fn
        value, {acc, dynamic} -> {[value | acc], dynamic}
      end)

    {List.to_tuple(result), binary}
  end

  defp decode_type(:string, data, full_data) do
    IO.inspect("decode_type string")
    decode_type(:bytes, data, full_data)
  end

  defp decode_type(:bytes, data, full_data) do
    IO.inspect("decode_type bytes 1")
    IO.inspect("DATA")
    IO.inspect(Base.encode16(data, case: :lower))
    IO.inspect("FULL_DATA")
    IO.inspect(Base.encode16(full_data, case: :lower))
    {offset, rest} = decode_uint(data, 256)
    IO.inspect("OFFSET:")
    IO.inspect(offset)
    IO.inspect("REST:")
    IO.inspect(Base.encode16(rest, case: :lower))
    <<_padding::binary-size(offset), rest_data::binary>> = full_data
    IO.inspect("DATA:")
    IO.inspect(Base.encode16(rest_data, case: :lower))
    {byte_size, dynamic_length_data} = decode_uint(rest_data, 256)
    IO.inspect("BYTE_SIZE:")
    IO.inspect(byte_size)
    IO.inspect("DYNAMIC_LENGTH_DATA:")
    IO.inspect(Base.encode16(dynamic_length_data, case: :lower))
    decode_bytes(dynamic_length_data, byte_size, :right, rest)
  end

  defp decode_type({:bytes, 0}, data, _),
    do: {<<>>, data}

  defp decode_type(els, _, _) do
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
end
