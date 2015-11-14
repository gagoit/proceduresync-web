CAMPAIGNS = HashWithIndifferentAccess.new YAML.load(File.read(Rails.root.join('config/campain_monitor.yml')))[Rails.env]

#Dev : https://longvuong.createsend.com
#Pro :