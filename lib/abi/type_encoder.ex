defmodule ABI.TypeEncoder do
  @moduledoc """
  `ABI.TypeEncoder` is responsible for encoding types to the format
  expected by Solidity. We generally take a function selector and an
  array of data and encode that array according to the specification.
  """

  @doc """
  Encodes the given data based on the function selector.

  ## Examples









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
    do_encode(data, types)
  end

  def encode(data, %ABI.FunctionSelector{types: types} = function_selector) do
    encode_method_id(function_selector) <> do_encode(data, types)
  end

  def encode(data, types) do
    do_encode(data, types)
  end

  def do_encode(params, types, static_acc \\ [], dynamic_acc \\ [])

  def do_encode([], [], [{static, dynamic}], []) do
    do_encode([], [], static, dynamic)
  end

  def do_encode([], [], static_acc, []) do
    static_acc
    |> List.flatten()
    |> Enum.reverse()
    |> Enum.reduce(<<>>, fn part, acc ->
      acc <> part
    end)
  end

  def do_encode([], [], [{:dynamic, _}], [dynamic_value]) when is_binary(dynamic_value) do
    encode_uint(32, 256) <> dynamic_value
  end

  def do_encode([], [], [{:dynamic, _}], [{static_part, dynamic_part}]) do
    encode_uint(32, 256) <> do_encode([], [], static_part, dynamic_part)
  end

  def do_encode([], [], [{:dynamic, _} | nested_static], [nested_dynamic])
      when is_list(nested_dynamic) and is_list(nested_static) do
    encode_uint(32, 256) <> do_encode([], [], nested_static, nested_dynamic)
  end

  def do_encode([], [], reversed_static_acc, reversed_dynamic_acc) do
    static_acc = reversed_static_acc |> List.flatten() |> Enum.reverse()

    dynamic_acc = reversed_dynamic_acc |> List.flatten() |> Enum.reverse()

    static_part_size =
      Enum.reduce(static_acc, 0, fn value, acc ->
        case value do
          {:dynamic, _} -> acc + 32
          _ -> acc + byte_size(value)
        end
      end)

    dynamic_indexes =
      static_acc
      |> Enum.with_index()
      |> Enum.filter(fn {value, _index} ->
        case value do
          {:dynamic, _} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn {{:dynamic, byte_size}, index} -> {index, byte_size} end)

    # |> Enum.zip(dynamic_acc)

    {complete_static_part, _} =
      Enum.reduce(dynamic_indexes, {static_acc, static_part_size}, fn {index, byte_size},
                                                                      {acc, size_acc} ->
        new_static_acc = List.replace_at(acc, index, encode_uint(size_acc, 256))
        new_prefix_size = byte_size + size_acc

        {new_static_acc, new_prefix_size}
      end)

    (complete_static_part ++ dynamic_acc)
    |> Enum.reduce(<<>>, fn part, acc ->
      acc <> part
    end)
  end

  def do_encode(
        [current_parameter | remaining_parameters],
        [current_type | remaining_types],
        static_acc,
        dynamic_acc
      ) do
    {new_static_acc, new_dynamic_acc} =
      do_encode_type(current_type, current_parameter, static_acc, dynamic_acc)

    do_encode(remaining_parameters, remaining_types, new_static_acc, new_dynamic_acc)
  end

  defp do_encode_type(:bool, parameter, static_part, dynamic_part) do
    value =
      case parameter do
        true -> encode_uint(1, 8)
        false -> encode_uint(0, 8)
        _ -> raise "Invalid data for bool: #{inspect(parameter)}"
      end

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type({:uint, size}, parameter, static_part, dynamic_part) do
    value = encode_uint(parameter, size)

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type({:int, size}, parameter, static_part, dynamic_part) do
    value = encode_int(parameter, size)

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type(:string, parameter, static_part, dynamic_part) do
    do_encode_type(:bytes, parameter, static_part, dynamic_part)
  end

  defp do_encode_type(:bytes, parameter, static_part, dynamic_part) do
    value = encode_uint(byte_size(parameter), 256) <> encode_bytes(parameter)

    dynamic_part_byte_size = byte_size(value)

    {[{:dynamic, dynamic_part_byte_size} | static_part], [value | dynamic_part]}
  end

  defp do_encode_type({:bytes, size}, parameter, static_part, dynamic_part)
       when is_binary(parameter) and byte_size(parameter) <= size do
    IO.inspect("hre")
    value = encode_uint(byte_size(parameter), 256) <> encode_bytes(parameter)
    IO.inspect(value)
    dynamic_part_byte_size = byte_size(value)

    {[{:dynamic, dynamic_part_byte_size} | static_part], [value | dynamic_part]}
    do_encode_type(:bytes, parameter, static_part, dynamic_part)
  end

  defp do_encode_type({:bytes, size}, data, _, _) when is_binary(data) do
    raise "size mismatch for bytes#{size}: #{inspect(data)}"
  end

  defp do_encode_type({:bytes, size}, data, _, _) do
    raise "wrong datatype for bytes#{size}: #{inspect(data)}"
  end

  defp do_encode_type({:array, type}, data, static_acc, dynamic_acc) do
    param_count = Enum.count(data)

    encoded_size = encode_uint(param_count, 256)

    types = List.duplicate(type, param_count)

    {static, dynamic} = do_encode_tuple(types, data, [], [])

    dynamic_acc_with_size = [encoded_size | dynamic_acc]

    data_bytes_size =
      Enum.reduce(static ++ dynamic, 0, fn value, acc ->
        byte_size(value) + acc
      end)

    if ABI.FunctionSelector.is_dynamic?(type) do
      {[{:dynamic, data_bytes_size + 32} | static_acc], [dynamic | dynamic_acc_with_size]}
    else
      {[{:dynamic, data_bytes_size + 32} | static_acc], [static | dynamic_acc_with_size]}
    end
  end

  defp do_encode_type({:array, type, size}, data, static_acc, dynamic_acc) do
    types = List.duplicate(type, size)
    {static, dynamic} = do_encode_tuple(types, data, static_acc, dynamic_acc)

    if ABI.FunctionSelector.is_dynamic?(type) do
      data_bytes_size =
        Enum.reduce(dynamic, 0, fn value, acc ->
          byte_size(value) + acc
        end)

      {[{:dynamic, data_bytes_size} | static_acc], [dynamic | dynamic_acc]}
    else
      {[static | static_acc], dynamic_acc}
    end
  end

  defp do_encode_type(:address, data, static_acc, dynamic_acc) do
    do_encode_type({:uint, 160}, data, static_acc, dynamic_acc)
  end

  defp do_encode_type(type = {:tuple, types}, tuple_parameters, static_acc, dynamic_acc)
       when is_tuple(tuple_parameters) do
    list_parameters = Tuple.to_list(tuple_parameters)

    {static, dynamic} = do_encode_tuple(types, list_parameters, static_acc, dynamic_acc)

    if ABI.FunctionSelector.is_dynamic?(type) do
      data_bytes_size =
        Enum.reduce(dynamic, 0, fn value, acc ->
          byte_size(value) + acc
        end)

      new_static = [static | static_acc]

      {[{:dynamic, data_bytes_size} | new_static], [dynamic | dynamic_acc]}
    else
      {[static | static_acc], [dynamic | dynamic_acc]}
    end
  end

  defp do_encode_tuple(
         [],
         [],
         static_acc,
         dynamic_acc
       ) do
    {static_acc, dynamic_acc}
  end

  defp do_encode_tuple(
         [type | remaining_types],
         [current_parameter | remaining_parameters],
         static_acc,
         dynamic_acc
       ) do
    {new_static_acc, new_dynamic_acc} =
      do_encode_type(type, current_parameter, static_acc, dynamic_acc)

    do_encode_tuple(remaining_types, remaining_parameters, new_static_acc, new_dynamic_acc)
  end

  defp encode_bytes(bytes) do
    pad(bytes, byte_size(bytes), :right)
  end

  #   def encode(data, types) do
  #     encode_raw(data, types)
  #   end

  #   @doc """
  #   Simiar to `ABI.TypeEncoder.encode/2` except we accept
  #   an array of types instead of a function selector. We also
  #   do not pre-pend the method id.

  #   ## Examples

  #       iex> [{"awesome", true}]
  #       ...> |> ABI.TypeEncoder.encode_raw([{:tuple, [:string, :bool]}])
  #       ...> |> Base.encode16(case: :lower)
  #       "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
  #   """
  #   def encode_raw(data, types) do
  #     initial_offset =
  #       if Enum.count(types) > 1 do
  #         Enum.count(types)
  #       else
  #         0
  #       end

  #     do_encode(types, initial_offset, <<>>, data, [])
  #   end

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

  #   @spec do_encode([ABI.FunctionSelector.type()], integer(), binary(), [any()], [binary()]) ::
  #           binary()
  #   defp do_encode([], _, dynamic_data, _, acc) do
  #     :erlang.iolist_to_binary(Enum.reverse(acc)) <> dynamic_data
  #   end

  #   defp do_encode([type | remaining_types], offset, dynamic_data, data, acc) do
  #     {encoded, offset, dynamic_data, remaining_data} =
  #       encode_type(type, offset, dynamic_data, data)

  #     do_encode(remaining_types, offset, dynamic_data, remaining_data, [encoded | acc])
  #   end

  #   # @spec encode_type(ABI.FunctionSelector.type(), integer(), any(), [any()]) ::
  #   #         {binary(), integer(), any(), [any()]}
  #   defp encode_type({:uint, size}, offset, dynamic_data, [data | rest]) do
  #     {encode_uint(data, size), offset, dynamic_data, rest}
  #   end

  #   defp encode_type({:int, size}, offset, dynamic_data, [data | rest]) do
  #     {encode_int(data, size), offset, dynamic_data, rest}
  #   end

  #   defp encode_type(:address, offset, dynamic_data, data) do
  #     encode_type({:uint, 160}, offset, dynamic_data, data)
  #   end

  #   defp encode_type(:bool, offset, dynamic_data, [data | rest]) do
  #     value =
  #       case data do
  #         true -> encode_uint(1, 8)
  #         false -> encode_uint(0, 8)
  #         _ -> raise "Invalid data for bool: #{data}"
  #       end

  #     {value, offset, dynamic_data, rest}
  #   end

  #   defp encode_type(:string, input_offset, dynamic_data, [data | rest]) do
  #     # length + value todo: value can spread to more than 32 bytes
  #     new_offset = input_offset + 1 + 1

  #     dynamic_data =
  #       if dynamic_data == <<>> do
  #         encode_uint(byte_size(data), 256) <> encode_bytes(data)
  #       else
  #         dynamic_data <> encode_uint(byte_size(data), 256) <> encode_bytes(data)
  #       end

  #     input_offset = if input_offset == 0, do: 1, else: input_offset
  #     current_offset = encode_uint(input_offset * 32, 256)

  #     {current_offset, new_offset, dynamic_data, rest}
  #   end

  #   defp encode_type(:bytes, input_offset, dynamic_data, [data | rest]) do
  #     # length + value todo: value can spread to more than 32 bytes
  #     new_offset = input_offset + 1 + 1

  #     dynamic_data =
  #       if dynamic_data == <<>> do
  #         encode_uint(byte_size(data), 256) <> encode_bytes(data)
  #       else
  #         dynamic_data <> encode_uint(byte_size(data), 256) <> encode_bytes(data)
  #       end

  #     input_offset = if input_offset == 0, do: 1, else: input_offset
  #     current_offset = encode_uint(input_offset * 32, 256)

  #     {current_offset, new_offset, dynamic_data, rest}
  #   end

  #   defp encode_type({:bytes, size}, offset, dynamic_data, [data | rest])
  #        when is_binary(data) and byte_size(data) <= size do
  #     {encode_bytes(data), offset, dynamic_data, rest}
  #   end

  #   defp encode_type({:bytes, size}, _, _, [data | _]) when is_binary(data) do
  #     raise "size mismatch for bytes#{size}: #{inspect(data)}"
  #   end

  #   defp encode_type({:bytes, size}, _, _, [data | _]) do
  #     raise "wrong datatype for bytes#{size}: #{inspect(data)}"
  #   end

  #   defp encode_type({:tuple, types}, offset, dynamic_data, [data | rest]) do
  #     # all head items are 32 bytes in length and there will be exactly
  #     # `count(types)` of them, so the tail starts at `32 * count(types)`.

  #     IO.inspect({{:tuple, types}, offset, dynamic_data, [data | rest]}, limit: :infinity)
  #     tail_start = (types |> Enum.count()) * 32

  #     initial_offset = offset + Enum.count(types)

  #     {head, tail, [], _, new_offset, new_dynamic_data} =
  #       Enum.reduce(
  #         types,
  #         {<<>>, <<>>, data |> Tuple.to_list(), tail_start, initial_offset, dynamic_data},
  #         fn type, {head, tail, data, _, offset, dynamic_data} ->
  #           {el, new_offset, new_dynamic_data, rest} = encode_type(type, offset, dynamic_data, data)

  #           {head <> el, tail, rest, new_offset * 32, new_offset, new_dynamic_data}
  #         end
  #       )

  #     {head <> tail, new_offset, new_dynamic_data, rest}
  #   end

  #   defp encode_type({:tuple, types}, offset, dynamic_data, [data | rest], encoded_prefix) do
  #     {encoded, new_offset, new_dynamic_data, rest} =
  #       encode_type({:tuple, types}, offset, dynamic_data, [data | rest])

  #     {encoded_prefix <> encoded, new_offset, new_dynamic_data, rest}
  #   end

  #   defp encode_type({:array, type, element_count}, input_offset, dynamic_data, [data | rest]) do
  #     repeated_type = List.duplicate(type, element_count)

  #     if ABI.FunctionSelector.is_dynamic?(type) do
  #       encode_type(
  #         {:tuple, repeated_type},
  #         input_offset,
  #         dynamic_data,
  #         [data |> List.to_tuple() | rest],
  #         encode_uint(32, 256)
  #       )
  #     else
  #       encode_type(
  #         {:tuple, repeated_type},
  #         input_offset,
  #         dynamic_data,
  #         [data |> List.to_tuple() | rest]
  #       )
  #     end
  #   end

  #   defp encode_type({:array, type}, input_offset, dynamic_data, [data | _rest] = all_data) do
  #     element_count = Enum.count(data)

  #     # we should add the length of array to offset
  #     offset_with_length = input_offset + 1

  #     {encoded_array, new_offset, dynamic_data, rest} =
  #       encode_type({:array, type, element_count}, offset_with_length, dynamic_data, all_data)

  #     encoded_uint = encode_uint(element_count, 256)

  #     dynamic_data =
  #       if dynamic_data == <<>> do
  #         encoded_uint <> encoded_array
  #       else
  #         dynamic_data <> encoded_uint <> encoded_array
  #       end

  #     input_offset = if input_offset == 0, do: 1, else: input_offset

  #     {encode_uint(input_offset * 32, 256), new_offset, dynamic_data, rest}
  #   end

  #   defp encode_type(els, a, b, c) do
  #     raise "Unsupported encoding type: #{inspect(els)} #{inspect(a)} #{inspect(b)} #{inspect(c)}"
  #   end

  #   def encode_bytes(bytes) do
  #     bytes |> pad(byte_size(bytes), :right)
  #   end

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
