defmodule Giza.QueryBuilder do
  @moduledoc """
  Helper for building up the SphinxQLQuery struct
  """

  def query_to_string(%SphinxqlQuery{call: nil} = query) do
    [
      query_to_string_select(query),
      query_to_string_from(query),
      query_to_string_where(query),
      query_to_string_order_by(query),
      query_to_string_limit(query),
      query_to_string_option(query),
      query_to_string_facets(query)
    ]
    |> query_list_to_string(nil)
  end

  def query_to_string(%SphinxqlQuery{call: call}), do: "CALL " <> call

  def query_to_string_select(%SphinxqlQuery{select: nil}), do: nil
  def query_to_string_select(%SphinxqlQuery{select: select}), do: "SELECT #{Enum.join(select, ", ")}" 

  def query_to_string_from(%SphinxqlQuery{from: nil}), do: nil
  def query_to_string_from(%SphinxqlQuery{from: from}), do: "FROM #{from}" 

  def query_to_string_where(%SphinxqlQuery{where: nil}), do: nil
  def query_to_string_where(%SphinxqlQuery{where: where}), do: "WHERE " <> where

  def query_to_string_order_by(%SphinxqlQuery{order_by: nil}), do: nil
  def query_to_string_order_by(%SphinxqlQuery{order_by: order_by}), do: "ORDER BY " <> order_by

  def query_to_string_limit(%SphinxqlQuery{limit: nil, offset: nil}), do: nil
  def query_to_string_limit(%SphinxqlQuery{limit: limit, offset: offset}),
    do: "LIMIT #{offset}, #{limit}"

  def query_to_string_option(%SphinxqlQuery{option: nil}), do: nil
  def query_to_string_option(%SphinxqlQuery{option: option}), do: "OPTION " <> option

  def query_to_string_facets(%SphinxqlQuery{facets: []}), do: nil
  def query_to_string_facets(%SphinxqlQuery{facets: facets}), do: Enum.join(facets, " ")

  def query_list_to_string([part | tail], acc) do
    cond do
      acc == nil -> query_list_to_string(tail, part)
      part == nil -> query_list_to_string(tail, acc)
      true -> query_list_to_string(tail, "#{acc} #{part}")
    end
  end

  def query_list_to_string([], acc), do: acc
end
