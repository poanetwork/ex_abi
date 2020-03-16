defmodule ABI.TypeEncoder do
  @moduledoc """
  `ABI.TypeEncoder` is responsible for encoding types to the format
  expected by Solidity. We generally take a function selector and an
  array of data and encode that array according to the specification.
  """

  @doc """
  Encodes the given data based on the function selector.

  ## Examples

      iex> [69, true]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          {:uint, 32},
      ...>          :bool
      ...>        ],
      ...>        returns: :bool
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "cdcd77c000000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"

      iex> [-5678, true]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          {:int, 256},
      ...>          :bool
      ...>        ],
      ...>        returns: :bool
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "d7aeca2bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe9d20000000000000000000000000000000000000000000000000000000000000001"

      iex> ["hello world"]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          :string,
      ...>        ]
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b68656c6c6f20776f726c64000000000000000000000000000000000000000000"

      iex> [{"awesome", true}]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [:string, :bool]}
      ...>        ]
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"

      iex> [{17, true, <<32, 64>>}]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [{:uint, 32}, :bool, {:bytes, 2}]}
      ...>        ]
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000012040000000000000000000000000000000000000000000000000000000000000"

      iex> [[17, 1]]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          {:array, {:uint, 32}, 2}
      ...>        ]
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "3d0ec53300000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"

      iex> [[17, 1], true]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}, 2},
      ...>          :bool
      ...>        ]
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"

      iex> [[17, 1]]
      ...> |> ABI.TypeEncoder.encode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}}
      ...>        ]
      ...>      }
      ...>    )
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
  """

  def encode(data, %ABI.FunctionSelector{function: nil, types: types}) do
    encode_raw(data, types)
  end

  def encode(data, %ABI.FunctionSelector{types: types} = function_selector) do
    # initial_offset = Enum.count(types)
    # initial_offset = 0
    # initial_offset =
    #   Enum.reduce(types, 0, fn type, offset ->
    #     IO.inspect("REDUCED TYPE")
    #     IO.inspect(type)

    #     case type do
    #       # {:array, _, size} ->
    #       #   offset + 1 #+ size

    #       # {:bytes, _, size} ->
    #       #   offset + 1 #+ size

    #       _ ->
    #         offset + 1
    #     end
    #   end)
    initial_offset = Enum.count(types)

    IO.inspect("INITIAL_OFFSET:")
    IO.inspect(initial_offset)

    {result, _, _, []} = encode_type({:tuple, types}, initial_offset, <<>>, [List.to_tuple(data)])

    encode_method_id(function_selector) <> result
  end

  def encode(data, types) do
    encode_raw(data, types)
  end

  @doc """
  Simiar to `ABI.TypeEncoder.encode/2` except we accept
  an array of types instead of a function selector. We also
  do not pre-pend the method id.

  ## Examples

      iex> [{"awesome", true}]
      ...> |> ABI.TypeEncoder.encode_raw([{:tuple, [:string, :bool]}])
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
  """
  def encode_raw(data, types) do
    IO.inspect("encode_raw")
    IO.inspect(types)

    # filtered_types =
    #   types
    #   |> Enum.filter(fn type ->
    #     false
    #     # if ABI.FunctionSelector.is_dynamic?(type) do
    #     #   false
    #     # else
    #     #   true
    #     # end
    #     # case type do
    #     #   {:tuple, _} ->
    #     #     false

    #     #   {:array, _} ->
    #     #     false

    #     #   {:array, _, _} ->
    #     #     false

    #     #   _ ->
    #     #     true
    #     # end
    #   end)

    # IO.inspect("filtered_types")
    # IO.inspect(filtered_types)
    # initial_offset Enum.count(filtered_types)
    # initial_offset = 0
    # initial_offset =
    #   Enum.reduce(types, 0, fn type, offset ->
    #     IO.inspect("REDUCED TYPE")
    #     IO.inspect(type)

    #     case type do
    #       # {:array, _, size} ->
    #       #   offset + 1 #+ size

    #       # {:bytes, _, size} ->
    #       #   offset + 1 #+ size

    #       _ ->
    #         offset + 1
    #     end
    #   end)
    initial_offset = Enum.count(types)

    IO.inspect("INITIAL_OFFSET:")
    IO.inspect(initial_offset)
    do_encode(types, initial_offset, <<>>, data, [])
  end

  @spec encode_method_id(%ABI.FunctionSelector{}) :: binary()
  defp encode_method_id(%ABI.FunctionSelector{function: nil}), do: ""

  defp encode_method_id(function_selector) do
    # Encode selector e.g. "baz(uint32,bool)" and take keccak
    kec =
      function_selector
      |> ABI.FunctionSelector.encode()
      |> ExthCrypto.Hash.Keccak.kec()

    # Take first four bytes
    <<init::binary-size(4), _rest::binary>> = kec

    # That's our method id
    init
  end

  @spec do_encode([ABI.FunctionSelector.type()], integer(), binary(), [any()], [binary()]) ::
          binary()
  defp do_encode([], _, dynamic_data, _, acc) do
    :erlang.iolist_to_binary(Enum.reverse(acc)) <> dynamic_data
  end

  defp do_encode([type | remaining_types], offset, dynamic_data, data, acc) do
    IO.inspect("do_encode")

    {encoded, offset, dynamic_data, remaining_data} =
      encode_type(type, offset, dynamic_data, data)

    do_encode(remaining_types, offset, dynamic_data, remaining_data, [encoded | acc])
  end

  # @spec encode_type(ABI.FunctionSelector.type(), integer(), any(), [any()]) ::
  #         {binary(), integer(), any(), [any()]}
  defp encode_type({:uint, size}, offset, dynamic_data, [data | rest]) do
    # offset = offset + 1
    {encode_uint(data, size), offset, dynamic_data, rest}
  end

  defp encode_type({:int, size}, offset, dynamic_data, [data | rest]) do
    # offset = offset + 1
    {encode_int(data, size), offset, dynamic_data, rest}
  end

  defp encode_type(:address, offset, dynamic_data, data) do
    # offset = offset + 1
    encode_type({:uint, 160}, offset, dynamic_data, data)
  end

  defp encode_type(:bool, offset, dynamic_data, [data | rest]) do
    # offset = offset + 1
    value =
      case data do
        true -> encode_uint(1, 8)
        false -> encode_uint(0, 8)
        _ -> raise "Invalid data for bool: #{data}"
      end

    {value, offset, dynamic_data, rest}
  end

  defp encode_type(:string, offset, dynamic_data, [data | rest]) do
    # offset = offset + 1
    IO.inspect("encode_type STRING")
    IO.inspect("data STRING:")
    IO.inspect(data)
    IO.inspect("rest STRING:")
    IO.inspect(rest)
    IO.inspect("offset STRING:")
    IO.inspect(offset)
    # length + value todo: value can spread to more than 32 bytes
    new_offset = offset + 1 + 1

    IO.inspect("DYNAMIC_DATA BEFORE (STRING)")
    IO.inspect(Base.encode16(dynamic_data))

    dynamic_data =
      if dynamic_data == <<>> do
        encode_uint(byte_size(data), 256) <> encode_bytes(data)
      else
        dynamic_data <> encode_uint(byte_size(data), 256) <> encode_bytes(data)
      end

    IO.inspect("DYNAMIC_DATA AFTER (STRING)")
    IO.inspect(Base.encode16(dynamic_data, case: :lower))

    current_offset = encode_uint(offset * 32, 256)

    IO.inspect("CURRENT_OFFSET")
    IO.inspect(Base.encode16(current_offset, case: :lower))

    {current_offset, new_offset, dynamic_data, rest}
  end

  defp encode_type(:bytes, offset, dynamic_data, [data | rest]) do
    # offset = offset + 1
    IO.inspect("encode_type BYTES")
    IO.inspect(offset)
    IO.inspect(dynamic_data)
    IO.inspect(data)
    IO.inspect(rest)
    IO.inspect("offset:")
    IO.inspect(offset)
    # length + value todo: value can spread to more than 32 bytes
    new_offset = offset + 1 + 1
    # {encode_uint(byte_size(data), 256) <> encode_bytes(data), offset, dynamic_data, rest}
    IO.inspect("DYNAMIC_DATA BEFORE (BYTES)")
    IO.inspect(Base.encode16(dynamic_data, case: :lower))

    dynamic_data =
      if dynamic_data == <<>> do
        encode_uint(byte_size(data), 256) <> encode_bytes(data)
      else
        dynamic_data <> encode_uint(byte_size(data), 256) <> encode_bytes(data)
      end

    IO.inspect("DYNAMIC_DATA AFTER (BYTES)")
    IO.inspect(Base.encode16(dynamic_data, case: :lower))

    current_offset = encode_uint(offset * 32, 256)

    IO.inspect("CURRENT_OFFSET")
    IO.inspect(Base.encode16(current_offset, case: :lower))

    {current_offset, new_offset, dynamic_data, rest}
  end

  defp encode_type({:bytes, size}, offset, dynamic_data, [data | rest])
       when is_binary(data) and byte_size(data) <= size do
    {encode_bytes(data), offset, dynamic_data, rest}
  end

  defp encode_type({:bytes, size}, _, _, [data | _]) when is_binary(data) do
    raise "size mismatch for bytes#{size}: #{inspect(data)}"
  end

  defp encode_type({:bytes, size}, _, _, [data | _]) do
    raise "wrong datatype for bytes#{size}: #{inspect(data)}"
  end

  defp encode_type({:tuple, types}, offset, dynamic_data, [data | rest]) do
    IO.inspect("encode_type TUPLE")
    IO.inspect(types)
    IO.inspect(offset)
    IO.inspect("TUPLE DATA:")
    IO.inspect(data)
    # all head items are 32 bytes in length and there will be exactly
    # `count(types)` of them, so the tail starts at `32 * count(types)`.
    tail_start = (types |> Enum.count()) * 32
    # initial_offset = Enum.count(types)
    # breakes a lot tests
    is_dynamic_tuple = Enum.any?(types, fn type -> ABI.FunctionSelector.is_dynamic?(type) end)
    IO.inspect("IS_DYNAMIC_TUPLE:")
    IO.inspect(is_dynamic_tuple)

    # prefix = if is_dynamic_tuple do
    #   encode_uint(offset * 32, 256)
    # else
    # <<>>
    # end

    # initial_offset = if is_dynamic_tuple, do: offset + 1, else: offset
    initial_offset = offset - 1 + Enum.count(types)

    IO.inspect("INITIAL_OFFSET:")
    IO.inspect(initial_offset)

    # inital_head =
    #   if is_dynamic_tuple do
    #     # fragile
    #     encode_uint(initial_offset * 32, 256)
    #     # encode_uint((offset + Enum.count(types)) * 32, 256)
    #     # if offset > 0 do
    #     #   encode_uint((offset + Enum.count(types)) * 32, 256)
    #     # else
    #     #   encode_uint(Enum.count(types) * 32, 256)
    #     # end
    #   else
    #     <<>>
    #   end

    # IO.inspect("INITAL_HEAD:")
    # IO.inspect(Base.encode16(inital_head, case: :lower))

    # breakes a lot of tests
    # initial_offset = Enum.count(types) + offset

    {head, tail, [], _, new_offset, new_dynamic_data} =
      Enum.reduce(
        types,
        {<<>>, <<>>, data |> Tuple.to_list(), tail_start, initial_offset, dynamic_data},
        fn type, {head, tail, data, tail_position, offset, dynamic_data} ->
          IO.inspect("TUPLE OFFSET:")
          IO.inspect(offset)
          IO.inspect("TUPLE TYPE:")
          IO.inspect(type)
          {el, new_offset, new_dynamic_data, rest} = encode_type(type, offset, dynamic_data, data)

          IO.inspect("TUPLE EL:")
          IO.inspect(Base.encode16(el, case: :lower))

          IO.inspect("TUPLE HEAD:")
          IO.inspect(Base.encode16(head, case: :lower))

          IO.inspect("TUPLE TAIL:")
          IO.inspect(Base.encode16(tail, case: :lower))

          IO.inspect("TUPLE TAIL_POSITION:")
          IO.inspect(tail_position)

          IO.inspect("TUPLE NEW_OFFSET:")
          IO.inspect(new_offset)

          IO.inspect("TUPLE REST:")
          IO.inspect(rest)

          {head <> el, tail, rest, new_offset * 32, new_offset, new_dynamic_data}
          # if ABI.FunctionSelector.is_dynamic?(type) do
          #   IO.inspect("TUPLE #1")
          #   # If we're a dynamic type, just encoded the length to head and the element to body
          #   # {head <> encode_uint(tail_position, 256), tail <> el, rest,
          #   # tail_position + byte_size(el), new_offset, new_dynamic_data}
          #   # {head <> encode_uint(tail_position, 256), tail, rest, tail_position + byte_size(el),
          #   # {head <> el, tail, rest, tail_position + byte_size(el), new_offset, new_dynamic_data}
          #   # {head <> encode_uint(tail_position, 256), tail, rest, tail_position + byte_size(el),
          #   #  new_offset, new_dynamic_data} #good (5)
          #   # {head <> encode_uint(tail_position, 256), tail, rest, tail_position + new_offset * 32,
          #   #  new_offset, new_dynamic_data} #very good (3)
          #   # {head <> encode_uint(tail_position, 256), tail, rest, new_offset * 32,
          #   #  new_offset, new_dynamic_data}
          #   {head <> el, tail, rest, new_offset * 32, new_offset, new_dynamic_data}
          # else
          #   IO.inspect("TUPLE #2")
          #   # If we're a static type, simply encode the el to the head
          #   # {head <> el, tail, rest, tail_position, new_offset, new_dynamic_data}
          #   {head <> el, tail, rest, new_offset * 32, new_offset, new_dynamic_data}
          # end
        end
      )

    new_offset = new_offset + Enum.count(types)

    IO.inspect("TUPLE HEAD FINAL:")
    IO.inspect(Base.encode16(head, case: :lower))
    IO.inspect("TUPLE TAIL FINAL:")
    IO.inspect(Base.encode16(tail, case: :lower))
    IO.inspect("TUPLE NEW_OFFSET FINAL:")
    IO.inspect(new_offset)
    IO.inspect("TUPLE NEW_DYNAMIC_DATA FINAL:")
    IO.inspect(Base.encode16(new_dynamic_data, case: :lower))
    IO.inspect("TUPLE REST FINAL:")
    IO.inspect(rest)

    {head <> tail, new_offset, new_dynamic_data, rest}
    # {prefix <> head <> tail, new_offset, new_dynamic_data, rest}
    # {encode_uint(offset * 32, 256) <> head <> tail, new_offset, new_dynamic_data, rest}
  end

  defp encode_type({:array, type, element_count}, offset, dynamic_data, [data | rest]) do
    IO.inspect("encode_type ARRAY")
    repeated_type = List.duplicate(type, element_count)
    IO.inspect("repeated_type:")
    IO.inspect(repeated_type)
    IO.inspect("offset:")
    IO.inspect(offset)
    IO.inspect("dynamic_data:")
    IO.inspect(dynamic_data)
    IO.inspect("data:")
    IO.inspect(data)
    encode_type({:tuple, repeated_type}, offset, dynamic_data, [data |> List.to_tuple() | rest])
  end

  defp encode_type({:array, type}, offset, dynamic_data, [data | _rest] = all_data) do
    IO.inspect("array offset:")
    IO.inspect(offset)
    IO.inspect("array data:")
    IO.inspect(data)

    element_count = Enum.count(data)

    {encoded_array, new_offset, dynamic_data, rest} =
      encode_type({:array, type, element_count}, offset, dynamic_data, all_data)

    IO.inspect("array new_offset:")
    IO.inspect(new_offset)

    # offset = offset + 1

    encoded_uint = encode_uint(element_count, 256)
    IO.inspect("DYNAMIC_DATA BEFORE 1")
    IO.inspect(Base.encode16(dynamic_data, case: :lower))

    dynamic_data =
      if dynamic_data == <<>> do
        encoded_uint <> encoded_array
      else
        dynamic_data <> encoded_uint <> encoded_array
      end

    IO.inspect("DYNAMIC_DATA AFTER 1")
    IO.inspect(Base.encode16(dynamic_data, case: :lower))

    IO.inspect("offset * 32:")
    IO.inspect(offset * 32)

    IO.inspect("encode_uint(offset * 32, 256):")
    IO.inspect(Base.encode16(encode_uint(offset * 32, 256), case: :lower))

    {encode_uint(offset * 32, 256), new_offset, dynamic_data, rest}
    # {<<>>, new_offset, dynamic_data, rest}
  end

  defp encode_type(els, a, b, c) do
    raise "Unsupported encoding type: #{inspect(els)} #{inspect(a)} #{inspect(b)} #{inspect(c)}"
  end

  def encode_bytes(bytes) do
    bytes |> pad(byte_size(bytes), :right)
  end

  # Note, we'll accept a binary or an integer here, so long as the
  # binary is not longer than our allowed data size
  defp encode_uint(data, size_in_bits) when rem(size_in_bits, 8) == 0 do
    size_in_bytes = (size_in_bits / 8) |> round
    bin = maybe_encode_unsigned(data)

    if byte_size(bin) > size_in_bytes,
      do:
        raise(
          "Data overflow encoding uint, data `#{data}` cannot fit in #{size_in_bytes * 8} bits"
        )

    bin |> pad(size_in_bytes, :left)
  end

  defp encode_int(data, size_in_bits) when rem(size_in_bits, 8) == 0 do
    if signed_overflow?(data, size_in_bits) do
      raise("Data overflow encoding int, data `#{data}` cannot fit in #{size_in_bits} bits")
    end

    encode_int(data)
  end

  # encoding with integer-signed-256 we already get the right padding
  defp encode_int(data), do: <<data::signed-256>>

  defp signed_overflow?(n, max_bits) do
    n < :math.pow(2, max_bits - 1) * -1 + 1 || n > :math.pow(2, max_bits - 1) - 1
  end

  # TODO change to ExthCrypto.Math.mod when it's fixed ( mod(-75,32) == 21 )
  def mod(x, n) do
    remainder = rem(x, n)

    if (remainder < 0 and n > 0) or (remainder > 0 and n < 0),
      do: n + remainder,
      else: remainder
  end

  defp pad(bin, size_in_bytes, direction) do
    # TODO: Create `left_pad` repo, err, add to `ExthCrypto.Math`
    total_size = size_in_bytes + mod(32 - size_in_bytes, 32)
    padding_size_bits = (total_size - byte_size(bin)) * 8
    padding = <<0::size(padding_size_bits)>>

    case direction do
      :left -> padding <> bin
      :right -> bin <> padding
    end
  end

  @spec maybe_encode_unsigned(binary() | non_neg_integer()) :: binary()
  defp maybe_encode_unsigned(bin) when is_binary(bin), do: bin
  defp maybe_encode_unsigned(int) when is_integer(int), do: :binary.encode_unsigned(int)
end
