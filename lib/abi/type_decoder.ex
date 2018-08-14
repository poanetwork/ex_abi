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
      ...>        returns: :bool
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
      ...>        returns: :int
      ...>      }
      ...>    )
      [-42]


      iex> "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b68656c6c6f20776f726c64000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
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

      iex> "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}}
      ...>        ]
      ...>      }
      ...>    )
      [[17, 1]]

      iex> "000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000011020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
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

      iex> "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [:string, :bool]}
      ...>        ]
      ...>      }
      ...>    )
      [{"awesome", true}]

      iex> "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [{:array, :address}]}
      ...>        ]
      ...>      }
      ...>    )
      [{[]}]

      iex> "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000c556e617574686f72697a656400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000204a2bf2ff0a4eaf1890c8d8679eaa446fb852c4000000000000000000000000861d9af488d5fa485bb08ab6912fff4f7450849a"
      ...> |> Base.decode16!(case: :lower)
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
  def decode(encoded_data, %FunctionSelector{types: types}) do
    decode_raw(encoded_data, types)
  end

  @doc """
  Similar to `ABI.TypeDecoder.decode/2` except accepts a list of types instead
  of a function selector.

  ## Examples

      iex> "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode_raw([{:tuple, [:string, :bool]}])
      [{"awesome", true}]
  """
  def decode_raw(binary_data, types) do
    decode_raw(binary_data, types, 0)
  end

  defp decode_raw(binary_data, types, initial_cursor_offset) do
    {reversed_result, _} =
      Enum.reduce(types, {[], initial_cursor_offset}, fn (type, {acc, cursor_offset}) ->
        do_decode_raw(binary_data, type, cursor_offset, acc)
      end)

    Enum.reverse(reversed_result)
  end

  defp do_decode_raw(binary_data, type, cursor_offset, acc) do
    {allocation, current_head_bit_length} = type_metadata(type)

    <<
      _prev :: bits-size(cursor_offset),
      current_head_data :: bits-size(current_head_bit_length),
      _rest :: binary
    >> = binary_data

    decoded_data = decode_data(binary_data, type, allocation, current_head_data)

    updated_acc = [decoded_data | acc]
    next_cursor_offset = cursor_offset + current_head_bit_length

    {updated_acc, next_cursor_offset}
  end

  defp decode_data(binary_data, type, allocation, head_data)

  defp decode_data(binary_data, {:tuple, sub_types}, :dynamic, head_data) do
    <<data_offset_byte_length :: integer-size(256) >> = head_data
    data_offset_bit_length = data_offset_byte_length * 8

    binary_data
    |> decode_raw(sub_types, data_offset_bit_length)
    |> List.to_tuple()
  end

  defp decode_data(_binary_data, {:tuple, sub_types}, :static, head_data) do
    head_data
    |> decode_raw(sub_types, 0)
    |> List.to_tuple()
  end

  defp decode_data(binary_data, {:array, type}, :dynamic, head_data) do
    <<data_offset_byte_length :: integer-size(256) >> = head_data

    <<
      _prev :: bytes-size(data_offset_byte_length),
      array_length_count :: integer-size(256),
      _rest :: binary
    >> = binary_data

    if array_length_count > 0 do
      types = for _ <- 1..array_length_count, do: type
      array_data_offset =  (data_offset_byte_length * 8) + 256

      decode_raw(binary_data, types, array_data_offset)
    else
      []
    end
  end

  defp decode_data(binary_data, {:array, type, count}, :dynamic, head_data) do
    repeated_type = for _ <- 1..count, do: type

    <<data_offset_byte_length :: integer-size(256) >> = head_data
    data_offset_bit_length = data_offset_byte_length * 8

    decode_raw(binary_data, repeated_type, data_offset_bit_length)
  end

  defp decode_data(_binary_data, {:array, type, count}, :static, head_data) do
    repeated_type = for _ <- 1..count, do: type
    decode_raw(head_data, repeated_type, 0)
  end

  defp decode_data(binary_data, type, :dynamic, head_data) do
    <<data_offset_byte_length :: integer-size(256) >> = head_data

    <<
      _prev :: bytes-size(data_offset_byte_length),
      type_data :: binary
    >> = binary_data

    {decoded_data, _} = decode_type(type, type_data)

    decoded_data
  end

  defp decode_data(_binary_data, type, :static, head_data) do
    {decoded_data, _} = decode_type(type, head_data)

    decoded_data
  end

  defp type_metadata({:tuple, sub_types}) do
    if Enum.any?(sub_types, &FunctionSelector.is_dynamic?/1) do
      {:dynamic, 256}
    else
      {:static, 256 * length(sub_types)}
    end
  end
  defp type_metadata({:array, type, count}) do
    if FunctionSelector.is_dynamic?(type) do
      {:dynamic, 256}
    else
      {:static, 256 * count}
    end
  end
  defp type_metadata(type) do
    type_head_bit_length = 256

    if FunctionSelector.is_dynamic?(type) do
      {:dynamic, type_head_bit_length}
    else
      {:static, type_head_bit_length}
    end
  end

  @spec decode_type(ABI.FunctionSelector.type(), binary()) :: {any(), binary()}
  defp decode_type({:uint, size_in_bits}, data) do
    decode_uint(data, size_in_bits)
  end

  defp decode_type({:int, size_in_bits}, data) do
    decode_int(data, size_in_bits)
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
    <<
      string_length_in_bytes :: integer-size(256),
      string_data :: binary
    >> = data

    <<
      string :: bytes-size(string_length_in_bytes),
      rest :: binary
    >> = string_data

    {string, rest}
  end

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

  @spec decode_bytes(binary(), integer(), atom()) :: {binary(), binary()}
  def decode_bytes(data, size_in_bytes, padding_direction) do
    # TODO: Create `unright_pad` repo, err, add to `ExthCrypto.Math`
    total_size_in_bytes = size_in_bytes + ExthCrypto.Math.mod(32 - size_in_bytes, 32)
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

  defp nul_terminate_string(raw_string) do
    raw_string = :erlang.iolist_to_binary(raw_string)
    [pre_nul_part | _] = :binary.split(raw_string, <<0>>)
    pre_nul_part
  end
end
