Proceduresync.hide_loading();

<% if @message[:doc_id]%>
  $('#double_title_confirm #accept').attr('href', '<%= edit_document_path(@message[:doc_id])%>');
  $('#double_title_confirm').modal('show');
<%else%>
  AlertMessage.show("<%= @message[:success] ? 'success' : 'danger' %>", "<%= @message[:message]%>");
  
  Document.upload_document_callback();
<%end%>

<% if @message[:success] %>
  <% if @message[:version_changed] %>
    Document.reload_versions_table();
  <%end%>

  Document.logs_table.dataTable().fnReloadAjax();
<%end%>