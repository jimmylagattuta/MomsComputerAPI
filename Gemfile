source "https://rubygems.org"
# ruby "3.3.9"

gem "rails", "~> 7.2.3"

# DB
gem "pg"

# Web server
gem "puma", ">= 5.0"

gem "bcrypt"
gem "jwt"
gem "rack-cors"
gem "image_processing", "~> 1.2"
gem "dry-validation"

gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]
gem "bootsnap", require: false

group :development, :test do
  gem "sqlite3", ">= 1.4"

  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end
