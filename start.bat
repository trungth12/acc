set RACK_ENV=production
bundle exec puma config.ru -b tcp://0.0.0.0:3004 -t 4:32 RACK_ENV=%RACK_ENV%