App.business_rules_activity = App.cable.subscriptions.create("Rules::BusinessRulesActivityChannel", {
  connected: function() {
    console.log("business_rules_activity ActionCable connected");
  },

  disconnected: function() {
    console.log("business_rules_activity ActionCable disconnected");    
  },

  received: function(data) {
    console.log("business_rules_activity received:");
    console.log(data);
    // rules_data needs to be defined by whomever subscribes (dashboard.html.haml)
    rules_data(data);
  }
});