defmodule ABI.TypeEncoder do
  @moduledoc """
  `ABI.TypeEncoder` is responsible for encoding types to the format
  expected by Solidity. We generally take a function selector and an
  array of data and encode that array according to the specification.
  """

  alias ABI.FunctionSelector

  @doc """
  Encodes the given data based on the function selector.
  """

  def encode(data, selector_or_types, data_type \\ :input)

  def encode(data, %FunctionSelector{function: nil, types: types}, :input) do
    do_encode(data, types)
  end

  def encode(data, %FunctionSelector{types: types} = function_selector, :input) do
    encode_method_id(function_selector) <> do_encode(data, types)
  end

  def encode(data, %FunctionSelector{returns: types}, :output) do
    do_encode(data, types)
  end

  def encode(data, types, _) when is_list(types) do
    do_encode(data, types)
  end

  def encode_raw(data, types) when is_list(types) do
    do_encode(data, types)
  end

  defp do_encode(params, types, static_acc \\ [], dynamic_acc \\ [])

  defp do_encode([], [], reversed_static_acc, reversed_dynamic_acc) do
    static_acc = Enum.reverse(reversed_static_acc)
    dynamic_acc = Enum.reverse(reversed_dynamic_acc)

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

  defp do_encode(
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
    binary_param = maybe_encode_unsigned(parameter)
    value = encode_uint(byte_size(binary_param), 256) <> encode_bytes(binary_param)

    dynamic_part_byte_size = byte_size(value)

    {[{:dynamic, dynamic_part_byte_size} | static_part], [value | dynamic_part]}
  end

  defp do_encode_type({:bytes, size}, parameter, static_part, dynamic_part)
       when is_binary(parameter) and byte_size(parameter) <= size do
    value = encode_bytes(parameter)

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type({:bytes, size}, data, _, _) when is_binary(data) do
    raise "size mismatch for bytes#{size}: #{inspect(data)}"
  end

  defp do_encode_type({:bytes, size}, data, static_part, dynamic_part) when is_integer(data) do
    binary_param = maybe_encode_unsigned(data)

    do_encode_type({:bytes, size}, binary_param, static_part, dynamic_part)
  end

  defp do_encode_type({:bytes, size}, data, _, _) do
    raise "wrong datatype for bytes#{size}: #{inspect(data)}"
  end

  defp do_encode_type({:array, type}, data, static_acc, dynamic_acc) do
    param_count = Enum.count(data)

    encoded_size = encode_uint(param_count, 256)

    types = List.duplicate(type, param_count)

    result = do_encode(data, types)

    dynamic_acc_with_size = [encoded_size | dynamic_acc]

    # number of elements count + data size
    data_bytes_size = byte_size(result) + 32

    {[{:dynamic, data_bytes_size} | static_acc], [result | dynamic_acc_with_size]}
  end

  defp do_encode_type({:array, type, size}, data, static_acc, dynamic_acc) do
    types = List.duplicate(type, size)
    result = do_encode(data, types)

    if FunctionSelector.is_dynamic?(type) do
      data_bytes_size = byte_size(result)

      {[{:dynamic, data_bytes_size} | static_acc], [result | dynamic_acc]}
    else
      {[result | static_acc], dynamic_acc}
    end
  end

  defp do_encode_type(:address, data, static_acc, dynamic_acc) do
    do_encode_type({:uint, 160}, data, static_acc, dynamic_acc)
  end

  defp do_encode_type(type = {:tuple, types}, tuple_parameters, static_acc, dynamic_acc)
       when is_tuple(tuple_parameters) do
    list_parameters = Tuple.to_list(tuple_parameters)

    result = do_encode(list_parameters, types)

    if FunctionSelector.is_dynamic?(type) do
      data_bytes_size = byte_size(result)

      {[{:dynamic, data_bytes_size} | static_acc], [result | dynamic_acc]}
    else
      {[result | static_acc], dynamic_acc}
    end
  end

  defp encode_bytes(bytes) do
    pad(bytes, byte_size(bytes), :right)
  end

  @spec encode_method_id(%FunctionSelector{}) :: binary()
  defp encode_method_id(%FunctionSelector{function: nil}), do: ""

  defp encode_method_id(function_selector) do
    # Encode selector e.g. "baz(uint32,bool)" and take keccak
    kec =
      function_selector
      |> FunctionSelector.encode()
      |> ExthCrypto.Hash.Keccak.kec()

    # Take first four bytes
    <<init::binary-size(4), _rest::binary>> = kec

    # That's our method id
    init
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
