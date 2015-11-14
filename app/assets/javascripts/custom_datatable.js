/**
* Custom datatable
**/

$.extend( true, $.fn.dataTable.defaults, {
  "autoWidth": false
} );

// $(document).delegate(".dataTable", "processing.dt", function ( e, settings, processing ) {
//   if(processing){
//     Proceduresync.show_loading();
//   }else{
//     Proceduresync.hide_loading();
//   }
// });