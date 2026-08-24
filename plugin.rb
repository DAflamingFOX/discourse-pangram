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

after_initialize do
  register_post_custom_field_type("pangram_ai_fraction", :float)
  register_post_custom_field_type("pangram_ai_assisted_fraction", :float)
  register_post_custom_field_type("pangram_human_fraction", :float)
  register_post_custom_field_type("pangram_task_id", :string)
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
        pangram_checked_at
        pangram_scanned_version
        pangram_history
      ]
    )
  end

  include_pangram_condition = -> {
    SiteSetting.pangram_enabled &&
      (scope.is_staff? || SiteSetting.pangram_visibility == "everyone") &&
      object.custom_fields["pangram_ai_fraction"].present?
  }

  add_to_serializer(
    :post,
    :pangram_ai_fraction,
    include_condition: include_pangram_condition
  ) { object.custom_fields["pangram_ai_fraction"]&.to_f }

  add_to_serializer(
    :post,
    :pangram_ai_assisted_fraction,
    include_condition: include_pangram_condition
  ) { object.custom_fields["pangram_ai_assisted_fraction"]&.to_f }

  add_to_serializer(
    :post,
    :pangram_human_fraction,
    include_condition: include_pangram_condition
  ) { object.custom_fields["pangram_human_fraction"]&.to_f }

  add_to_serializer(
    :post,
    :pangram_checked_at,
    include_condition: include_pangram_condition
  ) { object.custom_fields["pangram_checked_at"] }

  add_to_serializer(
    :post,
    :pangram_scanned_version,
    include_condition: include_pangram_condition
  ) { object.custom_fields["pangram_scanned_version"]&.to_i }

  add_to_serializer(
    :post,
    :pangram_history,
    include_condition: -> {
      SiteSetting.pangram_enabled && scope.is_staff? && object.custom_fields["pangram_history"].present?
    }
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
