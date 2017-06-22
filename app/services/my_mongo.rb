class MyMongo

  def self.client
    @client ||= Mongoid.default_client
  end

  def self.database
    @db ||= client.database
  end
end