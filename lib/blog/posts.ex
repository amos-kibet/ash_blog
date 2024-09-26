defmodule Blog.Posts do
  use Ash.Domain

  alias Blog.Posts.Post

  resources do
    resource Post
  end
end
