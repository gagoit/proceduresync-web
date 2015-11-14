/**
* Document Settings module
**/
var DocumentSettings = {
  /**
  *
  **/
  init: function(){
    this.document_settings_page = $("#document_settings_page");

    if(this.document_settings_page.length > 0){
      this.document_settings_page.find("form").submit(function(e){
        Proceduresync.show_loading();
      });
    }
  },
}

$(function() {
  DocumentSettings.init();
});