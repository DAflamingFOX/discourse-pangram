# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Jobs::CheckPangramPost do
  fab!(:post) do
    Fabricate(:post, raw: "This is a test post that has enough text to be scanned. " * 15)
  end

  before do
    SiteSetting.pangram_enabled = true
    SiteSetting.pangram_api_key = "test-key"
    SiteSetting.pangram_mode = "manual"
  end

  it "skips execution if mode is manual and force is false" do
    expect_any_instance_of(::Pangram::Client).not_to receive(:analyze)
    described_class.new.execute(post_id: post.id, force: false)
  end

  it "runs analysis when force is true, saving custom fields and publishing to MessageBus" do
    mock_result = {
      task_id: "test-task-123",
      fraction_ai: 0.92,
      fraction_ai_assisted: 0.05,
      fraction_human: 0.03,
      headline: "AI Generated",
    }

    expect_any_instance_of(::Pangram::Client).to receive(:analyze).and_return(mock_result)

    messages =
      MessageBus.track_publish("/pangram/posts/#{post.id}") do
        described_class.new.execute(post_id: post.id, force: true)
      end

    post.reload
    expect(post.custom_fields["pangram_ai_fraction"]).to eq("0.92").or eq(0.92)
    expect(post.custom_fields["pangram_task_id"]).to eq("test-task-123")
    expect(messages.length).to eq(1)
    expect(messages.first.data[:ai_fraction]).to eq(0.92)
  end
end
