defmodule ABI.PropertyTest do
  use PropCheck
  use ExUnit.Case

  alias ABI.{TypeDecoder, TypeEncoder}

  property "simple bool", [1000, :verbose, max_size: 100] do
    forall value <- bool() do
      encode_and_decode([:bool], [value])
    end
  end

  property "simple uint", [1000, :verbose, max_size: 100] do
    forall value <- non_neg_integer() do
      encode_and_decode([{:uint, 256}], [value])
    end
  end

  property "simple int", [1000, :verbose, max_size: 100] do
    forall value <- integer() do
      encode_and_decode([{:int, 256}], [value])
    end
  end

  property "simple bytes with size", [1000, :verbose, max_size: 100] do
    forall value <- non_empty(binary(8)) do
      encode_and_decode([{:bytes, 8}], [value])
    end
  end

  property "simple string", [1000, :verbose, max_size: 100] do
    forall value <- non_empty(binary()) do
      encode_and_decode([:string], [value])
    end
  end

  property "simple bytes", [1000, :verbose, max_size: 100] do
    forall value <- non_empty(binary()) do
      encode_and_decode([:bytes], [value])
    end
  end

  property "static tuple", [1000, :verbose, max_size: 100] do
    forall list <-
             list(union([non_neg_integer(), bool()])) do
      types =
        Enum.map(list, fn value ->
          if is_integer(value) do
            {:int, 256}
          else
            :bool
          end
        end)

      encode_and_decode([{:tuple, types}], [List.to_tuple(list)])
    end
  end

  property "dynamic tuple", [1000, :verbose, max_size: 100] do
    forall list <-
             list(union([non_neg_integer(), bool(), binary()])) do
      types =
        Enum.map(list, fn value ->
          cond do
            is_integer(value) -> {:int, 256}
            is_binary(value) -> :string
            true -> :bool
          end
        end)

      encode_and_decode([{:tuple, types}], [List.to_tuple(list)])
    end
  end

  defp encode_and_decode(types, values) do
    encoded_value = TypeEncoder.encode(values, types)
    decoded_value = TypeDecoder.decode(encoded_value, types)

    decoded_value == values
  end
end
