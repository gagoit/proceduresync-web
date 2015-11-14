class Invoice
  include Mongoid::Document
  include Mongoid::Timestamps

  field :month, type: Integer
  field :year, type: Integer

  field :num_of_active_users, type: Integer
  field :price_per_user, type: Float
  field :total_amount, type: Float

  field :active_users_url, type: String
  field :transaction_id, type: Integer
  field :currency, type: String, default: "AUD"
  field :invoice_number, type: String, default: "<Auto Number>"
  field :summary, type: String
  field :transaction_date, type: String

  field :amount_paid, type: Float
  field :payment_status, type: String
  field :amount_owed, type: Float

  field :invoice_id, type: Integer #id in Saasu
  field :invoice_pdf_url, type: String #url to the pdf version

  field :saasu_response, type: String
  field :success, type: Boolean, default: true

  belongs_to :company

  validates_presence_of :month, :year, :company_id
  #validates_uniqueness_of :month, scope: [:company_id, :year]
end