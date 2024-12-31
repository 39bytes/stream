class PostsController < ApplicationController
  allow_unauthenticated_access only: %i[index]
  before_action :require_admin
  skip_before_action :require_admin, only: %i[index]

  def index
    @posts = Post.order(created_at: :desc)
    render json: @posts
  end

  def create
    @post = Post.new(post_params)
    if @post.save
      render json: @post, status: :created
    else
      render json: @post.errors, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      render json: @post
    else
      render json: @post.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.destroy
    render json: @post
  end

  def post_params
    params.expect(post: [:content])
  end
end
