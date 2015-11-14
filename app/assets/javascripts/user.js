/**
* User module
**/
var User = {
  /**
  * #login_page
  **/
  init: function(){
    this.setup_page = $("#setup_page");
    this.user_edit_page = $("#user_edit_page");
    this.user_profile_page = $("#user_profile_page");
    this.users_page = $("#users_page");
    this.logs_table = $('#table-user-logs');
    this.users_table = $("#all_users");

    this.devices_page = $("#user_devices_page");

    if(this.devices_page.length == 0){
      this.devices_page = $("#user_devices_panel");
    }

    this.init_events();
  },

  /**
  * 
  **/
  init_events: function(){
    var self = this;

    /** Setup Page **/
    if(self.setup_page.length > 0){
      var setup_form = self.setup_page.find("form");
      var mark_as_read_modal = self.setup_page.find("#mark_as_read_modal");

      var mark_as_read_field = setup_form.find("#user_mark_as_read");
      var remind_later_field = setup_form.find("#user_remind_mark_as_read_later");

      self.setup_form_validation(setup_form);

      /** 
      *   Only show mark_as_read modal if this modal was not shown before 
      *   or (remind_later field is not blank and it's value is != false)
      **/
      if(remind_later_field.length > 0 && remind_later_field.val() != "false"){
        self.setup_page.attr("data-show-modal", "1");
      }
      
      if(setup_form.attr("data-has-setup") == "true"){
        mark_as_read_modal.modal({backdrop: 'static'});
        mark_as_read_modal.modal("show");
        self.setup_page.find(".panel-body").hide();
      }

      setup_form.submit(function(e){
        if($(this).valid()){
          if(self.setup_page.attr("data-show-modal") != "1"){
            return true;
          }else{
            mark_as_read_modal.modal();
            return false;
          }
        }else{
          return false;
        }
      });

      /** Mark as read **/
      mark_as_read_modal.find("button").click(function(e){
        e.preventDefault();

        mark_as_read_field.val("nil");
        remind_later_field.val("nil");

        var field = $(this).attr("data-field");
        var value = $(this).attr("data-value");

        function submit_setup_form(){
          mark_as_read_modal.modal("hide");
          self.setup_page.attr("data-show-modal", "0");

          setup_form.submit();
        }

        if(field == "mark_as_read"){
          if(value == "false"){ /*leave all unread*/
            bootbox.confirm(I18n.t("user.setup.confirm_leave_all_unread"), function(result) {
              if (result == true) {
                mark_as_read_field.val(value);
                remind_later_field.val("false");

                submit_setup_form();
                return;
              }
            });

          }else{
            mark_as_read_field.val(value);
            remind_later_field.val("false");

            submit_setup_form();
          }
        }else if(field == "remind_mark_as_read_later"){
          remind_later_field.val(value);

          submit_setup_form();
        }else {
        }
      });
    }
      
    /** New/Edit User page **/
    if(self.user_edit_page.length > 0){
      self.init_edit_user_page();
    }

    /** Profile User page **/
    if(self.user_profile_page.length > 0){
      var profile_form = self.user_profile_page.find("form#edit_user");

      self.setup_form_validation(profile_form);

      profile_form.submit(function(e){
        e.preventDefault();

        if (profile_form.valid()){
          self.update_user(profile_form);
        }
        return false;
      });

      self.init_belongs_to_select();

      /** Logs **/
      Proceduresync.init_logs_table($('#table-user-logs'));

      /** Show approver/supervisor areas **/
      Company.init_table_organisation_for_view($("#table-org-for-approver"));
      Company.init_table_organisation_for_view($("#table-org-for-supervisor"));

      /** Approval email settings for Approver **/
      var approval_email_setting_form = self.user_profile_page.find("form#approval_email_settings");

      Proceduresync.init_select2_for_field(approval_email_setting_form.find("#email_settings"));

      approval_email_setting_form.submit(function(e){
        e.preventDefault();

        var data = {};
        $.each(approval_email_setting_form.serializeArray(), function(index, obj){ data[obj["name"]] = obj["value"] });

        $.ajax(approval_email_setting_form[0].action, {
          type: approval_email_setting_form[0].method,
          data: data
        }).done(function(ev){
          if(ev.success == true){
            AlertMessage.show("success", ev.message);
          }else{
            AlertMessage.show("danger", ev.message);
          }

          Proceduresync.hide_loading();
        });
        
        return false;
      });
    }

    /** Users page **/
    if(self.users_page.length > 0){
      self.init_users_table();

      Proceduresync.init_select2_for_field($("#select-actions"));

      $("#select-actions").on("change", function() {
        var selectBox = document.getElementById("select-actions");
        var selectedValue = selectBox.options[selectBox.selectedIndex].value;
        var selected_ids = ProceduresyncTable.getSelectedIds(self.users_table);

        if(selected_ids.length == 0){
          bootbox.alert(I18n.t("user.index.no_selected_user"));
          $(this).select2('val', 'action');
          return;
        }

        if (selectedValue == "assign_users") {
          $('#assign_users_modal').modal();

          if($("#assign_users_modal").attr("data-has-shown") == "false"){
            $("#assign_users_modal").attr("data-has-shown", "true");
            self.init_belongs_to_select();
          }
          
        }else if (selectedValue == "download_csv") {
          self.downLoad_csv($(selectBox).attr("data-url"));
        }

        $(this).select2('val', 'action');
      });

      // Update users path
      $("#assign_users_modal #submit_update_users_path").on('click',function(){
        var paths = $("#assign_users_modal #user_company_path_ids").val();

        Proceduresync.show_loading();

        $.ajax($(this).attr("data-url"), {
          type: 'PUT',
          data: {
            paths: paths,
            user_ids: ProceduresyncTable.getSelectedIds(self.users_table),
            search: self.users_table.attr("data-search")
          }
        }).done(function(ev){
          if(ev.success == true){
            self.users_table.dataTable().fnReloadAjax();
            $('#assign_users_modal').modal('hide');
            AlertMessage.show("success", ev.message);
          }else{
            window.location.reload();
          }

          Proceduresync.hide_loading();
        });
      });
    }

    /** Change Company **/
    $("a.change-company").click(function(e) {
      e.preventDefault();
      var company_id = $(this).attr("data-uid");

      Proceduresync.show_loading();
      $.ajax(this.href, {
        type: 'PUT',
        data: {
          company_id: company_id
        }
      }).done(function(ev){
        if(ev.success == true){
          window.location = ev.success_url;
        }else{
          AlertMessage.show("danger", ev.message);
          Proceduresync.hide_loading();
        }
      });
    });

    /** User Devices page **/
    if(self.devices_page.length > 0){
      self.init_devices_page();
    }
  },

  init_edit_user_page: function(){
    var self = this;

    if(self.user_edit_page.length == 0){
      return;
    }  

    self.init_belongs_to_select();
    self.init_permission_select();

    var perm_select = self.user_edit_page.find("#user_permission_id");
    var custom_permissions = self.user_edit_page.find("#custom_permissions");
    var edit_form = self.user_edit_page.find("form#edit_user");

    Proceduresync.init_select2_for_field(self.user_edit_page.find("#user_user_type"));

    perm_select.change(function(e){
      self.show_hide_approver_supervisor_section();

      self.render_custom_permissions($(this));
    });

    var checkbox_event = ( ie < Proceduresync.OLD_IE_VERSION ) ? "click" : "ifToggled";

    /** show approver section when is_approval_user clicked **/
    self.user_edit_page.delegate("#permission_is_approval_user", checkbox_event, function(event){
      self.show_hide_approver_supervisor_section();
    });

    /** show supervisor section when is_supervisor_user clicked **/
    self.user_edit_page.delegate("#permission_is_supervisor_user", checkbox_event, function(event){
      self.show_hide_approver_supervisor_section();
    });

    self.show_hide_approver_supervisor_section();

    self.user_edit_page.delegate("#user_user_type", "change", function(e){
      /** Load permissions for user type **/
      $.ajax($(this).attr("data-url"), {
        type: "GET",
        data: {
          code: $(this).select2("val"),
          permission_id: perm_select.select2("val")
        }
      }).done(function(ev){
        if(ev.success == true){
          self.user_edit_page.find("#available_permissions").html(ev.html);
          Icheck.init_icheck(self.user_edit_page.find("#available_permissions"));

          self.show_hide_approver_supervisor_section();
        }
      });
    });

    self.render_custom_permissions(perm_select);

    edit_form.submit(function(e){
      e.preventDefault();

      self.update_user(edit_form);
      return false;
    });

    //Approver / Supervisor table
    Company.init_table_organisation($("#table-org-for-approver"), $("#user_approver_paths"));
    Company.init_table_organisation($("#table-org-for-supervisor"), $("#user_supervisor_paths"));

    /** Logs **/
    Proceduresync.init_logs_table(self.logs_table);
  },

  /**
  * Check and show/hide approver section based on user type and permission
  **/
  show_hide_approver_supervisor_section: function(){
    var self = this;
    var perm_select = self.user_edit_page.find("#user_permission_id");
    var approver_section = self.user_edit_page.find(".form-group#approver-section");
    var supervisor_section = self.user_edit_page.find(".form-group#supervisor-section");

    var bulk_assign_documents_perm = self.user_edit_page.find("#permission_bulk_assign_documents");

    var user_type = self.user_edit_page.find("#user_user_type").select2("val");
    var approver_code = perm_select.attr("data-approver-code");
    var supervisor_code = perm_select.attr("data-supervisor-code");

    if(approver_code == user_type || ($("#permission_is_approval_user")[0] && $("#permission_is_approval_user")[0].checked)){
      approver_section.removeClass("hidden");

      bulk_assign_documents_perm.closest("tr").show();

      if(approver_section.find("#table-org-for-approver").length == 0){
        Proceduresync.load_company_structure_table(approver_section, $("#user_approver_paths"));
      }
    }else{
      approver_section.addClass("hidden");
      bulk_assign_documents_perm.closest("tr").hide();
      ProceduresyncCheckbox.state(bulk_assign_documents_perm, "uncheck");
    }

    if(supervisor_code == user_type || ($("#permission_is_supervisor_user")[0] && $("#permission_is_supervisor_user")[0].checked)){
      supervisor_section.removeClass("hidden");

      if(supervisor_section.find("#table-org-for-supervisor").length == 0){
        Proceduresync.load_company_structure_table(supervisor_section, $("#user_supervisor_paths"));
      }
    }else{
      supervisor_section.addClass("hidden");
    }
  },

  /**
  * 
  **/
  update_user: function(form){
    var self = this;

    if(form.length == 0){
      return;
    }

    Proceduresync.show_loading();

    var data = {};

    $.each(form.serializeArray(), function(index, obj){ data[obj["name"]] = obj["value"] });

    if(self.user_edit_page.length > 0){
      if(data["user[permission_id]"] == "custom_permission"){
        data["custom_permissions"] = self.get_custom_permissions();
        data["user[user_type]"] = self.user_edit_page.find("#user_user_type").val();
      }

      data["user[prev_action]"] = "edit";
    }else{
      data["user[prev_action]"] = "profile";
    }
    
    $.ajax(form[0].action, {
      type: form[0].method,
      data: data
    }).done(function(ev){
      if(ev.success == true){
        if(typeof ev.return_url != "undefined") {
          AlertMessage.show("success", ev.message);

          setTimeout(function(){
            window.location = ev.return_url;
          }, 2500);
        }else{
          AlertMessage.show("success", ev.message);

          var panel = form.closest(".panel");
          panel.find(".panel-heading h4").html(data["user[name]"]);

          self.logs_table.dataTable().fnReloadAjax();
        }
      }else if(ev.error_code == "user_existed"){
        bootbox.confirm(ev.message, function(result) {
          if (result == true) {
            form.find("#user_confirm_overwrite").val("true");
            self.update_user(form);
            Proceduresync.hide_loading();
            return;
          }else{

          }
        });
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  * 
  **/
  get_custom_permissions: function(){
    var self = this;

    var custom_permissions = self.user_edit_page.find("#custom_permissions");

    var permissions = {};

    custom_permissions.find("td.permission").each(function(e){
      var td = $(this);
      var input = td.find("input");
      var perm_type = td.attr("data-key");

      permissions[perm_type] = input[0].checked;
    });

    return permissions;
  },

  /** 
  * Render the custom permissions widget in the right side when change permission in the left side
  **/
  render_custom_permissions: function(perm_select){
    var self = this;
    var permission_id = perm_select.select2("val");
    var option = perm_select[0].options[perm_select[0].selectedIndex];

    if(permission_id == "custom_permission"){
      self.user_edit_page.find("#user_user_type").removeAttr("disabled");
      ProceduresyncCheckbox.state(self.user_edit_page.find("#available_permissions input"), "enable");
    }else{
       self.user_edit_page.find("#user_user_type").select2("val", $(option).attr("data-code"));         
       self.user_edit_page.find("#user_user_type").trigger("change");
       self.user_edit_page.find("#user_user_type").attr("disabled", "disabled");
    }
  },

  /**
  * 
  **/
  setup_form_validation: function(form){
    var rules = {
      "user[email]": {
        required: true,
        email: true
      },
      "user[password]": {
        minlength: 10,
        password_validation: true
      },
      "user[password_confirmation]": {
        equalTo: "#user_password",
        password_validation: true
      }
    };

    if(form.attr("data-has-setup") == "false"){
      rules["user[password]"].required = true;
      rules["user[password_confirmation]"].required = true;
    }

    form.validate({
        highlight: function (element) {
            jQuery(element).closest('.form-group').removeClass('has-success').addClass('has-error');
        },
        success: function (element) {
            jQuery(element).closest('.form-group').removeClass('has-error');
        },
        rules: rules,
        errorElement: 'span',
        errorClass: 'help-block jq-validate-error',
        errorPlacement: function (error, element) {
            if (element.parent('.input-group').length) {
                error.insertAfter(element.parent());
            } else if (element.prop('type') === 'checkbox') {
                error.appendTo(element.closest('.checkbox').parent());
            } else if (element.prop('type') === 'radio') {
                error.appendTo(element.closest('.radio').parent());
            }
            else {
                error.insertAfter(element);
            }
        }
    });
  },

  init_belongs_to_select: function(){
    $("#user_company_path_ids").select2({
      placeholder: "Choose a company paths",
      formatNoMatches: function(term) {
        if(term){
          return term + ' is not found';
        }else{
          return 'No path found.';
        }
      }
    });
  },

  init_permission_select: function(){
    $("#user_permission_id").select2({
      minimumResultsForSearch: -1,
      placeholder: "Choose a Permission",
      formatNoMatches: function(term) {
        if(term){
          return term + ' is not found';
        }else{
          return 'No permission found.';
        }
      }
    });
  },

  init_users_table: function(){
    var self = this;

    var columns = [
        { "sTitle": '<input id="optionsCheckboxAll" type="checkbox" value="all" class="icheck square-blue">',
          "sWidth": "5%",
          "bSortable": false,
          "mData": "id",
          "mRender": self.render_checkbox
        },
        { "sTitle": "Name",
          "sWidth": "8%",
          "bSortable": true,
          "mData": 'name'
        },
        { "sTitle": "Email",
          "sWidth": "10%",
          "mData": "emails"
        },
        { "sTitle": "Area",/*self.users_table.attr("data-lowest-level"),*/
          "sWidth": "17%",
          "bSortable": false,
          "sClass": "text-center",
          "mData": "path"
        },
        { "sTitle": "Unread Documents",
          "sWidth": "20%",
          "bSortable": false,
          "mData": "unread_docs",
          "mRender": self.render_unread_docs
        },
        { "sTitle": "Active",
          "sWidth": "6%",
          "bSortable": true,
          "sClass": "text-center",
          "mData": "active",
          "mRender": self.render_active
        },
        { "sTitle": "Edit",
          "sWidth": "8%",
          "bSortable": false,
          "sClass": "text-center",
          "mData": "edit_url",
          "mRender": self.render_edit
        }
      ];

    var empty_text = I18n.t("user.table.no_result");
    if(self.users_table.data("search") && (self.users_table.data("search") + "").length > 0){
      empty_text = I18n.t("user.table.no_search_result");
    }

    self.users_table.dataTable({
      sDom: 'rt<"#tbfoot"<"row"<"col col-lg-6"i><"col col-lg-6"p>>>',
      "bInfo": true,
      "bProcessing": false,
      "bServerSide": true,
      "bAutoWidth": false,
      "iDisplayLength": self.users_table.attr("data-per-page"),
      "order": [[ 1, "asc" ]],
      "aoColumns": columns,
      "oLanguage": {
        "sEmptyTable": empty_text,
      },
      "sAjaxSource": self.users_table.attr("data-path"),
      "fnServerData": function ( sSource, aoData, fnCallback ) {
        aoData.push({ "name": "search", "value": $(this).data("search")});
        $.getJSON(sSource, aoData, function (json) {
          fnCallback(json);
        });
      },
      "fnDrawCallback": function(){
        $(".dataTables_scrollBody").css("width", "100%");
        $(".dataTables_scrollHead").css("width", "100%");

        if(ie < Proceduresync.OLD_IE_VERSION){

        }else{
          Icheck.init(self.users_table);  
        }
        
        ProceduresyncTable.checkBoxAllClick(self.users_table);
        Proceduresync.show_hide_pagination(self.users_table);
      }
    });

    $(window.document).delegate(".load-more-unread-docs", "click", function(e){
      e.preventDefault();

      self.load_more_unread_docs(this);
      return false;
    });

    $(window.document).delegate(".mark-all-as-read", "click", function(e){
      e.preventDefault();
      var link = this;

      bootbox.confirm(I18n.t("user.mark_all_as_read.confirm_text"), function(result) {
        if (result == true) {
          self.mark_all_as_read(link);
        }
      });

      return false;
    });
  },

  load_more_unread_docs: function(ele){
    var self = this;

    Proceduresync.show_loading();

    $.ajax(ele.href, {
      type: 'GET',
      data: {}
    }).done(function(ev){
      if(ev.success == true){
        $(ele).closest("td").html(ev.unread_docs);
      }else{
        AlertMessage.show("danger", ev.message);
      }
      Proceduresync.hide_loading();
    });
  },

  render_checkbox: function(data){
    $('#optionsCheckboxAll')[0].checked = false;
    return '<input class="icheck square-blue"  name="optionsCheckbox" type="checkbox" value="'+data+'">';
  },

  render_unread_docs: function(data, type, full){
    var new_data = data;
    if(full.unread_docs_length > 3){
      new_data += ", " + '<a href="'+full.load_more_unread_docs_url+'" data-uid="'+full.id+'" class="load-more-unread-docs">More</a>';
    }
    return new_data;
  },

  render_active: function(data){
    if(data){
      return '<li class="fa fa-fw fa-circle text-success"></li>';
    }else{
      return '<li class="fa fa-fw fa-circle text-danger"></li>';
    }
  },

  render_edit: function(data, type, full){
    editString = '<a href="' + data + '" class="text-muted"><i class="fa fa-pencil-square-o fa-lg"></i></a>';

    if(!full.has_perm){
      editString = "";
    }

    if(full.can_mark_all_as_read){
      editString += '<a href="' + full.mark_all_as_read_url + 
        '" class="text-muted left-5 mark-all-as-read" title="Mark All Read"><i class="fa fa-file-text-o fa-lg"></i></a>';
    }

    return editString;
  },

  downLoad_csv: function(url){
    var self = this;
    if (typeof url == "undefined"){
      url = "/users/export_csv.csv";
    }

    Proceduresync.show_loading();

    sort = self.users_table.dataTable().fnSettings().aaSorting;

    $.fileDownload(url, {
      httpMethod: "GET",
      data: {
        sort_column: sort[0][0],
        sort_dir : sort[0][1],
        search: self.users_table.attr("data-search"),
        ids : ProceduresyncTable.getSelectedIds(self.users_table)
      }
    })

    Proceduresync.hide_loading();
  },

  init_devices_page: function(){
    var table = this.devices_page.find("#table-user-devices");

    if(table.length < 0){
      return;
    }

    var self = this;

    var columns = [
      { "sTitle": I18n.t("user.devices.columns.name"),
        "sWidth": "15%",
        "mData": "name"
      },
      { "sTitle": I18n.t("user.devices.columns.os_version"),
        "sWidth": "15%",
        "mData": "os_version"
      }
    ];

    if(table.attr("data-is-owner") == "true"){
      columns.push({ "sTitle": "",
        "sWidth": "10%",
        "bSortable": false,
        "sClass": "text-center",
        "mData": "remote_wipe_device_url",
        "mRender": function(data, type, full){
          var remove_icon = '<a id="' + full.id + '" href="' + data + '" class="text-muted remote-wipe-device" data-uid="' + 
            full.id + '" data-device-name="' + full.name + '" title="' + I18n.t("user.devices.remote_wipe.title") + '"><i class="fa fa-trash-o fa-lg"></i></a>';

          var sent_notification_icon = '<a id="' + full.id + '" href="' + full.sent_test_notification_url + '" class="text-muted sent-test-notification left-5" data-uid="' + 
            full.id + '" data-device-name="' + full.name + '" title="' + I18n.t("user.devices.sent_notification.title") + '"><i class="fa fa-bell fa-lg"></i></a>';

          return remove_icon + sent_notification_icon;
        }
      });
    }

    table.dataTable({
      sDom: 'rt<"#tbfoot"<"row"<"col col-lg-12">>>',
      "bInfo": true,
      "bProcessing": false,
      "bServerSide": true,
      "bAutoWidth": false,
      "aaSorting": [[ 1, "asc" ]],
      "aoColumns": columns,
      "iDisplayLength": 1000,
      "oLanguage": {
        "sEmptyTable": I18n.t("user.devices.table.no_result"),
      },
      "sAjaxSource": table.attr("data-url")
    });

    $(window.document).delegate(".remote-wipe-device", "click", function(e){
      e.preventDefault();
      var link = this;

      bootbox.confirm(I18n.t("user.devices.confirm_wipe", {name: $(this).attr("data-device-name")}), function(result) {
        if (result == true) {
          self.remote_wipe_device(link);
        }
      });

      return false;
    });

    $(window.document).delegate(".sent-test-notification", "click", function(e){
      e.preventDefault();
      var link = this;

      bootbox.confirm(I18n.t("user.devices.confirm_sent_test_notification", {name: $(this).attr("data-device-name")}), function(result) {
        if (result == true) {
          self.sent_test_notification(link.href);
        }
      });

      return false;
    });
  },

  remote_wipe_device: function(ele){
    var self = this;

    Proceduresync.show_loading();

    $.ajax(ele.href, {
      type: 'POST',
      data: {}
    }).done(function(ev){
      if(ev.success == true){
        self.devices_page.find("#table-user-devices").dataTable().fnReloadAjax();

        AlertMessage.show("success", ev.message);
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  * Sent test notification to a device
  **/
  sent_test_notification: function(url){
    var self = this;

    Proceduresync.show_loading();

    $.ajax(url, {
      type: 'POST',
      data: {}
    }).done(function(ev){
      if(ev.success == true){
        AlertMessage.show("success", ev.message);
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  },

  /**
  * Have an action in the Admin for the super user: 
  *  "Mark All Read" for a specific user. This will mark that users accountable documents as read.
  **/
  mark_all_as_read: function(ele){
    var self = this;

    Proceduresync.show_loading();

    $.ajax(ele.href, {
      type: 'POST',
      data: {}
    }).done(function(ev){
      if(ev.success == true){
        self.users_table.dataTable().fnReloadAjax();

        AlertMessage.show("success", ev.message);
      }else{
        AlertMessage.show("danger", ev.message);
      }

      Proceduresync.hide_loading();
    });
  }
}


$(function() {
  User.init();
});