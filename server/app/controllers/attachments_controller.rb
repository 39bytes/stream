class AttachmentsController < ApplicationController
  def create
    attachment = Attachment.create!(attachment: params["attachment"])
    puts request.url
    render json: {url: url_for(attachment.attachment)}
  end
end
