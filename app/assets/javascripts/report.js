/**
* Report module
**/
var Report = {
  /**
  *
  **/
  init: function(){
    this.reports_page = $("#reports_page");
    this.view_report_form = this.reports_page.find("#view_report");
    this.report_setting_form = this.reports_page.find("#edit_report_setting");
    this.accountability_report = this.reports_page.find("#accountability_report");
    this.supervisors_approvers_report = this.reports_page.find("#supervisors_approvers_report");

    this.init_events();
  },

  /**
  * 
  **/
  init_events: function(){
    var self = this;

    /** Reports Page **/
    if(self.reports_page.length > 0){
      self.init_view_report_form();

      self.init_update_report_setting_form();

      self.reports_page.find(".select2.no-search").select2({minimumResultsForSearch: -1});

      self.reports_page.find(".select2").not(".no-search").select2({});

      self.init_accountability_report();
      self.init_supervisors_approvers_report();

      var multiple_selects = self.reports_page.find(".select2[multiple]").not(".no-search");
      $.each(multiple_selects, function(index, sel){
        $(sel).attr("data-prev-value", $(sel).select2("val"));

        self.multiple_select2_change_event(sel);
      })

      multiple_selects.on("change", function(e){
        self.multiple_select2_change_event(this);
      });
    }
  },

  init_view_report_form: function(){
    var self = this;

    /** View report **/
    if(self.view_report_form.length > 0){
      var view_btn = self.view_report_form.find("#view_report_btn");

      view_btn.click(function(e){
        e.preventDefault();

        self.view_report($(this).closest("form"));
        return false;
      });

      /** Areas change event **/
      var report_areas = self.view_report_form.find("#report_areas");
      if(report_areas.length > 0){
        self.areas_change_event(report_areas, self.view_report_form.find("#report_users"));
      }

      report_areas.trigger("change");
    }
  },

  init_update_report_setting_form: function(){
    var self = this;

    /** report setting **/
    if(self.report_setting_form.length > 0){
      var update_btn = self.report_setting_form.find("#update_report_setting_btn");

      update_btn.click(function(e){
        e.preventDefault();

        self.update_report_setting($(this).closest("form"));
        return false;
      });

      /** Areas change event **/
      var report_areas = self.report_setting_form.find("#report_setting_areas");
      if(report_areas.length > 0){
        self.areas_change_event(report_areas, self.report_setting_form.find("#report_setting_users"));
      }

      report_areas.trigger("change");
    }
  },

  init_accountability_report: function(){
    var self = this;

    /** accountability report **/
    if(self.accountability_report.length > 0){
      //Company.init_table_organisation($(".table-organisation"), self.accountability_report.find("#belongs_to_paths"));

      var view_btn = self.accountability_report.find("#view_accountability_report_btn");

      view_btn.click(function(e){
        e.preventDefault();

        self.view_report($(this).closest("form"));
        return false;
      });

      var areas = self.accountability_report.find("#accountability_report_areas");
      var areas_name = self.accountability_report.find("#accountability_report_areas_name");

      areas.change(function(e){
        e.preventDefault();

        areas_name.val(areas.find("option:selected").text());
      });

      areas_name.val(areas.find("option:selected").text());
    }
  },

  /**
  * Supervisors & Approvers
  **/
  init_supervisors_approvers_report: function(){
    var self = this;

    /** accountability report **/
    if(self.supervisors_approvers_report.length > 0){
      var view_btn = self.supervisors_approvers_report.find("#view_supervisors_approvers_report_btn");

      view_btn.click(function(e){
        e.preventDefault();

        self.view_report($(this).closest("form"));
        return false;
      });

      var areas = self.supervisors_approvers_report.find("#supervisors_approvers_report_areas");
      var areas_name = self.supervisors_approvers_report.find("#supervisors_approvers_report_areas_name");

      areas.change(function(e){
        e.preventDefault();

        areas_name.val(areas.find("option:selected").text());
      });

      areas_name.val(areas.find("option:selected").text());
    }
  },

  /**
  * 
  **/
  view_report: function(form){
    if(typeof form == "undefined"){
      return ;
    }

    var self = this;

    Proceduresync.show_loading();

    var data = {};
    $.each(form.serializeArray(), function(index, obj){ 
      data[obj["name"]] = obj["value"];

      var field = form.find("[name='" + obj["name"] + "']");

      if(field.hasClass("select2")){
        data[obj["name"]] = field.select2("val");
      }
    });
  
    $.fileDownload(form.attr("data-url"), {
      httpMethod: "GET",
      data: data
    });

    Proceduresync.hide_loading();
  },

  /**
  * 
  **/
  update_report_setting: function(form){
    if(typeof form == "undefined"){
      return ;
    }

    Proceduresync.show_loading();

    var self = this;
    var data = {};
    $.each(form.serializeArray(), function(index, obj){ 
      data[obj["name"]] = obj["value"]; 

      var field = form.find("[name='" + obj["name"] + "']");

      if(field.hasClass("select2")){
        data[obj["name"]] = field.select2("val");
      }
    });

    $.ajax(form.attr("data-url"), {
      type: 'PUT',
      data: data
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

      Proceduresync.show_loading();
    });
  },

  /**
  * Init Event for Areas in Report form
  **/
  areas_change_event: function(report_areas, report_users){
    report_areas.on("change", function(e) {
      var value = this.options[this.selectedIndex].value;

      if (value == "select_users"){
        report_users.removeAttr("disabled");
      }else{
        report_users.select2("val", "all");
        report_users.attr("disabled", "disabled");
      }
    });
  },

  /**
  * onChange multiple select2 event
  **/
  multiple_select2_change_event: function(ele){
    var value = $(ele).select2("val");
    var pre_value = $(ele).attr("data-prev-value");

    if(value.indexOf("all") != -1 && pre_value.indexOf("all") == -1){

      $(ele).select2("val", ["all"]);

    }else if(value.length > 1 && value.indexOf("all") != -1 && pre_value.indexOf("all") != -1){
      value.splice(value.indexOf("all"), 1);

      $(ele).select2("val", value);
    }

    $(ele).attr("data-prev-value", $(ele).select2("val"));
  }
}


$(function() {
  Report.init();
});