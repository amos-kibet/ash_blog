defmodule Blog.Notifiers do
  use Ash.Notifier

  def notify(%{action: %{type: :create}, data: post}) do
    Phoenix.PubSub.broadcast(Blog.PubSub, "post_creation", {:post_created, post})
  end
end
