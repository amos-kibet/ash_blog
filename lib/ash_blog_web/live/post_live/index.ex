defmodule AshBlogWeb.PostLive.Index do
  use AshBlogWeb, :live_view

  alias AshBlog.Posts
  alias AshBlog.Posts.Post

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(AshBlog.PubSub, "post_creation")

    form =
      Post
      |> AshPhoenix.Form.for_create(:create)
      |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:load_more_token, nil)
     |> assign(:new_posts_count, 0)
     |> assign(:new_posts, [])
     |> assign(:page_title, "AshBlog Posts")
     |> stream(:posts, [])}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, list_posts(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("load-more", _params, socket) do
    {:noreply, list_posts(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("show-new-posts", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_posts_count, 0)
     |> assign(:new_posts, [])
     |> push_event("scroll-to-top", %{})
     |> stream(:posts, socket.assigns.new_posts, at: 0)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _post} ->
        form =
          Post
          |> AshPhoenix.Form.for_create(:create)
          |> to_form()

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:info, "Post created successfully")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp list_posts(%{assigns: %{load_more_token: nil}} = socket) do
    do_list_posts(socket, page: [limit: 10])
  end

  defp list_posts(%{assigns: %{load_more_token: load_more_token}} = socket) do
    do_list_posts(socket, page: [after: load_more_token, limit: 10])
  end

  defp do_list_posts(socket, opts) do
    case Posts.read(Post, action: :list, page: opts[:page]) do
      {:ok, %{results: posts}} ->
        load_more_token = List.last(posts) && List.last(posts).__metadata__.keyset

        stream_opts =
          [
            reset: socket.assigns.load_more_token == nil,
            at: if(opts[:page][:after], do: -1, else: nil)
          ]
          |> Enum.reject(fn {_, v} -> is_nil(v) end)

        socket
        |> assign(:load_more_token, load_more_token)
        |> stream(:posts, posts, stream_opts)

      {:error, error} ->
        put_flash(socket, :error, "Error loading posts: #{inspect(error)}")
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:post_created, post}, socket) do
    new_posts_count = socket.assigns.new_posts_count + 1
    new_posts = [post | socket.assigns.new_posts]

    {:noreply,
     socket
     |> assign(:new_posts_count, new_posts_count)
     |> assign(:new_posts, new_posts)}
  end
end
