defmodule ABI.FunctionSelector do
  @moduledoc """
  Module to help parse the ABI function signatures, e.g.
  `my_function(uint64, string[])`.
  """

  require Integer

  @type type ::
          {:uint, integer()}
          | :bool
          | :string
          | :address
          | :function
          | {:array, type}
          | {:array, type, non_neg_integer}
          | {:tuple, [type]}
          | :bytes
          | {:bytes, non_neg_integer}
          | {:ufixed, non_neg_integer, non_neg_integer}
          | {:fixed, non_neg_integer, non_neg_integer}
          | {:int, integer}

  @typedoc """
  Struct to represent a function and its input and output types.

  * `:function` - Name of the function
  * `:types` - Function's input types
  * `:returns` - Function's return types
  * `:method_id` - First four bits of the hashed function signature
  * `:input_names` - Names of the input values (argument names)
  * `:type` - The type of the selector. Events are part of the ABI, but are not considered functions
  * `:inputs_index` - A list of true/false values denoting if each input is indexed. Only populated for events.
  """
  @type t :: %__MODULE__{
          function: String.t() | nil,
          method_id: String.t() | nil,
          input_names: [String.t()],
          types: [type],
          returns: [type],
          type: :event | :function | :constructor,
          inputs_indexed: [boolean]
        }

  defstruct [
    :function,
    :method_id,
    :type,
    :inputs_indexed,
    input_names: [],
    types: [],
    returns: []
  ]

  @doc """
  Decodes a function selector to a struct.

  ## Examples

      iex> ABI.FunctionSelector.decode("bark(uint256,bool)")
      %ABI.FunctionSelector{
        function: "bark",
        types: [
          {:uint, 256},
          :bool
        ],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("growl(uint,address,string[])")
      %ABI.FunctionSelector{
        function: "growl",
        types: [
          {:uint, 256},
          :address,
          {:array, :string}
        ],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("rollover()")
      %ABI.FunctionSelector{
        function: "rollover",
        types: [],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("do_playDead3()")
      %ABI.FunctionSelector{
        function: "do_playDead3",
        types: [],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("pet(address[])")
      %ABI.FunctionSelector{
        function: "pet",
        types: [
          {:array, :address}
        ],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("paw(string[2])")
      %ABI.FunctionSelector{
        function: "paw",
        types: [
          {:array, :string, 2}
        ],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("scram(uint256[])")
      %ABI.FunctionSelector{
        function: "scram",
        types: [
          {:array, {:uint, 256}}
        ],
        returns: []
      }

      iex> ABI.FunctionSelector.decode("shake((string))")
      %ABI.FunctionSelector{
        function: "shake",
        types: [
          {:tuple, [:string]}
        ],
        returns: []
      }
  """
  def decode(signature) do
    ABI.Parser.parse!(signature, as: :selector)
  end

  @doc """
  Decodes the given type-string as a simple array of types.

  ## Examples

      iex> ABI.FunctionSelector.decode_raw("string,uint256")
      [:string, {:uint, 256}]

      iex> ABI.FunctionSelector.decode_raw("")
      []
  """
  def decode_raw(type_string) do
    {:tuple, types} = decode_type("(#{type_string})")
    types
  end

  @doc false
  def parse_specification_item(%{"type" => "function"} = item) do
    %{
      "name" => function_name,
      "inputs" => named_inputs,
      "outputs" => named_outputs
    } = item

    input_types = Enum.map(named_inputs, &parse_specification_type/1)
    input_names = Enum.map(named_inputs, &Map.get(&1, "name"))

    output_types = Enum.map(named_outputs, &parse_specification_type/1)

    selector = %ABI.FunctionSelector{
      function: function_name,
      types: input_types,
      returns: output_types,
      input_names: input_names,
      type: :function
    }

    add_method_id(selector)
  end

  def parse_specification_item(%{"type" => "constructor"} = item) do
    %{
      "inputs" => named_inputs
    } = item

    input_types = Enum.map(named_inputs, &parse_specification_type/1)
    input_names = Enum.map(named_inputs, &Map.get(&1, "name"))

    selector = %ABI.FunctionSelector{
      types: input_types,
      input_names: input_names,
      type: :constructor
    }

    add_method_id(selector)
  end

  def parse_specification_item(%{"type" => "event"} = item) do
    %{
      "name" => event_name,
      "inputs" => named_inputs
    } = item

    input_types = Enum.map(named_inputs, &parse_specification_type/1)
    input_names = Enum.map(named_inputs, &Map.get(&1, "name"))
    inputs_indexed = Enum.map(named_inputs, &Map.get(&1, "indexed"))

    selector = %ABI.FunctionSelector{
      function: event_name,
      types: input_types,
      input_names: input_names,
      inputs_indexed: inputs_indexed,
      type: :event
    }

    add_method_id(selector)
  end

  def parse_specification_item(%{"type" => "fallback"}) do
    %ABI.FunctionSelector{
      function: nil,
      method_id: nil,
      input_names: [],
      types: [],
      returns: [],
      type: :function
    }
  end

  def parse_specification_item(_), do: nil

  @doc false
  def parse_specification_type(%{"type" => "tuple", "components" => components}) do
    sub_types = for component <- components, do: parse_specification_type(component)
    {:tuple, sub_types}
  end

  def parse_specification_type(%{"type" => "tuple[]", "components" => components}) do
    sub_types = for component <- components, do: parse_specification_type(component)
    {:array, {:tuple, sub_types}}
  end

  def parse_specification_type(%{"type" => type}), do: decode_type(type)

  @doc """
  Decodes the given type-string as a single type.

  ## Examples

      iex> ABI.FunctionSelector.decode_type("uint256")
      {:uint, 256}

      iex> ABI.FunctionSelector.decode_type("(bool,address)")
      {:tuple, [:bool, :address]}

      iex> ABI.FunctionSelector.decode_type("address[][3]")
      {:array, {:array, :address}, 3}
  """
  def decode_type(single_type) do
    ABI.Parser.parse!(single_type, as: :type)
  end

  @doc """
  Encodes the given single type as a type-string.

  ## Examples

      iex> ABI.FunctionSelector.encode_type({:uint, 256})
      "uint256"

      iex> ABI.FunctionSelector.encode_type({:tuple, [:bool, :address]})
      "(bool,address)"

      iex> ABI.FunctionSelector.encode_type({:array, {:array, :address}, 3})
      "address[][3]"

  """
  def encode_type(single_type) do
    get_type(single_type)
  end

  @doc """
  Encodes a function call signature.

  ## Examples

      iex> ABI.FunctionSelector.encode(%ABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [
      ...>     {:uint, 256},
      ...>     :bool,
      ...>     {:array, :string},
      ...>     {:array, :string, 3},
      ...>     {:tuple, [{:uint, 256}, :bool]}
      ...>   ]
      ...> })
      "bark(uint256,bool,string[],string[3],(uint256,bool))"
  """
  def encode(function_selector) do
    types = get_types(function_selector) |> Enum.join(",")

    "#{function_selector.function}(#{types})"
  end

  defp add_method_id(selector) do
    signature = encode(selector)

    case ExKeccak.hash_256(signature) do
      {:ok, <<method_id::binary-size(4), _::binary>>} ->
        %{selector | method_id: method_id}

      _ ->
        selector
    end
  end

  defp get_types(function_selector) do
    for type <- function_selector.types do
      get_type(type)
    end
  end

  defp get_type(nil), do: nil
  defp get_type({:int, size}), do: "int#{size}"
  defp get_type({:uint, size}), do: "uint#{size}"
  defp get_type(:address), do: "address"
  defp get_type(:bool), do: "bool"
  defp get_type({:fixed, element_count, precision}), do: "fixed#{element_count}x#{precision}"
  defp get_type({:ufixed, element_count, precision}), do: "ufixed#{element_count}x#{precision}"
  defp get_type({:bytes, size}), do: "bytes#{size}"
  defp get_type(:function), do: "function"

  defp get_type({:array, type, element_count}), do: "#{get_type(type)}[#{element_count}]"

  defp get_type(:bytes), do: "bytes"
  defp get_type(:string), do: "string"
  defp get_type({:array, type}), do: "#{get_type(type)}[]"

  defp get_type({:tuple, types}) do
    encoded_types = Enum.map(types, &get_type/1)
    "(#{Enum.join(encoded_types, ",")})"
  end

  defp get_type(els), do: raise("Unsupported type: #{inspect(els)}")

  @doc false
  @spec is_dynamic?(ABI.FunctionSelector.type()) :: boolean
  def is_dynamic?(:bytes), do: true
  def is_dynamic?(:string), do: true
  def is_dynamic?({:array, _type}), do: true
  def is_dynamic?({:array, type, len}) when len > 0, do: is_dynamic?(type)
  def is_dynamic?({:tuple, types}), do: Enum.any?(types, &is_dynamic?/1)
  def is_dynamic?(_), do: false

  @doc false
  def from_params(params) when is_map(params) do
    formatted_params =
      params
      |> Map.take(~w(function types returns)a)
      |> Enum.map(&sanitize_param/1)

    struct!(ABI.FunctionSelector, formatted_params)
  end

  defp sanitize_param({key, nil}) when key in ~w(types returns)a do
    {key, []}
  end

  defp sanitize_param(tuple), do: tuple
end
