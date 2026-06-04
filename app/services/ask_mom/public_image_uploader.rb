# app/services/ask_mom/public_image_uploader.rb
# frozen_string_literal: true

module AskMom
  class PublicImageUploader
    def self.call(images:)
      new(images: images).call
    end

    def initialize(images:)
      @images = Array(images).compact
    end

    def call
      @images.map do |img|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: image_io(img),
          filename: safe_filename(img),
          content_type: safe_content_type(img)
        )

        blob.url(
          expires_in: 10.minutes,
          disposition: "inline",
          filename: blob.filename
        )
      end
    end

    private

    def image_io(img)
      if img.respond_to?(:tempfile) && img.tempfile
        img.tempfile
      else
        img
      end
    end

    def safe_filename(img)
      original =
        if img.respond_to?(:original_filename)
          img.original_filename.to_s
        else
          "public-ask-mom-image.jpg"
        end

      original = File.basename(original)
      original = "public-ask-mom-image.jpg" if original.blank?

      original
    end

    def safe_content_type(img)
      if img.respond_to?(:content_type)
        img.content_type.to_s
      else
        "image/jpeg"
      end
    end
  end
end