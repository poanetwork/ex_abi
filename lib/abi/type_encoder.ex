defmodule ABI.TypeEncoder do
  @moduledoc """
  `ABI.TypeEncoder` is responsible for encoding types to the format
  expected by Solidity. We generally take a function selector and an
  array of data and encode that array according to the specification.
  """

  alias ABI.FunctionSelector

  @doc """
  Encodes the given data based on the function selector.

  ## Parameters
  - data: The data to encode
  - selector_or_types: Either a FunctionSelector struct or a list of types to encode the data with
  - data_type: Determines which types to use from a FunctionSelector struct. Can be `:input` or `:output`.
  - mode: Encoding mode. Can be `:standard` or `:packed`.
  """

  def encode(data, selector_or_types, data_type \\ :input, mode \\ :standard)

  def encode(data, %FunctionSelector{function: nil, types: types}, :input, mode) do
    do_encode(data, types, mode)
  end

  def encode(data, %FunctionSelector{types: types} = function_selector, :input, mode) do
    encode_method_id(function_selector) <> do_encode(data, types, mode)
  end

  def encode(data, %FunctionSelector{returns: types}, :output, mode) do
    do_encode(data, types, mode)
  end

  def encode(data, types, _, mode) when is_list(types) do
    do_encode(data, types, mode)
  end

  def encode_raw(data, types, mode) when is_list(types) do
    do_encode(data, types, mode)
  end

  defp do_encode(params, types, static_acc \\ [], dynamic_acc \\ [], mode)

  defp do_encode([], [], reversed_static_acc, reversed_dynamic_acc, :standard) do
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
        new_static_acc = List.replace_at(acc, index, encode_uint(size_acc, 256, :standard))

        {new_static_acc, byte_size + size_acc}
      end)

    Enum.join(complete_static_part ++ dynamic_acc)
  end

  defp do_encode([], [], static_acc, dynamic_acc, :packed) do
    {values_acc, []} =
      Enum.reduce(static_acc, {[], dynamic_acc}, fn
        {:dynamic, _}, {values_acc, [value | dynamic_acc]} ->
          {[value | values_acc], dynamic_acc}

        value, {values_acc, dynamic_acc} ->
          {[value | values_acc], dynamic_acc}
      end)

    Enum.join(values_acc)
  end

  defp do_encode(
         [current_parameter | remaining_parameters],
         [current_type | remaining_types],
         static_acc,
         dynamic_acc,
         mode
       ) do
    {new_static_acc, new_dynamic_acc} =
      do_encode_type(current_type, current_parameter, static_acc, dynamic_acc, mode)

    do_encode(remaining_parameters, remaining_types, new_static_acc, new_dynamic_acc, mode)
  end

  defp do_encode_type(:bool, parameter, static_part, dynamic_part, mode) do
    value =
      case parameter do
        true -> encode_uint(1, 8, mode)
        false -> encode_uint(0, 8, mode)
        _ -> raise "Invalid data for bool: #{inspect(parameter)}"
      end

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type({:uint, size}, parameter, static_part, dynamic_part, mode) do
    value = encode_uint(parameter, size, mode)

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type({:int, size}, parameter, static_part, dynamic_part, mode) do
    value = encode_int(parameter, size, mode)

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type(:string, parameter, static_part, dynamic_part, mode) do
    do_encode_type(:bytes, parameter, static_part, dynamic_part, mode)
  end

  defp do_encode_type(:bytes, parameter, static_part, dynamic_part, mode) do
    binary_param = maybe_encode_unsigned(parameter)

    value =
      case mode do
        :standard ->
          encode_uint(byte_size(binary_param), 256, mode) <> encode_bytes(binary_param, mode)

        :packed ->
          encode_bytes(binary_param, mode)
      end

    dynamic_part_byte_size = byte_size(value)

    {[{:dynamic, dynamic_part_byte_size} | static_part], [value | dynamic_part]}
  end

  defp do_encode_type({:bytes, size}, parameter, static_part, dynamic_part, mode)
       when is_binary(parameter) and byte_size(parameter) <= size do
    value = encode_bytes(parameter, mode)

    {[value | static_part], dynamic_part}
  end

  defp do_encode_type({:bytes, size}, data, _, _, _) when is_binary(data) do
    raise "size mismatch for bytes#{size}: #{inspect(data)}"
  end

  defp do_encode_type({:bytes, size}, data, static_part, dynamic_part, mode)
       when is_integer(data) do
    binary_param = maybe_encode_unsigned(data)

    do_encode_type({:bytes, size}, binary_param, static_part, dynamic_part, mode)
  end

  defp do_encode_type({:bytes, size}, data, _, _, _) do
    raise "wrong datatype for bytes#{size}: #{inspect(data)}"
  end

  defp do_encode_type({:array, type}, data, static_acc, dynamic_acc, mode) do
    param_count = Enum.count(data)

    types = List.duplicate(type, param_count)

    result = do_encode(data, types, mode)

    {dynamic_acc_with_size, data_bytes_size} =
      case mode do
        :standard ->
          encoded_size = encode_uint(param_count, 256, mode)
          # length is included and also length size is added
          {[encoded_size | dynamic_acc], byte_size(result) + 32}

        :packed ->
          # ignoring length of array
          {dynamic_acc, byte_size(result)}
      end

    {[{:dynamic, data_bytes_size} | static_acc], [result | dynamic_acc_with_size]}
  end

  defp do_encode_type({:array, type, size}, data, static_acc, dynamic_acc, mode) do
    types = List.duplicate(type, size)
    result = do_encode(data, types, mode)

    if FunctionSelector.dynamic?(type) do
      data_bytes_size = byte_size(result)

      {[{:dynamic, data_bytes_size} | static_acc], [result | dynamic_acc]}
    else
      {[result | static_acc], dynamic_acc}
    end
  end

  defp do_encode_type(:address, data, static_acc, dynamic_acc, mode) do
    do_encode_type({:uint, 160}, data, static_acc, dynamic_acc, mode)
  end

  defp do_encode_type({:tuple, _types}, _, _, _, :packed) do
    raise RuntimeError, "Structs (tuples) are not supported in packed mode encoding"
  end

  defp do_encode_type(
         type = {:tuple, _types},
         tuple_parameters,
         static_acc,
         dynamic_acc,
         :standard
       )
       when is_tuple(tuple_parameters) do
    list_parameters = Tuple.to_list(tuple_parameters)

    do_encode_type(type, list_parameters, static_acc, dynamic_acc, :standard)
  end

  defp do_encode_type(type = {:tuple, types}, list_parameters, static_acc, dynamic_acc, :standard)
       when is_list(list_parameters) do
    result = do_encode(list_parameters, types, :standard)

    if FunctionSelector.dynamic?(type) do
      data_bytes_size = byte_size(result)

      {[{:dynamic, data_bytes_size} | static_acc], [result | dynamic_acc]}
    else
      {[result | static_acc], dynamic_acc}
    end
  end

  defp encode_bytes(bytes, mode) do
    pad(bytes, byte_size(bytes), :right, mode)
  end

  @spec encode_method_id(FunctionSelector.t()) :: binary()
  defp encode_method_id(%FunctionSelector{function: nil}), do: ""

  defp encode_method_id(function_selector) do
    keccak_module = Application.get_env(:ex_abi, :keccak_module, ExKeccak)
    # Encode selector e.g. "baz(uint32,bool)" and take keccak
    kec =
      function_selector
      |> FunctionSelector.encode()
      |> keccak_module.hash_256()

    # Take first four bytes
    <<init::binary-size(4), _rest::binary>> = kec

    # That's our method id
    init
  end

  # Note, we'll accept a binary or an integer here, so long as the
  # binary is not longer than our allowed data size
  defp encode_uint(data, size_in_bits, mode) when rem(size_in_bits, 8) == 0 do
    size_in_bytes = (size_in_bits / 8) |> round
    bin = maybe_encode_unsigned(data)

    if byte_size(bin) > size_in_bytes,
      do:
        raise(
          "Data overflow encoding uint, data `#{data}` cannot fit in #{size_in_bytes * 8} bits"
        )

    bin |> pad(size_in_bytes, :left, mode)
  end

  defp encode_int(data, size_in_bits, mode) when rem(size_in_bits, 8) == 0 do
    if signed_overflow?(data, size_in_bits) do
      raise("Data overflow encoding int, data `#{data}` cannot fit in #{size_in_bits} bits")
    end

    case mode do
      :standard -> <<data::signed-256>>
      :packed -> <<data::signed-size(size_in_bits)>>
    end
  end

  defp signed_overflow?(n, max_bits) do
    n < 2 ** (max_bits - 1) * -1 + 1 || n > 2 ** (max_bits - 1) - 1
  end

  def mod(x, n) do
    remainder = rem(x, n)

    if (remainder < 0 and n > 0) or (remainder > 0 and n < 0),
      do: n + remainder,
      else: remainder
  end

  defp pad(bin, size_in_bytes, _direction, :packed) when byte_size(bin) == size_in_bytes, do: bin

  defp pad(bin, size_in_bytes, direction, :packed) when byte_size(bin) < size_in_bytes do
    padding_size_bits = (size_in_bytes - byte_size(bin)) * 8
    padding = <<0::size(padding_size_bits)>>

    case direction do
      :left -> padding <> bin
      :right -> bin <> padding
    end
  end

  defp pad(bin, size_in_bytes, direction, :standard) do
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
