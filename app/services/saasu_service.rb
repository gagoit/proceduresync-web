class SaasuService < BaseService
  extend ActionView::Helpers::TextHelper

  BASE_URI = "https://api.saasu.com/"

  #Development
  # File ID: 55575
  # Web Services Access Key : F31DCE091D8446738C00CC6D07D7305E
  SAASU_CONFIG = HashWithIndifferentAccess.new YAML.load(File.read(Rails.root.join('config/saasu.yml')))[Rails.env]

  BASE_PARAMS = {
    "wsaccesskey" => SAASU_CONFIG[:wsaccesskey],
    "fileid" => SAASU_CONFIG[:fileid]
  }

  #Production
  # File ID: 45132
  # Web Services Access Key : 4E35E0C3F09E40D1B4B7AA2E85D26AC2

  ##
  # Post invoice
  # https://api.saasu.com/Help/Api/POST-invoice-optionalargs
  ##
  def self.create_invoice(comp, num_users = nil, users_url = "", payment_result = {charged: false}, calculate_for_time = nil)
    curr_time = Time.now.utc
    calculate_for_time ||= curr_time.advance(months: -1)
    
    month = calculate_for_time.month
    year = calculate_for_time.year

    num_users ||= comp.users.active.count

    invoice = comp.invoices.new({month: month, year: year})

    invoice.active_users_url = users_url
    invoice.num_of_active_users = num_users
    invoice.price_per_user = comp.price_per_user
    invoice.total_amount = invoice.num_of_active_users * comp.price_per_user
    invoice.transaction_date = curr_time.strftime("%Y-%m-%dT%T")

    invoice.summary = "Proceduresync Usage Fees #{calculate_for_time.strftime('%B %Y')} (#{pluralize(invoice.num_of_active_users, 'User')})"

    payment_count = 1
    if payment_result[:charged]
      invoice.amount_paid = invoice.total_amount
      invoice.payment_status = "paid"
      invoice.amount_owed = 0

      quick_payment = {
        "DatePaid" => curr_time.strftime("%Y-%m-%d"),
        "BankedToAccountId" => SAASU_CONFIG[:bank_account_id],
        "Amount" => invoice.total_amount,
        "Summary" => invoice.summary
      }
    else
      invoice.amount_paid = 0
      invoice.payment_status = "unpaid"
      invoice.amount_owed = invoice.total_amount
      quick_payment = nil
      payment_count = 0
    end

    begin
      saasu_invoice = {
          "LineItems" =>  [
            {
              "Id" => SAASU_CONFIG[:item_id],
              "Description" => invoice.summary,
              "AccountId" =>  nil,
              "TaxCode" =>  "G1",
              "TotalAmount" =>  invoice.total_amount,
              "Quantity" =>  invoice.num_of_active_users,
              "UnitPrice" =>  invoice.price_per_user,
              "PercentageDiscount" =>  0.0,
              "InventoryId" => SAASU_CONFIG[:item_id],
              "Tags" =>  [],
              "Attributes" =>  [],
              "_links" =>  []
            }
          ],
          "NotesInternal" =>  nil,
          "NotesExternal" =>  nil,
          "TemplateId" =>  nil,
          "SendEmailToContact" => true,
          "QuickPayment" =>  quick_payment,
          "TransactionId" =>  56073104,
          "LastUpdatedId" =>  nil,
          "Currency" =>  invoice.currency,
          "InvoiceNumber" => "<Auto Number>",
          "InvoiceType" =>  "Tax Invoice",
          "TransactionType" =>  "S",
          "Layout" =>  "I",
          "Summary" =>  invoice.summary,
          "TotalAmount" =>  invoice.total_amount,
          "TotalTaxAmount" =>  0.0,
          "IsTaxInc" =>  true,
          "AmountPaid" =>  invoice.amount_paid,
          "AmountOwed" =>  invoice.amount_owed,
          "FxRate" =>  1.0,
          "AutoPopulateFxRate" =>  false,
          "RequiresFollowUp" =>  false,
          "SentToContact" =>  nil,
          "TransactionDate" =>  invoice.transaction_date,
          "BillingContactId" =>  comp.saasu_contact_id,
          "BillingContactFirstName" =>  nil,
          "BillingContactLastName" =>  nil,
          "BillingContactOrganisationName" =>  nil,
          "ShippingContactId" =>  nil,
          "ShippingContactFirstName" =>  nil,
          "ShippingContactLastName" =>  nil,
          "ShippingContactOrganisationName" =>  nil,
          "CreatedDateUtc" =>  invoice.transaction_date,
          "LastModifiedDateUtc" =>  invoice.transaction_date,
          "PaymentStatus" =>  invoice.payment_status,
          "DueDate" =>  nil,
          "InvoiceStatus" =>  nil,
          "PurchaseOrderNumber" =>  nil,
          "PaymentCount" =>  payment_count,
          "Tags" =>  [],
          "_links"=>[]
        }

      unless comp.invoice_email.blank?
        saasu_invoice["EmailMessage"] =  {
            "from" => "team@appiphany.com.au",
            "to" => comp.invoice_email,
            "subject" => invoice.summary,
            "body" => "This is #{invoice.summary}"
          }
      end

      response = HTTParty.post("#{BASE_URI}/invoice?#{BASE_PARAMS.to_query}", :body => saasu_invoice.to_json, :headers => { 'Content-Type' => 'application/json' })

      puts response.inspect
      
      invoice.saasu_response = response.to_s

      if response.response.code.to_s == "200"
        body = ActiveSupport::JSON.decode(response.body)

        #store invoice in db
        invoice.invoice_id = body["InsertedEntityId"]
        invoice.invoice_number = body["GeneratedInvoiceNumber"]

        invoice.save

        download_invoice_pdf(comp, invoice)
      else
        invoice.success = false
        invoice.save

        BaseService.notify_or_ignore_error(Exception.new("Can not create invoice in Saasu for company #{comp.id}"))
        
        #Try to create invoice later
        SaasuService.delay(run_at: 10.minutes.from_now).create_invoice(comp, num_users, users_url, payment_result, calculate_for_time)
      end
    rescue Exception => e
      BaseService.notify_or_ignore_error(Exception.new("Can not create invoice in Saasu for company #{comp.id}: #{e.message}"))
    end
  end


  ##
  # Download invoice pdf
  # https://api.saasu.com/Help/Api/POST-invoice-optionalargs
  # use old API (http://help.saasu.com/api/)
  # https://secure.saasu.com/webservices/rest/r1/invoice?wsaccesskey=13798421b3f24679acdc813a0ae28a78&FileUid=56070&uid=57173968&format=pdf
  ##
  def self.download_invoice_pdf(comp, invoice)

    begin
      file_name = "tmp/invoice_#{invoice.invoice_id}.pdf"

      url = "https://secure.saasu.com/webservices/rest/r1/invoice"

      query = {
        wsaccesskey: BASE_PARAMS["wsaccesskey"],
        FileUid: BASE_PARAMS["fileid"],
        format: "pdf",
        uid: invoice.invoice_id
      }

      open(file_name, 'wb') do |file|
        file << open( "#{url}?#{query.to_query}").read
      end

      #Upload to the S3 and store url
      path_on_s3 = ["invoices", "#{invoice.month}-#{invoice.month}", comp.id.to_s]
      invoice.invoice_pdf_url = upload_file_to_s3(file_name, {path_on_s3: path_on_s3})
      invoice.save(validate: false)

      invoice.invoice_pdf_url
    rescue Exception => e
      BaseService.notify_or_ignore_error(e)
    end
  end
end