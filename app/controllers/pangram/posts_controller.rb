# frozen_string_literal: true

module ::Pangram
  class PostsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_staff

    def scan
      post = Post.find_by(id: params[:post_id])
      raise Discourse::NotFound if post.blank?

      unless SiteSetting.pangram_enabled
        return render json: { failed: "FAILED", message: "Pangram plugin is disabled" }, status: :bad_request
      end

      if SiteSetting.pangram_api_key.blank?
        return render json: { failed: "FAILED", message: "Pangram API key is not configured" }, status: :bad_request
      end

      current_scanned_version = post.custom_fields["pangram_scanned_version"]&.to_i
      if current_scanned_version == post.version && post.custom_fields["pangram_ai_fraction"].present?
        payload = {
          post_id: post.id,
          ai_fraction: post.custom_fields["pangram_ai_fraction"].to_f,
          ai_assisted_fraction: post.custom_fields["pangram_ai_assisted_fraction"].to_f,
          human_fraction: post.custom_fields["pangram_human_fraction"].to_f,
          checked_at: post.custom_fields["pangram_checked_at"],
          scanned_version: post.version,
          cached: true
        }
        ::MessageBus.publish("/pangram/posts/#{post.id}", payload)

        return render json: payload.merge(success: true, message: "already_scanned")
      end

      # Execute scan directly for immediate feedback and logging
      result = ::Jobs::CheckPangramPost.new.execute(post_id: post.id, force: true)

      if result
        post.reload
        render json: {
          success: true,
          post_id: post.id,
          ai_fraction: result[:fraction_ai] || post.custom_fields["pangram_ai_fraction"]&.to_f,
          ai_assisted_fraction: result[:fraction_ai_assisted] || post.custom_fields["pangram_ai_assisted_fraction"]&.to_f,
          human_fraction: result[:fraction_human] || post.custom_fields["pangram_human_fraction"]&.to_f,
          checked_at: post.custom_fields["pangram_checked_at"],
          scanned_version: post.version
        }
      else
        render json: { failed: "FAILED", message: "Scan could not be completed" }, status: :unprocessable_entity
      end
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end
  end
end
