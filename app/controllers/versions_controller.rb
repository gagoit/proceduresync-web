class VersionsController < ApplicationController
  before_filter :authenticate_user!

  before_filter :check_company
  before_filter :check_permission

  def index
    @versions = @document.versions.order_by(:created_at => 'desc')

    if request.xhr?
      return_data = {
        "aaData" => [],
        "iTotalDisplayRecords" => @versions.length,
        "iTotalRecords" => @versions.length
      }

      # parse data
      @versions.each do |version|
        return_data["aaData"] << {
          date: BaseService.time_formated(current_company, version.created_at),
          version: version.version,
          action: {origin_url: version.get_origin_url, pdf_url: download_pdf_document_version_path(@document, version, format: :pdf), version_url: document_version_path(@document, version), box_show: version.box_status == 'done'}
        }
      end

      render :json =>  return_data

      return
    end    
  end  

  # GET /versions/1
  # GET /versions/1.json
  def show
    @version = @document.versions.find(params[:id])
    if @version.box_view_id
      @view_url, @assets_url = @version.get_box_url
    end

    @read_doc = current_user.read_doc?(@document)

    if !@read_doc && !current_user.is_required_to_read_doc?(current_company, @document)
      @read_doc = true
    end

    @can_approve = PermissionService.can_approve_document(current_user, current_company, @document)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @document }
    end
  end

  def download_pdf
    version = @document.versions.find(params[:id])

    folder = "tmp/#{@document.id}-#{Time.now.utc.to_i}"
    file_name = "#{folder}/#{version.id}.pdf"
    file_name_encrypted = "#{folder}/#{@document.title.naming_file_and_folder}.pdf"

    Dir::mkdir(folder) if Dir[folder].empty?

    open(file_name, 'w', encoding: 'ASCII-8BIT') do |f|
      f << open(version.doc_file).read
    end

    #encrypt file
    XOREncrypt.encrypt_decrypt(file_name, version.document.company_id.to_s, file_name_encrypted)

    respond_to do |format|
      format.html
      format.pdf {
        response.headers.delete("Pragma")
        response.headers.delete('Cache-Control')
        send_file file_name_encrypted
      }
    end
  end

  def check_permission
    @document = current_company.documents.find(params[:document_id])

    super(@document)
  end
end