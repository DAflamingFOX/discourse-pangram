# frozen_string_literal: true

module ::Jobs
  class CheckPangramPost < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.pangram_enabled
      return if SiteSetting.pangram_api_key.blank?

      post_id = args[:post_id]
      force = args[:force] == true

      post = Post.find_by(id: post_id)
      return if post.blank? || post.trashed? || post.user.blank?

      # Check if post has already been scanned for the current version
      current_scanned_version = post.custom_fields["pangram_scanned_version"]&.to_i
      if current_scanned_version == post.version && post.custom_fields["pangram_ai_fraction"].present?
        Rails.logger.info("[Pangram Job] Post #{post.id} was already scanned for version #{post.version}. Re-broadcasting cached results.")
        payload = {
          post_id: post.id,
          ai_fraction: post.custom_fields["pangram_ai_fraction"].to_f,
          ai_assisted_fraction: post.custom_fields["pangram_ai_assisted_fraction"].to_f,
          human_fraction: post.custom_fields["pangram_human_fraction"].to_f,
          confidence: post.custom_fields["pangram_confidence"]&.to_s,
          task_id: post.custom_fields["pangram_task_id"],
          public_dashboard_link: post.custom_fields["pangram_dashboard_link"],
          checked_at: post.custom_fields["pangram_checked_at"],
          scanned_version: post.version,
          cached: true
        }
        ::MessageBus.publish("/pangram/posts/#{post.id}", payload)
        return payload
      end

      # If not forced by staff, ensure mode is automatic and word count meets threshold
      unless force
        return unless SiteSetting.pangram_mode == "automatic"
        return if post.user.bot?

        word_count = ::Pangram::TextCleaner.word_count(post.raw)
        return if word_count < SiteSetting.pangram_min_word_count
      end

      cleaned_text = ::Pangram::TextCleaner.clean(post.raw)
      return if cleaned_text.blank?

      word_count = ::Pangram::TextCleaner.word_count(post.raw)
      Rails.logger.info("[Pangram Job] Processing post #{post.id} v#{post.version} (words: #{word_count}, force: #{force})")

      # Archive previous scan results into history if post was edited
      if post.custom_fields["pangram_ai_fraction"].present?
        history = begin
          JSON.parse(post.custom_fields["pangram_history"].presence || "[]")
        rescue StandardError
          []
        end
        history << {
          version: post.custom_fields["pangram_scanned_version"] || 1,
          ai_fraction: post.custom_fields["pangram_ai_fraction"].to_f,
          ai_assisted_fraction: post.custom_fields["pangram_ai_assisted_fraction"].to_f,
          human_fraction: post.custom_fields["pangram_human_fraction"].to_f,
          confidence: post.custom_fields["pangram_confidence"]&.to_s,
          task_id: post.custom_fields["pangram_task_id"],
          public_dashboard_link: post.custom_fields["pangram_dashboard_link"],
          checked_at: post.custom_fields["pangram_checked_at"]
        }
        post.custom_fields["pangram_history"] = history.to_json
      end

      client = ::Pangram::Client.new
      result = client.analyze(cleaned_text)

      checked_at = Time.zone.now.iso8601

      # Also store the latest scores as direct custom fields for easy querying/serialization
      post.custom_fields["pangram_ai_fraction"] = result[:fraction_ai]
      post.custom_fields["pangram_ai_assisted_fraction"] = result[:fraction_ai_assisted]
      post.custom_fields["pangram_human_fraction"] = result[:fraction_human]
      post.custom_fields["pangram_confidence"] = result[:confidence]
      post.custom_fields["pangram_task_id"] = result[:task_id]
      post.custom_fields["pangram_dashboard_link"] = result[:public_dashboard_link]
      post.custom_fields["pangram_checked_at"] = checked_at
      post.custom_fields["pangram_scanned_version"] = post.version
      post.save_custom_fields(true)

      Rails.logger.info("[Pangram Job] Post #{post.id} updated with custom fields: AI=#{result[:fraction_ai]}")

      # Publish real-time MessageBus notification for the post
      payload = {
        post_id: post.id,
        ai_fraction: result[:fraction_ai],
        ai_assisted_fraction: result[:fraction_ai_assisted],
        human_fraction: result[:fraction_human],
        confidence: result[:confidence],
        task_id: result[:task_id],
        public_dashboard_link: result[:public_dashboard_link],
        checked_at: post.custom_fields["pangram_checked_at"],
        scanned_version: post.version
      }

      # Delay for 1 second to ensure the client has finished rendering the post 
      # and has subscribed to the MessageBus channel.
      sleep 1
      ::MessageBus.publish("/pangram/posts/#{post.id}", payload)

      # Automated review flagging if threshold is exceeded
      auto_flag_threshold = SiteSetting.pangram_auto_flag_threshold.to_i
      if auto_flag_threshold.positive? && (result[:fraction_ai] * 100) >= auto_flag_threshold
        flag_for_review(post, result)
      end

      result
    rescue => e
      Rails.logger.error("Pangram post check failed for post #{args[:post_id]}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      nil
    end

    private

    def flag_for_review(post, result)
      ai_pct = (result[:fraction_ai] * 100).round
      reason = "Pangram AI detection score of #{ai_pct}% exceeded threshold of #{SiteSetting.pangram_auto_flag_threshold}%."

      if defined?(::ReviewablePost)
        reviewable = ::ReviewablePost.needs_review!(
          created_by: ::Discourse.system_user,
          target: post,
          topic: post.topic,
          reviewable_by_moderator: true,
          potential_spam: false
        )
        if reviewable.present? && reviewable.persisted?
          reviewable.add_score(
            ::Discourse.system_user,
            ::ReviewableScore.types[:notify_moderators],
            reason: reason,
            force: true
          )
        end
      end
    rescue => e
      Rails.logger.warn("Pangram: Failed to create reviewable for post #{post.id}: #{e.message}")
    end
  end
end
