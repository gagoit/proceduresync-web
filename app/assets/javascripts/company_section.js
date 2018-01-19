var CompanySection = {

  showDeleteModal: function(modal){
    var self = this;
    Proceduresync.show_loading();

    $.ajax(modal.data("loadModalUrl"), {
      type: 'GET',
      data: {
        node_id: modal.data("sectionId"),
        node_type: modal.data("sectionType")
      }
    }).done(function(response){
      if(response.success == true){
        modal.find(".modal-body").html(response.modal_body_html);

        modal.find("#delete_sections_btn").click(function(e){
          self.delete(modal, modal.find("#delete_sections_btn"));
        });

        modal.modal("show");
      }else{
        window.location.reload();
      }

      Proceduresync.hide_loading();
    });
  },

  delete: function(modal, deleteBtn){
    Proceduresync.show_loading();

    $.ajax(deleteBtn.data("url"), {
      type: 'POST',
      data: {
        node_id: modal.data("sectionId"),
        node_type: modal.data("sectionType")
      }
    }).done(function(response){
      if(response.success == true){
        AlertMessage.show("success", response.message);
        window.location.reload();
      }else if(response.reload){
        window.location.reload();
      }else{
        AlertMessage.show("danger", response.message);
        Proceduresync.hide_loading();
      }
    });
  }
}