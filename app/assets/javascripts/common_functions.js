/**
* Common functions for Proceduresync
**/
var Proceduresync = {
  OLD_IE_VERSION: 10,
  /**
  *
  **/
  init_number_textbox: function(field){
    field.keydown(function(event) {
        // Allow: backspace, delete, tab, escape, and enter
      if ( event.keyCode == 46 || event.keyCode == 8 || event.keyCode == 9 || event.keyCode == 27 || event.keyCode == 13 ||
         // Allow: Ctrl+A
        (event.keyCode == 65 && event.ctrlKey === true) ||
         // Allow: home, end, left, right
        (event.keyCode >= 35 && event.keyCode <= 39)) {
             // let it happen, don't do anything
             return;
      }
      else {
        // Ensure that it is a number and stop the keypress
        if (event.shiftKey || (event.keyCode < 48 || event.keyCode > 57) && (event.keyCode < 96 || event.keyCode > 105 )) {
            event.preventDefault();
        }
      }
    });
  },

  /**
  *
  **/
  init_decimal_textbox: function(field){
    field.keydown(function (event) {
      if (event.shiftKey == true) {
          event.preventDefault();
      }

      if ((event.keyCode >= 48 && event.keyCode <= 57) ||
          (event.keyCode >= 96 && event.keyCode <= 105) ||
          event.keyCode == 8 || event.keyCode == 9 || event.keyCode == 37 ||
          event.keyCode == 39 || event.keyCode == 46 || event.keyCode == 190) {

      } else {
          event.preventDefault();
      }

      if($(this).val().indexOf('.') !== -1 && event.keyCode == 190)
          event.preventDefault();
      //if a decimal has been added, disable the "."-button

      });
  },

  reload_page: function(){
    window.location.reload();
  },

  init_logs_table: function(table, type){
    var columns = [
        { "sTitle": "Timestamp",
          "sClass": "left",
          "sWidth": "25%",
          "mData": "action_time"
        },
        { "sTitle": "Logs",
          "sClass": "left",
          "sWidth": "75%",
          "mData": "log",
          "mRender": function(data, type, full){
            var reg = new RegExp("by " + full.user_name,"g");
            var new_data = data.replace(reg, "by " + full.user_url);

            return new_data;
          }
        }
      ];

    if(type == "company"){
      columns[1]["sWidth"] = "60%";

      columns.push({ 
        "sTitle": "User",
        "sClass": "left",
        "sWidth": "15%",
        "mData": "user_url"
      });
    }

    var empty_text = I18n.t("logs.table.no_result");
    if(table.data("search") && (table.data("search") + "").length > 0){
      empty_text = I18n.t("logs.table.no_search_result");
    }

    table.dataTable({
      sDom: 'rt<"#tbfoot"<"row"<"col col-lg-6"i><"col col-lg-6"p>>>',
      "bInfo": true,
      "bProcessing": false,
      "bServerSide": true,
      "bSort": false,
      "iDisplayLength": table.attr("data-per-page"),
      "bAutoWidth": false,
      "aoColumns": columns,
      "sAjaxSource": table.attr("data-url"),
      "oLanguage": {
        "sEmptyTable": empty_text,
      },
      "fnServerData": function ( sSource, aoData, fnCallback ) {
        if(type == "company"){
          aoData.push({ "name": "search", "value": $(this).data("search")});
        }
        $.getJSON(sSource, aoData, function (json) {
          fnCallback(json);
        });
      },
      "fnDrawCallback": function(){
        $(".dataTables_scrollBody").css("width", "100%");
        $(".dataTables_scrollHead").css("width", "100%");

        Proceduresync.show_hide_pagination(table);
      }
    });
  },

  getViewPort: function () {
    var e = window, a = 'inner';
    if (!('innerWidth' in window)) {
        a = 'client';
        e = document.documentElement || document.body;
    }
    return {
      width: e[a + 'Width'],
      height: e[a + 'Height']
    }
  },

  sign_out_event: function() {
    $(".sign-out").click(function(e){
      e.preventDefault();
      var link = $(this);
      var url = link.attr("href");
      var method = link.attr("data-method");
      if( link.attr("confirm") == "true" ){
        return true;
      }

      bootbox.confirm("Are you sure you want to sign out?", function(result) {
        if (result == true) {
          link.attr("confirm", "true");
          link.click();
        }
      });

      return false;
    });
  },

  show_loading: function(){
    var div_load = $(".page-subheading .breadcrumb").find(".my-loading");

    if(div_load.length > 0){
      div_load.show();
    }else{
      $("<div class='my-loading'></div>").appendTo(".page-subheading .breadcrumb");
    }
  },

  hide_loading: function(){
    var div_load = $(".page-subheading .breadcrumb").find(".my-loading");

    if(div_load.length > 0){
      div_load.hide();
    }
  },

  /**
  * remove if has only one page
  **/
  show_hide_pagination: function(table){
    var parent = $(document);
    if(table){
      parent = table.closest("div");  
    }

    if(parent.find("#tbfoot .pagination li").length <= 3){
      parent.find("#tbfoot .pagination").hide();
    }else{
      parent.find("#tbfoot .pagination").show();
    }
  },

  /** Init common event for Ajax **/
  ajax_init: function(){
    var self = this;

    $.ajaxSetup({
      'beforeSend': function(xhr) {
        xhr.setRequestHeader("Accept", "application/json");
      }
    });

    $(document).ajaxStart(function(){
      self.show_loading();

    }).ajaxComplete(function(ev){
      self.hide_loading();

      if(ev.window_reload){
        bootbox.alert("<%= ev.message %>");

        window.location.reload();
      }
    }).ajaxError(function(ev, jqxhr){
      self.hide_loading();

      if(ev.window_reload){
        bootbox.alert("<%= ev.message %>");

        window.location.reload();
      }
    });
  },

  clear_input_event: function(){
    $(document).delegate("#clear-input", "click", function(e){
      e.preventDefault();

      var input = $(this).closest(".form-group").find("input");
      input.val("");

      return false;
    });
  },

  init_select2: function(div){
    if(typeof div == "undefined"){
      div.find(".select2.no-search").select2({minimumResultsForSearch: -1});

      div.find(".select2").not(".no-search").select2({});
    }else{
      $(".select2.no-search").select2({minimumResultsForSearch: -1});

      $(".select2").not(".no-search").select2({});
    }
  },

  init_select2_for_field: function(field){
    if(typeof field != "undefined"){
      if(field.hasClass("no-search")){
        field.select2({minimumResultsForSearch: -1});
      }else{
        field.select2({});
      }
    }
  },

  /**
  * Get filename of file
  **/
  getFileName: function(file_name, is_url){
    origin_name = file_name;
    if(is_url){
      origin_name = file_name.split('\\').pop();
    }
    return origin_name.split(/(?:\.([^.]+))?$/)[0];
  },

  /**
  * redirect_to
  **/
  redirect_to: function(url, time_offset){
    if(typeof url == "undefined"){
      url = window.location.href;
    }

    if(typeof time_offset == "undefined"){
      time_offset = 2000;
    }

    window.setTimeout(function(){$(location).attr('href', url)}, time_offset);
  },

  /**
  * Remove placeholder when input field is disabled
  **/
  remove_placeholder_for_disabled_input: function(){
    $("input[type=text][disabled]").attr("placeholder", "");
  },

  /**
  * get top (padding + margin + subheader .. )
  **/
  get_top_height: function(){
    try{
      var top = [];
      var total_top = 0;
      top.push($("header").height());
      top.push($(".page-subheading").height());
      top.push(parseInt($(".page-subheading").css("padding-top")));
      top.push(parseInt($(".page-subheading").css("padding-bottom")));
      top.push(parseInt($(".page-subheading").css("margin-bottom")));
      top.push($(".panel-heading").height());

      top.push(parseInt($(".panel-heading").css("padding-top")));
      top.push(parseInt($(".panel-heading").css("padding-bottom")));

      top.push(parseInt($(".panel-body").css("padding-top")));
      top.push(parseInt($(".panel-body").css("padding-bottom")));

      top.push(parseInt($(".panel").css("margin-bottom")));

      for (var i = 0; i < top.length; i++) {
        if( (top[i] + "") == "NaN"){
          total_top += 0; 
        }else{
          total_top += top[i];
        }
      };

      return total_top;
    }catch(e){
      return 200;
    }
  },

  /**
  * Load company structure table for approve to areas, supervisor for areas, bulk assignment for areas
  **/
  load_company_structure_table: function(parent_section, field){
    if (parent_section.find("table").length > 0){
      return;
    }

    var self = this;
    var company_areas_table = parent_section.find(".company-areas-table");

    Proceduresync.show_loading();

    $.ajax(parent_section.attr("data-load-table-url"), {
      type: 'GET',
      data: {}
    }).done(function(ev){
      if(ev.success == true){
        if(parent_section.find("table").length == 0){
          company_areas_table.html(ev.company_structure_table_html);
          Icheck.init(company_areas_table);
          Company.init_table_organisation(parent_section.find("table"), field);

          var p_id = parent_section.attr("id");

          if(( p_id == "documents_assignment_modal" || p_id == "div_belongs_to_paths") && 
            parent_section.attr("data-can-add-edit-doc") != "true" ){
              Company.show_limit_path_in_table_organisation(parent_section.find("table"));
          }
        }
      }else{
        AlertMessage.show("danger", ev.message);
      }
      Proceduresync.hide_loading();
    });
  },

  /** 
  * Init tooltip style
  **/
  init_tooltip: function(div){
    var tooltip_elements = $('[data-toggle="tooltip"]');

    if(typeof div != "undefined"){
      tooltip_elements = div.find('[data-toggle="tooltip"]');
    }

    tooltip_elements.tooltip().on('show.bs.tooltip', function () {
        var style = $(this).data('style');
        if (style && style !== '') {
            $(this).data('bs.tooltip').tip().addClass('tooltip-' + style);
        }
    });
  }
}

