Proceduresync.hide_loading();

AlertMessage.show("<%= @result[:success] ? 'success' : 'danger' %>", "<%= @result[:message]%>");

<% if @result[:need_remove_for_approval_nav] %>
  $("#left_nav_items .to_approve").remove();
<% elsif @result[:need_reload] %>
	Proceduresync.redirect_to();
<%end%>