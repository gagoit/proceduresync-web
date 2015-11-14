/**
* Company module
**/
var Company = {
  /**
  *
  **/
  init: function(){
    this.company_structure_page = $("#company_structure_page");
    this.edit_organisation_modal = $('#edit_organisation_modal');
    this.company_url = this.company_structure_page.attr("data-company-url");

    this.preview_company_structure_modal = $('#preview_organisation_structure');

    this.logs_page = $("#company_logs_page");

    this.invoices_panel = $("#invoices_panel");
    this.edit_company_page = $("#company_info_page");
    
    this.init_events();
  },

  /**
  *
  **/
  init_events: function(){
    var self = this;

    self.click_upload_logo();

    /** Company Structure Page **/
    if(self.company_structure_page.length > 0){
      var company_id = self.company_structure_page.attr("data-company-id");
      var table_org = self.company_structure_page.find(".table-organisation");

      self.load_childs_of_org_node(table_org, company_id, "company");

      self.init_table_organisation(table_org);

      self.company_structure_page.find("#preview_company_structure_btn").click(function(){
        self.preview_company_structure();
      });

      /** Update name of node **/
      self.edit_organisation_modal.find("#btn_change_name_org").click(function(e){
        var name = self.edit_organisation_modal.find("#name").val();
        var id = self.edit_organisation_modal.find("#id").val();
        var type = self.edit_organisation_modal.find("#type").val();

        self.update_name_of_org_node(id, name, type);
      });
    }

    /** Logs **/
    if (self.logs_page.length > 0){
      var logs_table = self.logs_page.find($("#table-company-logs"));
      Proceduresync.init_logs_table(logs_table, "company");
    }

    /** Invoices **/
    if(self.invoices_panel.length > 0) {
      var columns = [
        { "sTitle": "Date",
          "sClass": "left",
          "sWidth": "25%",
          "mData": "date"
        },
        { "sTitle": "Total",
          "sClass": "left",
          "sWidth": "15%",
          "mData": "total",
          "mRender": function(data, type, full){
            return full.total_text
          }
        },
        { "sTitle": "",
          "sClass": "left",
          "sWidth": "60%", //Show "Download Invoice PDF" & "Download Users CSV"
          "mRender": function(data, type, full){
            var download_invoice_pdf = "<a href='"+full["invoice_pdf"]+"' target='blank'>" + I18n.t("company.invoices.action.download_invoice_pdf") + " </a>"
            var download_users_csv = " | <a href='"+full["users_csv"]+"' target='blank'> " + I18n.t("company.invoices.action.download_users_csv") + "</a>";
            
            return "<span class='pull-left'>"+download_invoice_pdf+download_users_csv+"</span>";
          }
        }
      ];

      var invoices_table = self.invoices_panel.find("#table-invoices");

      var empty_text = I18n.t("logs.table.no_result");
      if(invoices_table.data("search") && (invoices_table.data("search") + "").length > 0){
        empty_text = I18n.t("logs.table.no_search_result");
      }

      invoices_table.dataTable({
        sDom: 'rt<"#tbfoot"<"row"<"col col-lg-6"i><"col col-lg-6">>>',
        "bInfo": true,
        "bProcessing": false,
        "bServerSide": true,
        "bSort": false,
        "iDisplayLength": invoices_table.attr("data-per-page"),
        "bAutoWidth": false,
        "aoColumns": columns,
        "sAjaxSource": invoices_table.attr("data-url"),
        "oLanguage": {
          "sEmptyTable": empty_text,
        },
        "fnDrawCallback": function(){
          $(".dataTables_scrollBody").css("width", "100%");
          $(".dataTables_scrollHead").css("width", "100%");

          Proceduresync.show_hide_pagination(invoices_table);
        }
      });

      /** Generate invoice button **/
      self.invoices_panel.find("#generate-invoice").click(function(e){
        Proceduresync.show_loading();

        $.ajax($(this).attr("data-url"), {
          type: 'POST',
          data: {}
        }).done(function(ev){
          if(ev.success == true){
            AlertMessage.show("success", ev.message);
            invoices_table.dataTable().fnReloadAjax();
          }else{
            AlertMessage.show("danger", ev.message);
            window.location.reload();
          }

          Proceduresync.hide_loading();
        });

      });
    }

    /** Edit Company info **/
    if(self.edit_company_page.length > 0){
      self.form_init();
    }
  },

  /**
  * Init Organisation structure table
  **/
  init_table_organisation: function(table, field){
    var self = this;
    if(typeof table == "undefined"){
      table = $(".table-organisation");
    }

    if(table.attr("data-has-init") == "true"){
      return;
    }

    table.delegate("td span", "mouseover", function(){
      $(this).has("h5").removeClass("text-muted").addClass("text-nomal").find("h5").addClass("semi-bold");
      $(this).find("i.fa-pencil-square-o").removeClass("hidden");
    });

    table.delegate("td span", "mouseout", function(){
      $(this).has("h5").removeClass("text-nomal").addClass("text-muted").find("h5").removeClass("semi-bold");
      $(this).find("i.fa-pencil-square-o").addClass("hidden");
    });

    /** Load child nodes **/
    table.delegate("td span a.edit-name", "click", function(e){
      if($(this).hasClass("has_no_child")){
        return;
      }
      
      var span = $(this).closest("span");
      var id = span.attr("data-uid");
      var type = span.closest("td").attr("data-node-type");

      var td = $(this).closest("td.org-node");
      td.find("a.edit-name").removeClass("active");
      span.find("a.edit-name").addClass("active");

      self.load_childs_of_org_node(table, id, type);
      return false;
    });

    /** show Edit name of node modal**/
    table.delegate("td span i.fa-pencil-square-o", "click", function(e){
      var span = $(this).closest("span");
      var name = span.find("h5").text();
      var id = span.attr("data-uid");
      var type = span.closest("td").attr("data-node-type");

      self.edit_organisation_modal.find("#name").val(name);
      self.edit_organisation_modal.find("#id").val(id);
      self.edit_organisation_modal.find("#type").val(type);

      self.edit_organisation_modal.modal();

      return false;
    });

    /** Add a child to node **/
    table.delegate(".add-org-node button", "click", function(e){
      var div = $(this).closest(".add-org-node");
      var parent_id = div.attr("data-uid");
      var parent_type = div.closest("td").attr("data-parent-type");
      var name = div.find("input#name").val();

      self.add_child_to_org_node(parent_id, name, parent_type);
    });

    /** for Assign document and approver/suponsor table **/
    self.icheck_table_organisation(table, field);
  },

  /**
    params : {
      node_id: ,
      node_type: ,
      name:
    }
  **/
  update_name_of_org_node: function(node_id, name, node_type){
    name = name.trim();
    if(name.length == 0){
      return ;
    }

    var self = this;
    var current_node = self.company_structure_page.find("td.org-node[data-node-type='" + node_type + "']");
    var current_span = current_node.find("span.text-muted[data-uid='" + node_id + "']");

    Proceduresync.show_loading();

    $.ajax(self.company_url + "/update_org_node", {
      type: 'PUT',
      data: {
        node_id: node_id,
        node_type: node_type,
        name: name
      }
    }).done(function(ev){
      if(ev.success == true){
        var link = current_span.find("a.edit-name");
        link.text(ev.name);

        if(link.hasClass("active") && node_type != "panel"){
          var current_node_header = self.company_structure_page.find("th.org-node-header[data-node-type='" + node_type + "']");
          var next_node_header = current_node_header.next();

          next_node_header.html(ev.name);
        }

        self.edit_organisation_modal.modal("hide");
        
        AlertMessage.show("success", ev.message);
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
    params : {
      parent_id: ,
      parent_type: ,
      name:
    }
  **/
  add_child_to_org_node: function(parent_id, name, parent_type){
    name = name.trim();
    if(name.length == 0){
      return ;
    }

    var self = this;
    var current_node = self.company_structure_page.find("td.org-node[data-parent-type='" + parent_type + "']");
    var input = current_node.find("input#name");

    Proceduresync.show_loading();

    $.ajax(self.company_url + "/add_org_node", {
      type: 'POST',
      data: {
        parent_type: parent_type,
        parent_id: parent_id,
        name: name
      }
    }).done(function(ev){
      if(ev.success == true){
        var html = '<span class="text-muted" data-uid=' + ev.id + ' }>'
                      + '<h5><a class="edit-name">' + ev.name + '</a><i class="fa fa-pencil-square-o hidden"></i></h5></span>';

        $(html).insertBefore(current_node.find(".add-org-node"));

        input.val("");

        AlertMessage.show("success", ev.message);
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
    params : {
      node_id: ,
      node_type:
    }
  **/
  load_childs_of_org_node: function(table, node_id, node_type){
    var self = this;
    if(typeof table == "undefined"){
      table = $(".table-organisation");
    }

    if(node_type == "panel"){
      return;
    }else if(node_type == "company"){
      var next_node = table.find("td.org-node[data-node-type='division']");
      var next_nodes = next_node.nextAll();

      var next_node_header = table.find("th.org-node-header[data-node-type='division']");
      var next_nodes_header = next_node_header.nextAll();
    }else{
      var current_node = table.find("td.org-node[data-node-type='" + node_type + "']");
      var next_node = current_node.next();
      var next_nodes = current_node.nextAll();

      var current_node_header = table.find("th.org-node-header[data-node-type='" + node_type + "']");
      var next_node_header = current_node_header.next();
      var next_nodes_header = current_node_header.nextAll();

      var current_span = current_node.find("a.edit-name.active").closest("span");
    }

    Proceduresync.show_loading();

    if(table.find("input.icheck").length > 0){
      next_node.find("span").removeClass("visible").addClass("not-visible");

      if(typeof current_span == "undefined"){
        next_node_header.html(table.attr("data-company-name"));
        var path = company_id;
      }else{
        next_node_header.html(current_span.find("a").text());
        var path = current_span.find("input.icheck").attr("data-path");
      }

      next_nodes.each(function(e){
        next_nodes.find("a.edit-name").removeClass("active");
        $(this).addClass("not-visible").removeClass("visible");
      });

      next_nodes_header.each(function(e){
        $(this).addClass("not-visible").removeClass("visible");
      });

      var children = next_node.find("input.icheck");
      children.each(function(index, child){
        if($(child).attr("data-path").indexOf(path) == 0){
          $(child).closest("span.text-muted").removeClass("not-visible").addClass("visible");
        }
      });

      next_node.addClass("visible").removeClass("not-visible");
      next_node_header.addClass("visible").removeClass("not-visible");

      self.add_background_color_to_row(table);

      Proceduresync.hide_loading();
    }else{
      next_nodes.each(function(e){
        $(this).html("");
        $(this).addClass("not-visible").removeClass("visible");
      });

      next_nodes_header.each(function(e){
        $(this).html("");
        $(this).addClass("not-visible").removeClass("visible");
      });

      $.ajax(self.company_url + "/load_childs_of_org_node", {
        type: 'GET',
        data: {
          node_type: node_type,
          node_id: node_id
        }
      }).done(function(ev){
        if(ev.success == true){
          next_node.html(ev.childs_html);
          next_node_header.html(ev.name);

          next_node.addClass("visible").removeClass("not-visible");
          next_node_header.addClass("visible").removeClass("not-visible");
        }else{
          window.location.reload();
        }

        Proceduresync.hide_loading();
      });
    }
  },

  /**
  **/
  preview_company_structure: function(){
    var self = this;

    self.preview_company_structure_modal.modal("show");

    Proceduresync.show_loading();

    $.ajax(self.company_url + "/preview_company_structure", {
      type: 'GET',
      data: {
      }
    }).done(function(ev){
      if(ev.success == true){
        var treeData = ev.tree_data;
        var treeContent = self.preview_company_structure_modal.find(".modal-body");

        try{
          treeContent.dynatree('destroy');
        }catch(e){

        }

        treeContent.dynatree({
          checkbox: false,
          selectMode: 3,
          children: [treeData],
          // onSelect: function(select, node) {
          //   //Display list of selected nodes
          //   var tree = node.tree;

          //   //Display list of selected nodes
          //   var selNodes = tree.getSelectedNodes();
          // },
          onClick: function(node, event) {
            // We should not toggle, if target was "checkbox", because this
            // would result in double-toggle (i.e. no toggle)
            if( node.getEventTargetType(event) == "title" )
              node.toggleSelect();
          },
          onKeydown: function(node, event) {
            if( event.which == 32 ) {
              node.toggleSelect();
              return false;
            }
          },
          // The following options are only required, if we have more than one tree on one page:
          cookieId: "dynatree-Cb2",
          idPrefix: "dynatree-Cb2-"
        });
      }else{
        window.location.reload();
      }

      Proceduresync.hide_loading();
    });
  },

  click_upload_logo: function(){
    $('#upload-logo-btn').click(function(){
      $("#file-type").trigger('click');
    })

    $("input[id='file-type']").change(function() {
      var files = !!this.files ? this.files : [];
      // If no files were selected, or no FileReader support, return
      if (!files.length || !window.FileReader)
        return;
      // Only proceed if the selected file is an image
      if (/^image/.test(files[0].type)) {
        // Create a new instance of the FileReader
        var reader = new FileReader();
        // Read the local file as a DataURL
        reader.readAsDataURL(files[0]);
        // When loaded, set image data for src of image tag
        reader.onloadend = function() {
          $("#img-review img").attr("src", this.result);
        }
      }

    });
  },

  form_init: function(){
    $("#edit-company-billing").validate();
    $("#edit-company-creditcard").validate();

    if($("#edit-company-creditcard").length > 0){
      $( "#company_card_expiry" ).rules( "add", {
        required: true,
        card_expiry: true
      });
    }

    $('#select_country').select2({});

    $('#select_country').change(function() {
      if($("#select_country option:selected" ).text() == 'Australia'){
        $('#group_abn_acn').removeClass('hidden');
      }
      else{
        $('#group_abn_acn').addClass('hidden');
      }
    });

    var dateToday = new Date();
    // $('#company_card_expiry[data-rel=monthpicker]').datepicker( {
    //     format: "mm/yyyy",
    //     viewMode: "months",
    //     minViewMode: "months",
    //     startDate: dateToday
    // });

    if( ie <= 9){
      $('#file-type').removeClass('hidden');
      $('#upload-logo-btn').hide();
    }

    $("#edit-company-billing, #edit-company-creditcard").submit(function(){
      if($(this).valid()){
        Proceduresync.show_loading();
      }else{
        return false;
      }
    });

  },

  /**
  * A parent node will be checked if all it's child are checked
  * And will be mixed if one of it's child is checked (not all)
  **/
  check_parent_node: function(input){
    var self = this;
    var path = $(input).attr("data-path");
    var td = $(input).closest("td");

    var parent_path = path.replace((" > " + $(input).attr("data-uid")), "");

    var parent_state = "check";
    var num_checked = 0;
    var total = 0;
    var num_mixed = 0;
    var num_disabled = 0;

    /** Find and count parent-node's child that are checked / mixed **/
    td.find("input.icheck").each(function(index, child){
      if($(child).attr("data-path").indexOf(parent_path) == 0){
        if(child.checked){
          num_checked += 1;
        }else if($(child).closest("div").hasClass("mixed")){
          num_mixed += 1;
        }

        if(typeof $(child).attr("disabled") != "undefined"){
          num_disabled += 1;
        }

        total += 1;
      }
    });

    if(total == num_checked){
      parent_state = "check";
    }else if(num_checked == 0 && num_mixed == 0){
      parent_state = "uncheck";
    }else{
      parent_state = "mixed";
    }

    var prev_td = td.prev();
    if(prev_td.length > 0){
      var parent = prev_td.find("input.icheck");
      parent.each(function(index, child){
        if(parent_path == $(child).attr("data-path")){
          if(parent_state == "mixed"){
            ProceduresyncCheckbox.state(child, "uncheck");
            ProceduresyncCheckbox.mixed(child);
          }else{
            $(child).closest("div").removeClass("mixed");
            
            ProceduresyncCheckbox.state(child, parent_state);
          }

          if(num_disabled == 0){
            $(child).removeAttr("disabled");
            ProceduresyncCheckbox.state(child, "enable");
            $(child).closest("div").removeClass("disabled");
          }

          $(child).attr("data-processed", "true");

          self.check_parent_node(child);
        }
      });
    }
  },

  /**
  * 
  **/
  icheck_table_organisation: function(table, field){
    var self = this;
    if(typeof table == "undefined"){
      table = $(".table-organisation");
    }

    if(table.attr("data-has-init") == "true"){
      return;
    }

    var checkbox_event = ( ie < Proceduresync.OLD_IE_VERSION ) ? "click" : "ifClicked";

    /** Check a node **/
    table.find("input.icheck").on(checkbox_event, function(e){
      
      $(this).attr("data-processed", "false");

      var path = $(this).attr("data-path");
      var td = $(this).closest("td");
      var next_tds = td.nextAll();
      
      var new_value = ( ie < Proceduresync.OLD_IE_VERSION ) ? this.checked : !this.checked;

      var new_state = new_value ? "check" : "uncheck";

      ProceduresyncCheckbox.state(this, new_state);

      ProceduresyncCheckbox.remove_mixed(this);
      
      var children = next_tds.find("input.icheck");
      children.each(function(index, child){
        if($(child).attr("data-path").indexOf(path) == 0){
          ProceduresyncCheckbox.remove_mixed(child);
          
          ProceduresyncCheckbox.state(child, new_state);
        }
      });

      self.check_parent_node(this);

      if(typeof field != "undefined"){
        field.val(JSON.stringify( self.company_structure_page_checked_nodes(table)));
      }
    });

    /** Init Table, show current mixed node **/
    var last_td = table.find("td:last");
    var last_nodes;

    while(last_td.length > 0){
      last_nodes = last_td.find("input.icheck").not("[data-processed='true']");
      
      last_nodes.each(function(index, child){
        self.check_parent_node(child);
      });

      last_td = last_td.prev();
    }

    /** Expanded first leaf node **/
    if(table.attr('data-expanded') == "true"){
      var had_clicked = false;
      var parent_id = "";
      table.find("td").each(function(index, td){
        had_clicked = false;
        
        $(td).find("input.icheck").each(function(i, ip){
          
          if(!had_clicked && (ip.checked || ProceduresyncCheckbox.is_mixed(ip)) && 
              ($(ip).attr("data-path").indexOf(parent_id) > -1 || parent_id == "") ){

            $(ip).closest("span").find("a.edit-name").click();
            had_clicked = true;
            parent_id = $(ip).attr("data-path");
            return false;
          }
        });
      });
    }

    table.attr("data-has-init", "true");
    if(typeof field != "undefined"){
      field.val(JSON.stringify( self.company_structure_page_checked_nodes(table)));
    }
  },

  /**
  * 
  **/
  show_limit_path_in_table_organisation: function(table, field){
    var self = this;
    if(typeof table == "undefined"){
      table = $(".table-organisation");
    }
  },

  /**
  *
  **/
  company_structure_page_checked_nodes: function(table){
    if(typeof table == "undefined"){
      table = $(".table-organisation");
    }

    var ichecks = table.find("input.icheck:checked[data-has-child='false']").map(function(index, item){
      return $(item).attr("data-path");
    });

    return ichecks.toArray();
  },

  /**
  * Init table organisation for view, not edit
  **/
  init_table_organisation_for_view: function(table){
    if(typeof table == "undefined"){
      table = $(".table-organisation");
    }
    
    var self = this;
    self.init_table_organisation(table);

    /** Disable icheck **/
    ProceduresyncCheckbox.state(table.find("input.icheck"), "disable");
  },

  /**
  * Add background color to row
  **/
  add_background_color_to_row: function(table){
    table.find("td.org-node span h5").css('background-color', 'none');

    table.find("td.org-node.visible").each(function(i, node){
      $(node).find("span.visible:even h5").css('background-color', '#eff3f4');
    });
  }
}


$(function() {
  Company.init();
});
