# frozen_string_literal: true

module ::Pangram
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Pangram
    config.autoload_paths << File.join(config.root, "lib")
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    regular_job_dir = "#{config.root}/app/jobs/regular"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
      Rails.autoloaders.main.eager_load_dir(regular_job_dir) if Dir.exist?(regular_job_dir)
    end
  end
end
