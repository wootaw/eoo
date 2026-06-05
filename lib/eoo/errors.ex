defmodule Eoo.Error do
  defexception [:message]
  @type t :: %__MODULE__{message: String.t()}
end

defmodule Eoo.HeaderRowNotFoundError do
  defexception [:message]
  @type t :: %__MODULE__{message: String.t()}
end

defmodule Eoo.FileNotFound do
  defexception [:message]
  @type t :: %__MODULE__{message: String.t()}
end

defmodule Eoo.ExceedsMaxError do
  defexception [:message]
  @type t :: %__MODULE__{message: String.t()}
end
