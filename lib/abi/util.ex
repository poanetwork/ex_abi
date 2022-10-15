defmodule ABI.Util do
  @moduledoc false

  def split_method_id(<<method_id::binary-size(4), rest::binary>>) do
    {:ok, method_id, rest}
  end

  def split_method_id(_) do
    {:error, :invalid_data}
  end

  def find_selector_by_method_id(function_selectors, method_id_target) do
    function_selector =
      Enum.find(function_selectors, fn %{method_id: method_id} ->
        method_id == method_id_target
      end)

    if function_selector do
      {:ok, function_selector}
    else
      {:error, :no_matching_function}
    end
  end

  def find_selector_by_event_id(function_selectors, method_id_target, input_topics) do
    # Only process function selectors that are of type event
    function_selector =
      Enum.find(function_selectors, fn
        %{type: :event, method_id: ^method_id_target, inputs_indexed: inputs_indexed} ->
          # match the length of topics and indexed_args_length
          topics_length = Enum.count(input_topics, fn x -> x != nil end)
          indexed_length = Enum.count(inputs_indexed, &(&1 == true))
          topics_length == indexed_length

        _ ->
          false
      end)

    if function_selector do
      {:ok, function_selector}
    else
      {:error, :no_matching_function}
    end
  end
end
