defmodule Mix.Tasks.Phoenix.Gen.Jsonapi do
  use Mix.Task

  @shortdoc "Generates a controller and model for an JSON-based resource"

  @moduledoc """
  Generates a Phoenix resource.

      mix phoenix.gen.json User users name:string age:integer

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The generated resource will contain:

    * a model in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * test files for generated model and controller

  The generated model can be skipped with `--no-model`.
  Read the documentation for `phoenix.gen.model` for more
  information on attributes and namespaced resources.
  """
  def run(args) do
    {opts, parsed, _} = OptionParser.parse(args, switches: [model: :boolean])
    [singular, plural | attrs] = validate_args!(parsed)

    attrs   = Mix.Phoenix.attrs(attrs)
    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route, params: Mix.Phoenix.params(attrs)]

    #Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Controller")
    #Mix.Phoenix.check_module_name_availability!(binding[:module] <> "View")

    if opts[:model] != false do
      Mix.Task.run "phoenix.gen.model", args
    end

    files = [
      {:eex, "controller.ex",       "web/controllers/#{path}_controller.ex"},
      {:eex, "view.ex",             "web/views/#{path}_view.ex"},
      {:eex, "controller_test.exs", "test/controllers/#{path}_controller_test.exs"},
    ]

    unless File.exists?("web/views/changeset_view.ex") do
      files = files ++ [{:eex, "changeset_view.ex", "web/views/changeset_view.ex"}]
    end

    Mix.Phoenix.copy_from source_dir, "", binding, files

    Mix.shell.info """

    Add the resource to your api scope in web/router.ex:

        resources "/#{route}", #{binding[:scoped]}Controller
    """

    if opts[:model] != false do
      Mix.shell.info """
      and then update your repository by running migrations:

          $ mix ecto.migrate
      """
    end
  end

  defp validate_args!([_, plural | _] = args) do
    if String.contains?(plural, ":") do
      raise_with_help
    else
      args
    end
  end

  defp validate_args!(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.json expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.json User users name:string
    """
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/jsonapi")
  end
end
