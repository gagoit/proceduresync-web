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
    this.staff_with_outstanding_documents = this.dashboard_page.find("#staff_with_outstanding_documents");

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
        this.load_docs(this.unread_docs, 1);
      }

      /** Unread Docs **/
      if(this.to_approve_docs.length > 0){
        this.load_docs(this.to_approve_docs, 1);
      }

      /** staff_with_outstanding_documents **/
      if(this.staff_with_outstanding_documents.length > 0){
        self.scrollLoadContentInit(self.staff_with_outstanding_documents);

        setTimeout(function(){
          self.load_docs(self.staff_with_outstanding_documents, 1);
        }, 1000);
      }

      this.auto_restructure_dashboard();

      // $(window).resize(function() {
      //   self.auto_restructure_dashboard();
      // }).resize();
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

    $(window.document).delegate(".load-more-user-unread-docs", "click touchend", function(e){
      var link = $(this);
      var user_name = link.attr("data-name");
      var modal = $('#show_unread_docs_modal #confirm_modal');

      function show_unread_docs(unread_docs){
        var html = "<ul style='max-height: 350px; overflow: auto; list-style-type: none; padding-left: 0;'>";

        $.each(unread_docs, function( index, title ) {
          html += "<li>" + title + "</li>";
        });

        html += "</ul>";
        
        modal.find(".modal-header h3").text(user_name + " Outstanding Documents");
        modal.find(".panel-body.panel-e").html(html);

        modal.modal('show');
      }

      if(link.data("unread_docs")){
        show_unread_docs(link.data("unread_docs"));
      }else{
        Proceduresync.show_loading();

        $.ajax(link.attr("data-url"), {
          type: 'GET',
          data: {
            get_array: true
          }
        }).done(function(ev){
          if(ev.success == true){
            link.data("unread_docs", ev.unread_docs);

            show_unread_docs(ev.unread_docs);
          }else{
            AlertMessage.show("danger", ev.message);
          }
          Proceduresync.hide_loading();
        });
      }

      return false;
    });
  },

  /**
  *
  **/
  load_docs: function(div, currentPage){
    var self = this;
    Proceduresync.show_loading();

    var data = {};
    if(currentPage){
      data.page = currentPage;
    }

    $.ajax(div.attr("data-url"), {
      type: 'GET',
      data: data
    }).done(function(ev){
      if(ev.docs_html){
        $(ev.docs_html).appendTo(div);

        if(div.find("a.list-group-item").length == 0){
          div.parent().remove();
        }

        if(currentPage == 1){
          self.auto_restructure_dashboard();
        }
      }else{
        div.closest(".table-responsive").find(".loading-wrapper").remove();
        if(ev.message){
          AlertMessage.show("danger", ev.message);
        }
      }

      if(div.data("scrollLoadEnable") == "true"){
        div.data("scrollLoading", "false");
        div.data("currentPage", currentPage);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  * Scroll to load content in div
  **/
  scrollLoadContentInit: function(div) {
    var self = this;
    var scrollLoading = div.data("scrollLoading") || "false";
    var currentPage = parseInt(div.data("currentPage"), 10) || 1;
    var parent = $(div).closest(".table-responsive");

    $(parent).scroll(function() {
      if(scrollLoading == "false" && ($(parent).scrollTop() + $(parent).innerHeight()  >  this.scrollHeight - 20) ) {
        // ajax call get data from server and append to the div
        currentPage += 1;
        self.load_docs(div, currentPage);
      }
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
    if(this.dashboard_page.length == 0 || $(window).width() < 1200){
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
