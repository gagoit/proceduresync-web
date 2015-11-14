/**
* Device::Password module
**/
var DevisePassword = {
  /**
  * #reset_page
  **/
  init: function(){
    this.reset_page = $("#reset_page");

    this.reset_form = this.reset_page.find("form");
    this.init_events();
  },

  /**
  * 
  **/
  init_events: function(){
    var self = this;

    if(self.reset_page.length > 0){
      self.reset_form_validation();

      $("#password_reset_modal").find("button").click(function(e){
        window.location = $(this).attr("data-url");
      });
    }
  },

  /**
  * 
  **/
  reset_form_validation: function(){
    this.reset_form.validate({
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
  }
}


$(function() {
  DevisePassword.init();
});