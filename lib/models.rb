require 'data_mapper'

require 'csv'

DataMapper.setup(:default, 'postgres://casserver:123456@127.0.0.1:5432/hpuaccount')

class User
	include DataMapper::Resource

	#attr_accessor :password, :password_confirmation

	property :id, Serial
	property :email, String,     :required => true, :unique => true
	
	property :created_at, Date 
	property :status, Integer	
	property :password, Text	
   	property :masinhvien, String
   	property :hovaten, String
	property :gioitinh, String
	property :ngaysinh, Date
	property :diachi, Text	
	property :contact, String
	property :dienthoai, String	
	property :role, Integer
    has n, :activations    
end
class Activation
	include DataMapper::Resource
	property :id, Serial
	property :token, String
	property :created_at, Date	
	property :description, Text
	property :status, Integer
	belongs_to :user 
end

@@teacher = []
path = File.dirname(__FILE__) + '/emails.csv'
CSV.foreach(path) do |row|    
    str = row[0].to_str.strip
    @@teacher << str    
end

DataMapper.finalize
DataMapper::Model.raise_on_save_failure = true 

DataMapper.auto_upgrade!
#DataMapper.auto_migrate!
