/**
* Common functions for table in Proceduresync
**/
var ProceduresyncTable = {

  checkBoxAllClick: function(table){
    if(ie < Proceduresync.OLD_IE_VERSION){
      this.checkBoxAllClick_ie8(table);
      return;
    }

    var self = this;
    this.selectPageEvent(table);
    
    table.find('#optionsCheckboxAll').on('ifClicked', function() {
      $(this).iCheck('toggle');

      if(this.checked){
        table.find('input[name="optionsCheckbox"]').iCheck('check');
      }else{
        table.find('input[name="optionsCheckbox"]').iCheck("uncheck");
      }

      self.showSelectPage(table, this.checked);
    });

    if(table.find('input[name="optionsCheckbox"]').length == 0){
      table.find('#optionsCheckboxAll').iCheck('disable');
      table.find('.selectPage').remove();
    }else{
      this.rowCheckboxClick(table);
    }
  },

  checkAll: function(table, checked){
    table.find('#optionsCheckboxAll').prop('checked', checked); 
  },

  /** 
  * in IE8 we don't use iCheck
  **/
  checkBoxAllClick_ie8: function(table){
    var self = this;
    this.selectPageEvent(table);

    $(document).on('click', '#optionsCheckboxAll', function(e) {
      table.find('input[name="optionsCheckbox"]').prop('checked', this.checked);

      self.showSelectPage(table, this.checked);
      var checked = this.checked;

      setTimeout(function(){
        self.checkAll(table, checked); 
      }, 10);

      return false;
    });

    if(table.find('input[name="optionsCheckbox"]').length == 0){
      table.find('#optionsCheckboxAll').attr('disabled', true);
      table.find('.selectPage').remove();
    }else{
      this.rowCheckboxClick_ie8(table);
    }
  },

  selectPageEvent: function(table){
    var self = this;

    table.find('#optionsCheckboxAll').closest("th").on('mouseover', function() {
      table.find('.selectPage').addClass("open");
    });

    table.find('.selectPage li a').on('click', function(){
      var value = $(this).data("value");

      if($(this).hasClass("active")){
        self.unSelectPage(table);
      }else{
        self.selectPage(table, value); 
      }

      return false;
    });

    if(ie < Proceduresync.OLD_IE_VERSION){
      table.find('.selectPage .dropdown-toggle').addClass("ie-8");
    }
  },

  showSelectPage: function(table, checked){
    var self = this;
    var checkboxAll = table.find('#optionsCheckboxAll');

    table.find('.selectPage').addClass("open");

    if(checked){
      if(typeof checkboxAll.data("value") == "undefined" || checkboxAll.data("value") == ""){
        self.selectPage(table, "one-page");
      }
    }else{
      self.unSelectPage(table);
    }
  },

  selectPage: function(table, type){
    var checkboxAll = table.find('#optionsCheckboxAll');
    checkboxAll.data("value", type);

    table.find('.selectPage li a').removeClass("active").removeClass("glyphicon").removeClass("glyphicon-ok");
    table.find('.selectPage li a.' + type ).addClass("active glyphicon glyphicon-ok");

    var checkboxEvent = (ie < Proceduresync.OLD_IE_VERSION) ? 'click' : 'ifClicked';

    if(checkboxAll[0] && !checkboxAll[0].checked){
      checkboxAll.trigger(checkboxEvent);
    }
  },

  unSelectPage: function(table){
    var checkboxAll = table.find('#optionsCheckboxAll');

    table.find('.selectPage li a').removeClass("active").removeClass("glyphicon").removeClass("glyphicon-ok");
    checkboxAll.data("value", "");

    var checkboxEvent = (ie < Proceduresync.OLD_IE_VERSION) ? 'click' : 'ifClicked';

    if(checkboxAll[0] && checkboxAll[0].checked){
      checkboxAll.trigger(checkboxEvent);
    }
  },

  getSelectedIds: function(table){
    var selectedIds = [];
    var checkboxAll = table.find('#optionsCheckboxAll');

    if(checkboxAll.data("value") == "all-page"){
      return "all";
    }

    table.find('input[name="optionsCheckbox"]:checked').each(function(index, e){ selectedIds.push(e.value) });
    
    return selectedIds;
  },

  rowCheckboxClick: function(table){
    if(ie < Proceduresync.OLD_IE_VERSION){
      this.rowCheckboxClick_ie8(table);
      return
    }

    var self = this;

    table.find('input[name="optionsCheckbox"]').on('ifClicked', function(){
      $(this).iCheck('toggle');
      var isAll = (table.find('input[name="optionsCheckbox"]').length == table.find('input[name="optionsCheckbox"]:checked').length);

      if(isAll){
        table.find("#optionsCheckboxAll").iCheck("check");
        self.selectPage(table, "one-page");
      }else{
        table.find("#optionsCheckboxAll").iCheck("uncheck");
        self.unSelectPage(table);
      }
    })
  },

  /** 
  * 
  **/
  rowCheckboxClick_ie8: function(table){
    var self = this;

    $(document).on('click', 'input[name="optionsCheckbox"]', function(){
      var isAll = (table.find('input[name="optionsCheckbox"]').length == table.find('input[name="optionsCheckbox"]:checked').length);

      table.find("#optionsCheckboxAll").prop('checked', isAll);

      if(isAll){
        self.selectPage(table, "one-page");
      }else{
        self.unSelectPage(table);
      }
    });
  },

  /**
  * Template for select page/all page on table User/Document
  **/
  selectPageHtmlTemplate: function(){
    return '<div class="dropdown selectPage">' +
                          '<button class="dropdown-toggle" type="button" data-toggle="dropdown">' +
                          '<span class="caret"></span></button>' +
                          '<ul class="dropdown-menu">' +
                            '<li><a class="one-page" href="" data-value="one-page"><span>Select Page</span></a></li>' +
                            '<li><a class="all-page" href="" data-value="all-page"><span>Select All Pages</span></a></li>' +
                          '</ul>' +
                        '</div>';
  },

  /**
  * Get data for actions on table
  * favourite_docs
  * export_csv
  **/
  getDataForAction: function(table){
    var filter = table.data("filter");
    var sort = table.dataTable().fnSettings().aaSorting;
    var sort_column = (sort && sort[0]) ? sort[0][0] : 1;
    var sort_dir = (sort && sort[0]) ? sort[0][1] : "asc";
    var selected_ids = ProceduresyncTable.getSelectedIds(table);
    var search = table.data("search");

    return {
      filter: filter,
      sort_column: sort_column,
      sort_dir : sort_dir,
      search: search,
      ids : selected_ids,
      filter_category_id: table.data("category_id"),
      document_types: table.data("types"),
      order_by_ranking: table.data("order-by-ranking")
    }
  }
}