defmodule JSONAPI.Config do
  @moduledoc """
  Configuration struct containing JSON API information for a request

  Much of the data in this struct is populated for you by various Plugs this
  library offers if you choose to use them.

  `includes_post_processor`, if nil, will default to running all includes
  through `Enum.uniq/1`. You can customize this behavior if needed with a
  function that accepts two arguments: The includes about to be seriailzed and
  the requested includes for the current request. Your function must return the
  includes as you want them to be serialized.
  """

  defstruct data: nil,
            fields: %{},
            filter: [],
            include: [],
            includes_post_processor: nil,
            opts: nil,
            sort: nil,
            view: nil,
            page: %{}

  @type requested_include :: atom | {atom, any}

  @type t :: %__MODULE__{
          data: nil | map,
          fields: map,
          filter: keyword,
          include: [requested_include],
          includes_post_processor: nil | (keyword(), [requested_include] -> keyword()),
          opts: nil | keyword,
          sort: nil | keyword,
          view: any,
          page: nil | map
        }
end
