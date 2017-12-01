var TestSite = {
  init: function(){
    // initEvents
    this.initEvents();
  },

  initEvents: function(){
    var self = this;

    if($("#test_box_view").length > 0){
      var testBoxViewPage = $("#test_box_view");

      self.init_box_view($("#test_box_view"));

      $("#view_with_js_plugin").click(function(e){
        e.preventDefault();
        testBoxViewPage.find(".view_type").removeClass("active");
        $(this).addClass("active");

        testBoxViewPage.find(".pdf-viewer").show();
        testBoxViewPage.find(".pdf-viewer-ie8").hide();
        return false;
      })

      $("#view_with_iframe").click(function(e){
        e.preventDefault();
        testBoxViewPage.find(".view_type").removeClass("active");
        $(this).addClass("active");

        if(!testBoxViewPage.find(".pdf-viewer-ie8").data('hasInit')){
          self.init_new_box_view_for_ie8(testBoxViewPage);
        }

        testBoxViewPage.find(".pdf-viewer").hide();
        testBoxViewPage.find(".pdf-viewer-ie8").show();
        return false;
      })
    }
  },

  /**
  * Init box view for document
  **/
  init_box_view: function(parent_div){
    var self = this;

    //Switch to new box
    if(parent_div.data("newBox")){
      self.init_new_box_view(parent_div);
      return;
    }

    var pdf_view = parent_div.find(".pdf-viewer");
    if(pdf_view.length == 0){
      return;
    }

    parent_div.find(".pdf-viewer-ie8").hide();
    var url = pdf_view.attr("data-url");

    try{
      var viewer = Crocodoc.createViewer('.pdf-viewer', {
        url: url,
        layout: Crocodoc.LAYOUT_VERTICAL_SINGLE_COLUMN 
      });
      viewer.load();

      //set height of Box-View
      var view = Proceduresync.getViewPort();
      var total_top = Proceduresync.get_top_height();
      $(".pdf-viewer").height(view.height - total_top - 20);
    }catch(e){
    }

    $(".crocodoc-viewport").niceScroll({
      cursorcolor: "#357ebd"
    });
  },

  /**
  * Init box view for document
  **/
  init_box_view_for_ie8: function(parent_div){
    var self = this;

    var pdf_view = parent_div.find(".pdf-viewer-ie8");
    if(pdf_view.length == 0){
      return;
    }

    parent_div.find(".pdf-viewer").hide();

    //set height of Box-View
    var view = Proceduresync.getViewPort();
    var total_top = Proceduresync.get_top_height();
    $(".pdf-viewer-ie8").height(view.height - total_top - 20);
    $(".pdf-viewer-ie8").data('hasInit', true);
  },

  /**
  * Init new box view for document
  **/
  init_new_box_view: function(parent_div){
    var self = this;

    var pdf_view = parent_div.find(".pdf-viewer");
    if(pdf_view.length == 0){
      self.init_new_box_view_for_ie8(parent_div);
      return;
    }

    parent_div.find(".pdf-viewer-ie8").hide();
    var fileId = pdf_view.data("docBoxId") + "";
    var fileAccessToken = pdf_view.data("fileAccessToken");

    try{
      var preview = new Box.Preview();
      preview.addListener('load', function(data){
        //set height of Box-View
        var view = Proceduresync.getViewPort();
        var total_top = Proceduresync.get_top_height();
        $(".pdf-viewer").height(view.height - total_top - 20);
      });

      preview.show(fileId, fileAccessToken, {
      // preview.show('93392244621', 'EqFyi1Yq1tD9mxY8F38sxDfp73pFd7FP', {
        container: '.pdf-viewer',
        showDownload: true
      });
    }catch(e){
    }
  },

  /**
  * Init new box view for document
  **/
  init_new_box_view_for_ie8: function(parent_div){
    var self = this;

    var pdf_view = parent_div.find(".pdf-viewer-ie8");
    if(pdf_view.length == 0){
      return;
    }

    parent_div.find(".pdf-viewer").hide();

    //set height of Box-View
    var view = Proceduresync.getViewPort();
    var total_top = Proceduresync.get_top_height();
    $(".pdf-viewer-ie8").height(view.height - total_top - 20);
    $(".pdf-viewer-ie8").data('hasInit', true);
  },
}

$(function() {
  TestSite.init();
});