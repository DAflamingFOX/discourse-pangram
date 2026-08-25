# frozen_string_literal: true

Pangram::Engine.routes.draw { post "/posts/:post_id/scan" => "posts#scan" }

Discourse::Application.routes.draw { mount ::Pangram::Engine, at: "pangram" }
