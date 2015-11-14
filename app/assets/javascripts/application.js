// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require libs/jquery
//= require libs/jquery_ujs
//= require plugins/jquery_ie8_fixing
//= require plugins/icheck
//= require icheck
//= require plugins/jquery.validate
//= require jquery.remotipart
//= require plugins/jquery-datatables/jquery.dataTables
//= require plugins/jquery-datatables/dataTables.bootstrap
//= require plugins/jquery-datatables/dataTables.tableTools
//= require plugins/jquery-datatables/dataTables.tableTools
//= require plugins/jquery-datatables/datatable-responsive
//= require custom_datatable
//= require plugins/bootstrap-datepicker/moment
//= require plugins/bootstrap-datepicker/bootstrap-datepicker
//= require plugins/bootstrap-datepicker/bootstrap-datetimepicker
//= require jquery-fileupload/basic
//= require jquery-fileupload/vendor/tmpl
//= require plugins/s3_direct_upload
//= require i18n
//= require i18n/translations
//= require_tree .

$.fn.dataTableExt.oApi.fnReloadAjax = function(oSettings, sNewSource, fnCallback, bStandingRedraw) {
  if (sNewSource !== undefined && sNewSource !== null) {
    oSettings.sAjaxSource = sNewSource;
  }

  // Server-side processing should just call fnDraw
  if (oSettings.oFeatures.bServerSide) {
    this.fnDraw();
    return;
  }

  this.oApi._fnProcessingDisplay(oSettings, true);
  var that = this;
  var iStart = oSettings._iDisplayStart;
  var aData = [];

  this.oApi._fnServerParams(oSettings, aData);

  oSettings.fnServerData.call(oSettings.oInstance, oSettings.sAjaxSource, aData, function(json) {
    /* Clear the old information from the table */
    that.oApi._fnClearTable(oSettings);

    /* Got the data - add it to the table */
    var aData = (oSettings.sAjaxDataProp !== "") ?
      that.oApi._fnGetObjectDataFn(oSettings.sAjaxDataProp)(json) : json;

    for (var i = 0; i < aData.length; i++) {
      that.oApi._fnAddData(oSettings, aData[i]);
    }

    oSettings.aiDisplay = oSettings.aiDisplayMaster.slice();

    that.fnDraw();

    if (bStandingRedraw === true) {
      oSettings._iDisplayStart = iStart;
      that.oApi._fnCalculateEnd(oSettings);
      that.fnDraw(false);
    }

    that.oApi._fnProcessingDisplay(oSettings, false);

    /* Callback user function - for event handlers etc */
    if (typeof fnCallback == 'function' && fnCallback !== null) {
      fnCallback(oSettings);
    }
  }, oSettings);
};