class File
  def each_chunk(chunk_size=1*1024)
    yield read(chunk_size) until eof?
  end
end

class XOREncrypt
  def self.encrypt_decrypt(inputfile, password, outputfile, jump_byte = 1024)
    input = File.open(inputfile,"r")
    pass_array = password.split(//).map { |e| e.ord }
    output = File.new(outputfile,"w")
    
    file_size = input.size
    length = 1*jump_byte + pass_array.length
    encrypted_size = 0
    
    open(inputfile, "rb") do |f|
      f.each_chunk(length) do |chunk|
        
        if encrypted_size >= (file_size - pass_array.length)
          j = 0
          while c = chunk[j]
            output.print(c.force_encoding('UTF-8'))
            j += 1
          end

          next 
        end

        encrypted_size += length
        i = 0
        j = 0
        
        while c = chunk[j]
          c_new = c.ord
          if i > (pass_array.size - 1)
            output.print(c.force_encoding('UTF-8'))
          else
            pass_char = pass_array[i]
            xor = c_new ^ pass_char
            output.print(xor.chr.force_encoding('UTF-8'))
            i+=1
          end
          j += 1
        end
        
      end
    end
    
    input.close
    output.close
  end
end