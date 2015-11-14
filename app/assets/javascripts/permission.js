/**
* Permission module
* permission-table
**/
var Permission = {
  /**
  *
  **/
  init: function(){
    this.permissions_page = $("#permissions_page");
    this.permission_table = this.permissions_page.find(".permission-table");
    this.permissions_url = this.permissions_page.attr("data-permissions-url");
    this.update_batch_url = this.permissions_page.attr("data-update-batch-url");

    this.init_events();
  },

  /**
  * 
  **/
  init_events: function(){
    var self = this;

    /** Permissions Page **/
    if(self.permissions_page.length > 0){
      self.permissions_page.find("#create_user_type").click(function(e){
      	var name = self.permissions_page.find("input#user_type").val();

      	self.create_new_user_type(name);
      });

      self.permissions_page.find("#update_permissions").click(function(e){
      	self.update_all_permissions();
      });
    }
      
  },

  /**
  * 
  **/
  create_new_user_type: function(name){
  	name = name.trim();
    if(name.length == 0){
      return ;
    }

    var self = this;

    Proceduresync.show_loading();

    $.ajax(self.permissions_url, {
      type: 'POST',
      data: {
        permission: {name: name}
      }
    }).done(function(ev){
      if(ev.success == true){
      	var tr_new_user_type = self.permission_table.find("tr.new-user-type");

        $(ev.tr_new_html).insertBefore(tr_new_user_type);

        self.permissions_page.find("input#user_type").val("");

        Icheck.init_icheck(tr_new_user_type.prev());

        AlertMessage.show("success", ev.message);
      }else{
        if( ev.window_reload == true){
          alert(ev.message);
          window.location.reload();
        }else{
          AlertMessage.show("danger", ev.message);
        }
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  * 
  **/
  update_all_permissions: function(){
    var self = this;
    var all_permissions = self.get_all_permissions();

    Proceduresync.show_loading();

    $.ajax(self.update_batch_url, {
      type: 'PUT',
      data: {
        permissions: all_permissions
      }
    }).done(function(ev){
      if(ev.success == true){
      	//show alert success
        AlertMessage.show("success", ev.message);
      }else{
        if( ev.window_reload == true){
          alert(ev.message);
          window.location.reload();
        }else{
          AlertMessage.show("danger", ev.message);
        }
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  **/
  get_all_permissions: function(){
  	var self = this;

  	var data = [];
  	var trs = self.permission_table.find("tr.user-type");

  	trs.each(function(){
  		var tr = $(this);
  		var tr_hash = {};

  		tr_hash["id"] = tr.attr("data-uid");

  		tr.find("td").each(function(){
  			var input = $(this).find("input");
  			tr_hash[$(this).attr("data-key")] = input.is(":checked");
  		});
  		
  		data.push(tr_hash);
  	});

  	return data;
  }
}


$(function() {
  Permission.init();
});