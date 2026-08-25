# frozen_string_literal: true

# name: pangram
# about: A plugin to feed messages through the Pangram API to check for AI content.
# version: 0.0.1
# authors: Jeffrey Morris
# url: https://github.com/daflamingfox/pangram-plugin
# required_version: 2.7.0

enabled_site_setting :pangram_enabled

module ::Pangram
  PLUGIN_NAME = "pangram"
end

require_relative "lib/pangram/engine"

register_asset "stylesheets/pangram.scss"

after_initialize do
  register_post_custom_field_type("pangram_ai_fraction", :float)
  register_post_custom_field_type("pangram_ai_assisted_fraction", :float)
  register_post_custom_field_type("pangram_human_fraction", :float)
  register_post_custom_field_type("pangram_confidence", :string)
  register_post_custom_field_type("pangram_task_id", :string)
  register_post_custom_field_type("pangram_dashboard_link", :string)
  register_post_custom_field_type("pangram_checked_at", :string)
  register_post_custom_field_type("pangram_scanned_version", :integer)
  register_post_custom_field_type("pangram_history", :json)

  TopicView.on_preload do |topic_view|
    next if topic_view.posts.blank?

    Post.preload_custom_fields(
      topic_view.posts,
      %w[
        pangram_ai_fraction
        pangram_ai_assisted_fraction
        pangram_human_fraction
        pangram_confidence
        pangram_task_id
        pangram_dashboard_link
        pangram_checked_at
        pangram_scanned_version
        pangram_history
      ],
    )
  end

  include_pangram_condition = -> do
    return false unless SiteSetting.pangram_enabled
    return false if object.custom_fields["pangram_ai_fraction"].blank?

    return true if scope.is_staff?

    min_tl = SiteSetting.pangram_min_trust_level_to_view
    return true if min_tl == 0

    user = scope.current_user
    user.present? && user.has_trust_level?(min_tl)
  end

  {
    pangram_ai_fraction: :to_f,
    pangram_ai_assisted_fraction: :to_f,
    pangram_human_fraction: :to_f,
    pangram_confidence: :to_s,
    pangram_task_id: nil,
    pangram_dashboard_link: :to_s,
    pangram_checked_at: nil,
    pangram_scanned_version: :to_i,
  }.each do |field, cast_method|
    add_to_serializer(:post, field, include_condition: include_pangram_condition) do
      value = object.custom_fields[field.to_s]
      cast_method ? value&.public_send(cast_method) : value
    end
  end

  add_to_serializer(
    :post,
    :pangram_history,
    include_condition: -> do
      SiteSetting.pangram_enabled && scope.is_staff? &&
        object.custom_fields["pangram_history"].present?
    end,
  ) do
    begin
      JSON.parse(object.custom_fields["pangram_history"])
    rescue StandardError
      []
    end
  end

  on(:post_created) do |post, _opts, _user|
    if SiteSetting.pangram_enabled && SiteSetting.pangram_mode == "automatic"
      ::Jobs.enqueue(:check_pangram_post, post_id: post.id)
    end
  end

  on(:post_edited) do |post, _topic_changed, _editor|
    if SiteSetting.pangram_enabled && SiteSetting.pangram_mode == "automatic"
      ::Jobs.enqueue(:check_pangram_post, post_id: post.id)
    end
  end
end
