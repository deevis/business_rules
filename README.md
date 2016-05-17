* BPR - Business Process Rules 

This project rocks and uses MIT-LICENSE.


Gemfile
--------------------------------------------------------------
gem 'business_rules', github: "deevis/business_rules", branch: "master"
gem 'mongoid-versioning', github: 'ream88/mongoid-versioning'



application.js
--------------------------------------------------------------
//= require jquery.fancytree



mongoid.yml
--------------------------------------------------------------



```bundle install```

```rake business_rules:install:migrations```

```rake db:migrate```

```rails server```
