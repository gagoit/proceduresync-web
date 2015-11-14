/**
* Dashboard module
**/
var Dashboard = {
  /**
  *
  **/
  init: function(){
    this.dashboard_page = $("#dashboard_page");
    this.unread_docs = this.dashboard_page.find(".unread-docs");
    this.to_approve_docs = this.dashboard_page.find(".to-approve-docs");

    this.init_events();
  },

  /**
  *
  **/
  init_events: function(){
    var self = this;

    if(this.dashboard_page.length > 0){

      /** Unread Docs **/
      if(this.unread_docs.length > 0){
        this.load_docs(this.unread_docs);
      }

      /** Unread Docs **/
      if(this.to_approve_docs.length > 0){
        this.load_docs(this.to_approve_docs);
      }

      this.auto_restructure_dashboard();
    }

    /** .dropdown-notifications-li **/
    $("li.dropdown-notifications-li").click(function(e){
      self.load_notifications($("li.dropdown-notifications-li"));
    });

    /**  **/
    $("h4.link-face").click(function(e){
      e.preventDefault();

      var url = $(this).attr("data-url");
      if(typeof url != "undefined"){
        window.location = url;
      }
    });
  },

  /**
  *
  **/
  load_docs: function(div){
    var self = this;
    Proceduresync.show_loading();

    $.ajax(div.attr("data-url"), {
      type: 'GET',
      data: {}
    }).done(function(ev){
      if(ev.docs_html){
        $(ev.docs_html).appendTo(div);

        if(div.find("a.list-group-item").length == 0){
          div.parent().remove();
        }

        self.auto_restructure_dashboard();
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  *
  **/
  load_notifications: function(div){
    if(div.hasClass("open")){
      return;
    }
    Proceduresync.show_loading();

    $.ajax(div.attr("data-url"), {
      type: 'GET',
      data: {}
    }).done(function(ev){
      if(ev.notis_html){
        $(ev.notis_html).appendTo(div);
        div.find("span.badge").remove();

        div.find("a.notification").click(function(e){
          div.removeClass("open");

          return !(this.href.indexOf("dashboard#") > -1);
        })
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  * balance the height of two column: left-column, right-column
  **/
  auto_restructure_dashboard: function(){
    if(this.dashboard_page.length == 0){
      return;
    }
    var self = this;

    var left = $(".left-column");
    var right = $(".right-column");

    if(left.height() - right.height() > 300){
      self.balance_height_of_two_div(left, right);
      
    }else if(right.height() - left.height() > 300){
      self.balance_height_of_two_div(right, left);
    }

    /** Incase no .dashboard-panel **/
    if(self.dashboard_page.find(".dashboard-panel").length == 0){
      left.find(".row:first").unwrap();
    }
  },

  /**
  * Left is higher 
  **/
  balance_height_of_two_div: function(left, right){

    var last_ele = left.find(".col-lg-12:last");

    if(last_ele.length == 0 || (last_ele.height() >= (left.height() - right.height()))){
      return;
    }

    last_ele.remove();

    last_ele.appendTo(right);

    this.auto_restructure_dashboard();
  }
}

$(function() {
  Dashboard.init();
});
