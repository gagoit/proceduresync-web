var AlertMessage = {
  /**
    status: accept "success, warning, info, danger"
  **/
  init: function(status, content){
    string = '<div class="alert alert-block alert-'+status+'"><button data-dismiss="alert" class="close" type="button">×</button><p>'+content+'</p></div>';
    return string;
  },
  show: function(status, content, div){
    var self = this;

    if(typeof div == "undefined"){
      div = $('#alert-msg');
    }

    div.html(self.init(status, content));
    $('html, body').scrollTop(div.position().top);
    self.auto_hide();
  },
  auto_hide: function(){
    if($(".alert").length > 0){
      $(".alert").delay(5000).fadeOut("slow", function () { $(this).remove();});
    }
  }
}

$(function() {
  AlertMessage.auto_hide();
});