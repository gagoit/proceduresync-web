module CompanyHelper
  
  def assign_doc_text(company)
    text = if company.is_hybrid?
      "The parts of the organisation that the document will be assigned to."
    elsif company.is_advanced?
      "Select which areas you would like to send this document for accountability approval."
    else
      "Select which users (if any) are read receipt accountable for this document."
    end

    "#{text} Click the section names to expand."
  end

  def company_structure(company)
    company.table_structure(["company"])
  end

  # Company paths in Add/Edit User form
  ##
  def company_paths_for_select(user, comp)
    paths = comp.company_paths

    [["", ""]].concat(paths)
  end

  # Company paths in Add/Edit User form
  ##
  def company_paths_for_select_areas_in_reports(user, comp)
    paths = comp.company_paths

    [[I18n.t("reports.form.areas.options.select_users"), ReportSetting::SELECT_USERS_TEXT]].concat(paths)
  end
  
end
