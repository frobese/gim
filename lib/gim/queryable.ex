alias Gim.Query

defprotocol Gim.Queryable do
  @moduledoc false
  def to_query(data)
end

defimpl Gim.Queryable, for: Atom do
  def to_query(module) do
    try do
      module.__schema__(:gim)

      %Query{type: module}
    rescue
      UndefinedFunctionError ->
        message =
          if :code.is_loaded(module) do
            "the given module does not provide a gim schema"
          else
            "the given module does not exist"
          end

        raise Protocol.UndefinedError, protocol: @protocol, value: module, description: message

      FunctionClauseError ->
        raise Protocol.UndefinedError,
          protocol: @protocol,
          value: module,
          description: "the given module does not provide a gim schema"
    end
  end
end
