/**
* Device::Session module
**/
var DeviseSession = {
  /**
  * #login_page
  **/
  init: function(){
    this.login_page = $("#login_page");

    this.login_form = this.login_page.find("form#new_user");

    this.terms_and_conditions = this.login_page.find("#terms_and_conditions");

    this.init_events();
  },

  /**
  * 
  **/
  init_events: function(){
    var self = this;

    if(self.login_page.length > 0){
      self.sign_in_form_validation();

      self.login_form.submit(function(e){
        if($(this).valid()){
          if(self.login_page.attr("data-accept") == "1"){
            return true;
          }else{
            self.login_page.attr("data-click-login", "1");
            var check_login_url = self.login_page.attr("data-check-login-url");

            $.ajax(check_login_url, {
              type: 'GET',
              data: {
                email: self.login_form.find("#user_email").val()
              }
            }).done(function(ev){
              if(ev.success){
                if(ev.has_logged_in){
                  self.login_page.attr("data-accept", "1");
                  self.login_form.submit();
                }else{
                  self.terms_and_conditions.modal();
                  self.terms_and_conditions.find("#do-not-accept").show();
                  self.terms_and_conditions.find("#accept").show();
                }
              }else{
                AlertMessage.show("danger", ev.message);
              }
            });

            return false;
          }
        }else{
          return false;
        }
      });

      /** Terms & Conditions **/
      /** Show modal **/
      self.login_page.find("#show-terms-and-conditions").click(function(e){
        e.preventDefault();
        self.terms_and_conditions.modal();
        self.terms_and_conditions.find("#do-not-accept").hide();
        self.terms_and_conditions.find("#accept").hide();

        return false;
      });

      /** Do not Accept **/
      self.terms_and_conditions.find("#do-not-accept").click(function(e){
        e.preventDefault();

        self.login_page.attr("data-accept", "0");
        self.terms_and_conditions.modal("hide");
      });

      /** Accept **/
      self.terms_and_conditions.find("#accept").click(function(e){
        e.preventDefault();

        self.login_page.attr("data-accept", "1");
        self.terms_and_conditions.modal("hide");

        if(self.login_page.attr("data-click-login") == "1"){
          self.login_page.attr("data-click-login", "0");
          self.login_form.submit();
        }
      });

      self.terms_and_conditions.on("shown.bs.modal", function(){
        self.init_box_view_for_terms_and_conditions();
      }).on("hide.bs.modal", function(){
        
      });

      /** Incase user click on auto login link, and user has never logged in system, -> show terms and conditions modal **/
      var url = window.location.href;
      if(url.indexOf("password=")){
        self.login_page.find("#user_password").val(url.split("password=")[1]);
        self.login_form.submit();
      }
    }
  },

  /**
  * 
  **/
  sign_in_form_validation: function(){
    this.login_form.validate({
        highlight: function (element) {
            jQuery(element).closest('.form-group').removeClass('has-success').addClass('has-error');
        },
        success: function (element) {
            jQuery(element).closest('.form-group').removeClass('has-error');
        },
        rules: {
          "user[email]": {
            required: true,
            email: true
          },
          "user[password]": {
            required: true
          }
        },
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

  init_box_view_for_terms_and_conditions: function(){
    var self = this;

    if(ie < Proceduresync.OLD_IE_VERSION){
      self.init_box_view_for_terms_and_conditions_ie8();
      return;
    }

    var pdf_view = self.terms_and_conditions.find(".pdf-viewer");
    if(pdf_view.length == 0){
      return;
    }

    self.terms_and_conditions.find(".pdf-viewer-ie8").remove();

    var url = pdf_view.attr("data-url");

    var viewer = Crocodoc.createViewer('.pdf-viewer', {
      url: url,
      layout: Crocodoc.LAYOUT_VERTICAL_SINGLE_COLUMN 
    });

    viewer.load();

    //set height of Box-View
    viewer.on("ready", function(event){
      self.set_height_box_view(pdf_view);
    });
  },

  init_box_view_for_terms_and_conditions_ie8: function(){
    var self = this;

    var pdf_view = self.terms_and_conditions.find(".pdf-viewer-ie8");
    if(pdf_view.length == 0){
      return;
    }

    self.terms_and_conditions.find(".pdf-viewer").remove();

    self.set_height_box_view(pdf_view);
  },

  /** 
  *
  **/
  set_height_box_view: function(viewer_div){
    var self = this;
    var view = Proceduresync.getViewPort();
    var other_height = 0;

    if(self.terms_and_conditions.find("#do-not-accept").is(":visible")){
      other_height += self.terms_and_conditions.find("#do-not-accept").height();
    }

    if(self.terms_and_conditions.find("#accept").is(":visible")){
      other_height += self.terms_and_conditions.find("#accept").height();
    }

    viewer_div.height( view.height - 250 - other_height);

    if(view.width < 768){
      viewer_div.closest(".modal-dialog").width( view.width * 0.85 );
    }else{
      viewer_div.closest(".modal-dialog").width( view.width * 0.75 );
    }
  }
}


$(function() {
  DeviseSession.init();
});