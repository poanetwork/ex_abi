defmodule ABI.RandomTest do
  use ExUnitProperties
  use ExUnit.Case

  alias ABI.TypeDecoder
  alias ABI.TypeEncoder

  import StreamData,
    only: [
      constant: 1,
      integer: 0,
      integer: 1,
      boolean: 0,
      string: 1,
      byte: 0,
      tuple: 1,
      list_of: 1,
      list_of: 2,
      member_of: 1,
      fixed_list: 1
    ]

  # types
  @ints for m <- 1..32, do: {:int, m * 8}
  @uints for m <- 1..32, do: {:uint, m * 8}
  @bytes for m <- 1..32, do: {:bytes, m}

  @base_types [:bool, :string, :bytes, :address] ++ @uints ++ @ints ++ @bytes

  # since `:address` type is decoded as `{:bytes, 20}`
  @except [:address]

  #

  # generates a `non_neg_integer`
  defp length(), do: StreamData.map(integer(), &abs/1)

  # generates a single type spec
  defp type(leafs, _nodes, 0), do: member_of(leafs)

  defp type(leafs, nodes, max_depth) do
    max_depth = max_depth - Enum.random(0..(max_depth - 1))

    StreamData.bind(member_of(leafs ++ nodes), fn
      :array ->
        tuple({constant(:array), type(leafs, nodes, max_depth)})

      :array_f ->
        tuple({constant(:array), type(leafs, nodes, max_depth), length()})

      :tuple ->
        tuple({constant(:tuple), list_of(type(leafs, nodes, max_depth), max_length: 4)})

      leaf ->
        constant(leaf)
    end)
  end

  defp types(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:max_length, opts[:max] || 4)
      |> Keyword.put_new(:min_length, opts[:min] || 0)
      |> Keyword.put_new(:max_depth, 3)
      |> Keyword.put_new(:nodes, [:array, :array_f, :tuple])
      |> Keyword.put_new(:only, @base_types -- @except)

    list_of(type(opts[:only], opts[:nodes], opts[:max_depth]), opts)
  end

  # generates a single argument
  defp arg(:string), do: string(:printable)
  defp arg(:bool), do: boolean()
  defp arg(:address), do: arg({:uint, 160})

  defp arg(:bytes) do
    list_of(byte())
    |> StreamData.map(&Binary.from_list/1)
  end

  defp arg({:bytes, m}) do
    list_of(byte(), length: m)
    |> StreamData.map(&Binary.from_list/1)
  end

  defp arg({:uint, m}) do
    l = round(:math.pow(2, m))
    integer(0..(l - 1))
  end

  defp arg({:int, m}) do
    hl = round(:math.pow(2, m - 1))
    integer(-hl..(hl - 1))
  end

  defp arg({:array, type, m}) do
    list_of(arg(type), length: m)
  end

  defp arg({:array, type}) do
    list_of(arg(type))
  end

  defp arg({:tuple, types}) do
    types
    |> Enum.map(&arg/1)
    |> List.to_tuple()
    |> tuple()
  end

  # generates values for the given `types`
  defp args(types) do
    fixed_list(Enum.map(types, &arg/1))
  end

  #

  describe "encode ∘ decode = id" do
    property "holds for any type" do
      check all types <- types(),
                args <- args(types) do
        #
        assert args == TypeEncoder.encode(args, types) |> TypeDecoder.decode(types)
      end
    end
  end
end
