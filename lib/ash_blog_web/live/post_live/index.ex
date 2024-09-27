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
     |> assign(:page_title, "AshBlog Posts")
     |> assign(:load_more_token, nil)
     |> assign(:form, form)
     |> assign(:new_posts_count, 0)
     |> assign(:new_posts, [])
     |> stream(:posts, [])}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    list_posts(socket)
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
     |> stream(:posts, socket.assigns.new_posts, at: 0)
     |> push_event("scroll-to-top", %{})}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, post} ->
        form =
          Post
          |> AshPhoenix.Form.for_create(:create)
          |> to_form()

        JS.hide(to: "#modal")

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:info, "Post created successfully")
         |> stream_insert(:posts, post, at: 0)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp list_posts(%{assigns: %{load_more_token: nil}} = socket) do
    case Posts.read(Post, action: :list, page: [limit: 10]) do
      {:ok, %{results: posts}} ->
        load_more_token = List.last(posts) && List.last(posts).__metadata__.keyset

        socket
        |> assign(:load_more_token, load_more_token)
        |> stream(:posts, posts, reset: socket.assigns.load_more_token == nil)

      {:error, error} ->
        put_flash(socket, :error, "Error loading posts: #{inspect(error)}")
    end
  end

  defp list_posts(%{assigns: %{load_more_token: load_more_token}} = socket) do
    case Posts.read(Post, action: :list, page: [after: load_more_token, limit: 10]) do
      {:ok, %{results: posts}} ->
        load_more_token = List.last(posts) && List.last(posts).__metadata__.keyset

        socket
        |> assign(:load_more_token, load_more_token)
        |> stream(:posts, posts, at: -1, reset: socket.assigns.load_more_token == nil)

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
