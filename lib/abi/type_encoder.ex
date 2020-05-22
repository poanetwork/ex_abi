defmodule ABI.TypeEncoder do
  @moduledoc """
  `ABI.TypeEncoder` is responsible for encoding types to the format
  expected by Solidity. We generally take a function selector and an
  array of data and encode that array according to the specification.
  """

  @doc """
  Encodes the given data based on the function selector.
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
    types = List.duplicate(type, size) |> IO.inspect()
    {static, dynamic} = do_encode_tuple(types, data, static_acc, dynamic_acc) |> IO.inspect()

    if ABI.FunctionSelector.is_dynamic?(type) do
      data_bytes_size =
        Enum.reduce(dynamic, 0, fn value, acc ->
          byte_size(value) + acc
        end)
        |> IO.inspect()

      {[{:dynamic, data_bytes_size} | [static | static_acc]], [dynamic | dynamic_acc]}
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
