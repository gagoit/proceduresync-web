Proceduresync.hide_loading();

<% if @message[:doc_id]%>
  $('#double_title_confirm #accept').attr('href', '<%= edit_document_path(@message[:doc_id])%>');
  $('#double_title_confirm').modal('show');
<%else%>
  AlertMessage.show("<%= @message[:success] ? 'success' : 'danger' %>", "<%= @message[:message]%>");
<%end%>
<% if @message[:success] %>
  //window.setTimeout(function(){$(location).attr('href',"<%= edit_document_path(@document)%>")}, 1000);
  window.setTimeout(function(){location.reload()}, 1000);
<%end%>