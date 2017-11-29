class UrlUtility

  def self.get_file_extension url
    begin
      URI.encode(url).split("?").first.split(".").last
    rescue => e
      nil
    end
  end


  def self.get_file_name url
    begin
      URI.encode(url).split("?").first.split("/").last
    rescue => e
      nil
    end
  end
end