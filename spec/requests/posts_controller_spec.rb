# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Pangram::PostsController do
  fab!(:admin)
  fab!(:user)
  fab!(:target_post, :post)

  before do
    SiteSetting.pangram_enabled = true
    SiteSetting.pangram_api_key = "test-api-key"
  end

  describe "POST /pangram/posts/:post_id/scan" do
    it "rejects anonymous and regular users" do
      post "/pangram/posts/#{target_post.id}/scan.json"
      expect(response.status).to eq(403).or eq(404)

      sign_in(user)
      post "/pangram/posts/#{target_post.id}/scan.json"
      expect(response.status).to eq(403)
    end

    it "executes check job directly when requested by staff" do
      sign_in(admin)

      ::Jobs::CheckPangramPost
        .any_instance
        .expects(:execute)
        .with(post_id: target_post.id, force: true)
        .returns({ fraction_ai: 0.88 })

      post "/pangram/posts/#{target_post.id}/scan.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["ai_fraction"]).to eq(0.88)
    end
  end
end
