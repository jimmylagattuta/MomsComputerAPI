source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.3"

# Databases
gem "sqlite3", ">= 1.4"
gem "pg"

# Web server
gem "puma", ">= 5.0"

# Authentication / Security
gem "bcrypt"
gem "jwt"

# CORS for mobile dev/testing
gem "rack-cors"

# ActiveStorage variants (screenshots / attachments)
gem "image_processing", "~> 1.2"

# Request validation & clean error handling
gem "dry-validation"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ], require: "debug/prelude"

  # Static analysis for security vulnerabilities
  gem "brakeman", require: false

  # Ruby/Rails style guide
  gem "rubocop-rails-omakase", require: false
end
