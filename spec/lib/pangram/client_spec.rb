# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Pangram::Client do
  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#submit_task" do
    it "raises AuthenticationError if api_key is missing" do
      unauthed = described_class.new(api_key: "")
      expect { unauthed.submit_task("some text") }.to raise_error(::Pangram::Client::AuthenticationError)
    end

    it "posts to /task and returns task_id" do
      stub_request(:post, "https://text.external-api.pangram.com/task")
        .with(
          headers: { "x-api-key" => "test-api-key", "Content-Type" => "application/json" },
          body: { text: "Check this message", model: "pangram-3" }.to_json
        )
        .to_return(status: 200, body: { task_id: "task-123" }.to_json)

      task_id = client.submit_task("Check this message")
      expect(task_id).to eq("task-123")
    end
  end

  describe "#poll_task" do
    it "polls until STAGE_SUCCESS and parses results" do
      stub_request(:get, "https://text.external-api.pangram.com/task/task-123")
        .to_return(
          status: 200,
          body: {
            stage: "STAGE_SUCCESS",
            fraction_ai: 0.885,
            fraction_ai_assisted: 0.05,
            fraction_human: 0.065,
            headline: "Likely AI"
          }.to_json
        )

      result = client.poll_task("task-123", max_attempts: 1, base_sleep: 0)
      expect(result[:fraction_ai]).to eq(0.885)
      expect(result[:fraction_ai_assisted]).to eq(0.05)
      expect(result[:fraction_human]).to eq(0.065)
      expect(result[:headline]).to eq("Likely AI")
    end
  end
end
