defmodule ABI.Util do
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
end
