class String
  # Generates a string of n length made up of a-z0-9 chars.
	def self.generate_key(type = :all, length = 255)
		if type == :all
			chars = ('A'..'Z').to_a + ('a'..'z').to_a + (0..9).to_a
		elsif type == :number
			chars = (0..9).to_a
		else
			chars = ('A'..'Z').to_a + ('a'..'z').to_a
		end
		
		chars_length = chars.length
		key = []
		1.upto(length) {|i| key << chars.fetch(rand(chars_length))}
		key.join
	end

	##
	# Check String end with str or not
	##
	def end_with(str)
		begin
			i = self.length - str.length
			self[i..self.length] == str
		rescue Exception => e
			false
		end
	end

  def encode_signs
    signs = {'+' => "%2B", '=' => "%3D", '?' => '%3F', '@' => '%40',
      '$' => '%24', '&' => '%26', ',' => '%2C', '/' => '%2F', ':' => '%3A',
      ';' => '%3B', '?' => '%3F'}
    signs.keys.each do |key|
      self.gsub!(key, signs[key])
    end
    self
  end

  # escape characters: " * / : < > ? \ | -
  # https://d2l.custhelp.com/app/answers/detail/a_id/1473/~/special-characters-in-file-%26-folder-names
  def naming_file_and_folder(replacement_char = nil)
    pattern = /(\"|\*|\/|\:|\<|\>|\?|\\|\||\-)/
    replacement_char ||= "_"

    self.gsub(pattern){|match| replacement_char}
  end

  def escape_characters(replacement_char = nil)
    pattern = /(\'|\"|\.|\*|\/|\-|\\|\)|\$|\+|\(|\^|\?|\!|\~|\`|\=|\||\:|\<|\>)/
    replacement_char ||= "_"

    self.gsub(pattern){|match| replacement_char}
  end
end