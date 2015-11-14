/**
* Common functions for table in Proceduresync
**/
var ProceduresyncTable = {

  checkBoxAllClick: function(table){
    if(ie < Proceduresync.OLD_IE_VERSION){
      this.checkBoxAllClick_ie8(table);
      return;
    }
    
    table.find('#optionsCheckboxAll').on('ifClicked', function() {
      $(this).iCheck('toggle');

      if(this.checked){
        table.find('input[name="optionsCheckbox"]').iCheck('check');
      }else{
        table.find('input[name="optionsCheckbox"]').iCheck("uncheck");
      }
    });

    if(table.find('input[name="optionsCheckbox"]').length == 0){
      table.find('#optionsCheckboxAll').iCheck('disable');
    }else{
      this.rowCheckboxClick(table);
    }
  },

  /** 
  * in IE8 we don't use iCheck
  **/
  checkBoxAllClick_ie8: function(table){
    $(document).on('click', '#optionsCheckboxAll', function() {
      table.find('input[name="optionsCheckbox"]').prop('checked', this.checked);
    });

    if(table.find('input[name="optionsCheckbox"]').length == 0){
      table.find('#optionsCheckboxAll').attr('disabled', true);
    }else{
      this.rowCheckboxClick_ie8(table);
    }
  },

  getSelectedIds: function(table){
    var selectedIds = [];
    table.find('input[name="optionsCheckbox"]:checked').each(function(index, e){ selectedIds.push(e.value) });
    
    return selectedIds;
  },

  rowCheckboxClick: function(table){
    if(ie < Proceduresync.OLD_IE_VERSION){
      this.rowCheckboxClick_ie8(table);
      return
    }

    table.find('input[name="optionsCheckbox"]').on('ifClicked', function(){
      $(this).iCheck('toggle');
      var isAll = (table.find('input[name="optionsCheckbox"]').length == table.find('input[name="optionsCheckbox"]:checked').length);

      if(isAll){
        table.find("#optionsCheckboxAll").iCheck("check");
      }else{
        table.find("#optionsCheckboxAll").iCheck("uncheck");
      }
    })
  },

  /** 
  * 
  **/
  rowCheckboxClick_ie8: function(table){
    $(document).on('click', 'input[name="optionsCheckbox"]', function(){
      var isAll = (table.find('input[name="optionsCheckbox"]').length == table.find('input[name="optionsCheckbox"]:checked').length);

      table.find("#optionsCheckboxAll").prop('checked', isAll);
    });
  }
}