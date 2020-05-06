App.business_rules = App.cable.subscriptions.create("Rules::BusinessRulesChannel", {
  connected: function() {
    console.log("business_rules ActionCable connected");
  },

  disconnected: function() {
    console.log("business_rules ActionCable disconnected");    
  },

  received: function(data) {
    console.log("business_rules actioncable received:");
    console.log(data);
//     if (data.event == 'collected') {
// 
//     }
  }
});
