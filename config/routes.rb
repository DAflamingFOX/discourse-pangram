# frozen_string_literal: true

Pangram::Engine.routes.draw do
  post "/posts/:post_id/scan" => "posts#scan"
end

Discourse::Application.routes.draw { mount ::Pangram::Engine, at: "pangram" }
