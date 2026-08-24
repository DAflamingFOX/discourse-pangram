# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Pangram::PostsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post) }

  before do
    SiteSetting.pangram_enabled = true
    SiteSetting.pangram_api_key = "test-api-key"
  end

  describe "POST /pangram/posts/:post_id/scan" do
    it "rejects anonymous and regular users" do
      post "/pangram/posts/#{post.id}/scan.json"
      expect(response.status).to eq(403).or eq(404)

      sign_in(user)
      post "/pangram/posts/#{post.id}/scan.json"
      expect(response.status).to eq(403)
    end

    it "enqueues check job when requested by staff" do
      sign_in(admin)

      expect {
        post "/pangram/posts/#{post.id}/scan.json"
      }.to change { ::Jobs::CheckPangramPost.jobs.size }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
    end
  end
end
