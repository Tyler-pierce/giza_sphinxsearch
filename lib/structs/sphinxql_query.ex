defmodule Giza.Structs.SphinxqlQuery do
  defstruct raw: nil, select: ["*"], from: nil, where: nil, limit: 20, offset: 0, call: nil, option: nil
end