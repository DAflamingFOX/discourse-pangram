# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ::Pangram
  class Client
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class TaskFailedError < Error; end
    class TimeoutError < Error; end

    attr_reader :api_key, :base_url, :model

    def initialize(
      api_key: SiteSetting.pangram_api_key,
      base_url: SiteSetting.pangram_api_url,
      model: SiteSetting.pangram_model
    )
      @api_key = api_key
      @base_url = (base_url.presence || "https://text.external-api.pangram.com").chomp("/")
      @model = model.presence || "pangram-3"
    end

    def analyze(text)
      Rails.logger.info("[Pangram API] Starting analysis for text (#{text.length} characters)")
      task_id = submit_task(text)
      poll_task(task_id)
    end

    def submit_task(text)
      raise AuthenticationError, "Pangram API key is not configured" if api_key.blank?

      uri = URI("#{base_url}/task")
      payload = { text: text }
      payload[:model] = model if model.present? && model != "default"

      Rails.logger.info("[Pangram API] Submitting task to POST #{uri} with payload: #{payload.inspect}")

      response = request(Net::HTTP::Post, uri, payload)
      data = parse_json(response.body)

      task_id = data["task_id"] || data["id"]
      raise Error, "No task_id returned from Pangram API: #{response.body}" if task_id.blank?

      Rails.logger.info("[Pangram API] Task created successfully. Task ID: #{task_id}")
      task_id
    end

    def get_task_status(task_id)
      raise AuthenticationError, "Pangram API key is not configured" if api_key.blank?

      uri = URI("#{base_url}/task/#{task_id}")
      response = request(Net::HTTP::Get, uri)
      parse_json(response.body)
    end

    def poll_task(task_id, max_attempts: 20, base_sleep: 1.0)
      attempts = 0

      while attempts < max_attempts
        attempts += 1
        data = get_task_status(task_id)
        stage = (data["stage"] || data["status"] || data["state"] || "").to_s.upcase

        Rails.logger.info("[Pangram API] Polling task #{task_id} (Attempt #{attempts}/#{max_attempts}) - Stage: #{stage}, Response: #{data.inspect}")

        if %w[STAGE_SUCCESS SUCCESS COMPLETED DONE].include?(stage) || data["fraction_ai"].present? || data.dig("result", "fraction_ai").present?
          result = format_result(task_id, data)
          Rails.logger.info("[Pangram API] Task #{task_id} completed: AI=#{(result[:fraction_ai] * 100).round(2)}%, AI-Assisted=#{(result[:fraction_ai_assisted] * 100).round(2)}%, Human=#{(result[:fraction_human] * 100).round(2)}%")
          return result
        elsif %w[STAGE_FAILED FAILED STAGE_ERROR ERROR].include?(stage)
          Rails.logger.error("[Pangram API] Task #{task_id} failed with response: #{data.inspect}")
          raise TaskFailedError, "Pangram task failed: #{data['error'] || data['message'] || stage}"
        else
          # Still processing (e.g. STAGE_QUEUED, STAGE_RUNNING, QUEUED, RUNNING)
          sleep(base_sleep)
        end
      end

      Rails.logger.error("[Pangram API] Task #{task_id} timed out after #{max_attempts} attempts")
      raise TimeoutError, "Pangram task #{task_id} timed out after #{max_attempts} attempts"
    end

    private

    def format_result(task_id, data)
      fraction_ai = (data["fraction_ai"] || data.dig("result", "fraction_ai") || 0.0).to_f
      fraction_ai_assisted = (data["fraction_ai_assisted"] || data.dig("result", "fraction_ai_assisted") || 0.0).to_f
      fraction_human = (data["fraction_human"] || data.dig("result", "fraction_human") || 0.0).to_f

      {
        task_id: task_id,
        fraction_ai: fraction_ai.round(4),
        fraction_ai_assisted: fraction_ai_assisted.round(4),
        fraction_human: fraction_human.round(4),
        headline: data["headline"] || data.dig("result", "headline"),
        windows: data["windows"] || data.dig("result", "windows") || [],
        raw: data
      }
    end

    def request(klass, uri, body_hash = nil)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 15

      req = klass.new(uri.request_uri)
      req["Content-Type"] = "application/json"
      req["x-api-key"] = api_key

      if body_hash
        req.body = body_hash.to_json
      end

      response = http.request(req)
      Rails.logger.info("[Pangram API] Response #{req.method} #{uri.path} -> HTTP #{response.code} (body length: #{response.body&.length || 0})")

      case response.code.to_i
      when 200..299
        response
      when 401, 403
        Rails.logger.error("[Pangram API] Auth error HTTP #{response.code}: #{response.body}")
        raise AuthenticationError, "Pangram API authentication failed (HTTP #{response.code}): #{response.body}"
      else
        Rails.logger.error("[Pangram API] Error HTTP #{response.code}: #{response.body}")
        raise Error, "Pangram API error (HTTP #{response.code}): #{response.body}"
      end
    end

    def parse_json(str)
      JSON.parse(str)
    rescue JSON::ParserError => e
      Rails.logger.error("[Pangram API] JSON parse error: #{e.message} for body: #{str}")
      raise Error, "Failed to parse Pangram API response: #{e.message}"
    end
  end
end
