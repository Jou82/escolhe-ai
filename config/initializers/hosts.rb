# Development convenience only. Production hosts are set exclusively in
# config/environments/production.rb (no catch-all /.*/).
if Rails.env.local?
  Rails.application.config.hosts << "localhost"
  Rails.application.config.hosts << "127.0.0.1"
end
