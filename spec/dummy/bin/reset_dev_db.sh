spring stop
RULES_DISABLED=true RAILS_ENV=development bin/rails db:environment:set
rm -fr db/migrate/*
rake rules_engine:install:migrations
RULES_DISABLED=true RAILS_ENV=development rake db:drop db:create 
RULES_DISABLED=true RAILS_ENV=development rake db:migrate