/**
* Proceduresync Checkbox
* If IE < Proceduresync.OLD_IE_VERSION : We will not use iCheck
* Else : we will use iCheck
**/
var ProceduresyncCheckbox = {
  /**
  * Set checkbox checked/not checked
  **/
  state: function(checkbox, new_state){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      this.state_ie(checkbox, new_state);      
    }else{
      $(checkbox).iCheck(new_state);
    }
  },

  /**
  * For IE 8 9
  **/
  state_ie: function(checkbox, new_state){
    
    if( new_state == "check" || new_state == "uncheck" ){
      var checked = (new_state == "check") ? true : false;

      $(checkbox).prop( "checked", checked );
      this.remove_mixed(checkbox);

    }else if( new_state == "enable" || new_state == "disable" ){
      var disabled = (new_state == "disable") ? true : false;

      $(checkbox).attr("disabled", disabled);
    }
  },

  /**
  * Set mixed state
  **/
  mixed: function(checkbox){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      var parent = $(checkbox).parent();
      if(parent.hasClass("div-for-checkbox")){
        parent.addClass("mixed");
        $("<label for='" + $(checkbox).attr("id") + "'></label>").appendTo(parent);
      }else{
        $(checkbox).wrapAll('<div/>');
        parent = $(checkbox).parent();
        $("<label for='" + $(checkbox).attr("id") + "'></label>").appendTo(parent);

        parent.addClass("div-for-checkbox");
        parent.addClass("mixed");
      }
    }else{
      $(checkbox).closest("div").addClass("mixed");
    }
  },

  /**
  * remove mixed state
  **/
  remove_mixed: function(checkbox){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      var parent = $(checkbox).parent();
      if(parent.hasClass("div-for-checkbox")){
        parent.removeClass("mixed");
        parent.find("label").remove();
      }
    }else{
      $(checkbox).closest("div").removeClass("mixed");
    }
  },

  /**
  * Check checkbox is checked
  **/
  is_checked: function(checkbox){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      return ($(checkbox).attr("checked") == "checked");
    }
      
    return $(checkbox).closest("div").hasClass("checked");
  },

  /**
  * Check checkbox has status mixed
  **/
  is_mixed: function(checkbox){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      return $(checkbox).closest("div.div-for-checkbox").hasClass("mixed");
    }
      
    return $(checkbox).closest("div").hasClass("mixed");
  },

  /**
  * Check checkbox has status disabled
  **/
  is_disabled: function(checkbox){
    if( ie < Proceduresync.OLD_IE_VERSION ){
      return $(checkbox).closest("div.div-for-checkbox").hasClass("disabled");
    }
      
    return $(checkbox).closest("div").hasClass("disabled");
  }
}


$(function() {
  Proceduresync.sign_out_event();

  Proceduresync.ajax_init();

  Proceduresync.clear_input_event();
  Proceduresync.remove_placeholder_for_disabled_input();
});
