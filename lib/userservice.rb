# encoding: UTF-8
require 'savon'
require 'celluloid'
require 'email_veracity'
require_relative './workers/mailservice'
#require_relative './models_test'
require_relative './models'
require 'stomp'
require 'redis'
class UserService
	include Celluloid
	def initialize
		@redis = Redis.new(:host => "127.0.0.1", :port => 6384)
		@client = Savon.client(wsdl: "http://10.1.0.238:8082/HPUWebService.asmx?wsdl")		
		#@emailclient = Stomp::Client.open "stomp://localhost:61613"
		@emailclient = Stomp::Connection.open '','',"localhost", 61613, true, {'client-id' => "hpustomp"}
		@ds = getds
	end
	def getds
		client = Savon.client(wsdl: "http://10.1.0.238:8082/HPUWebService.asmx?wsdl")
		response = client.call(:danh_sach_can_bo_giang_vien)
				
		res_hash = response.body.to_hash;
		ls = res_hash[:danh_sach_can_bo_giang_vien_response][:danh_sach_can_bo_giang_vien_result][:diffgram][:document_element][:danh_sach_can_bo_giang_vien];
		return ls
	end
	def checkrealmail(email)
		address = EmailVeracity::Address.new(email)
		return address.valid?
	end
	
	def getemail(msv)	
		return {:code => -3, :email => nil} if msv.blank?	
		begin
			response = @client.call(:thong_tin_sinh_vien) do		
				message(masinhvien: msv)
			end
		
			res_hash = response.body.to_hash
			
			ls = res_hash[:thong_tin_sinh_vien_response][:thong_tin_sinh_vien_result][:diffgram][:document_element];
			if (ls != nil) then 	
				ls = ls[:thong_tin_sinh_vien]					
				return {:code => -1, :email => nil} unless ls[:email].kind_of? String		
				return {:code => 1, :email => (ls[:email].strip if ls[:email].kind_of? String and ls[:email].respond_to?(:strip) and ls.has_key?(:email))}		
			else
				return {:code => -2, :email => nil}
			end
		rescue
			puts "Email error #{ls[:email]}"
			return {:code => -3, :email => nil}
		end
	end
	def getprofile(email, msv)	
		return '' if msv.blank?	
		begin
			user = get_user(email)	  	
			return nil if user == nil
		  	
			response = @client.call(:thong_tin_sinh_vien) do		
				message(masinhvien: msv)
			end
			res_hash = response.body.to_hash
			result = {}
			ls = res_hash[:thong_tin_sinh_vien_response][:thong_tin_sinh_vien_result][:diffgram][:document_element];
			if (ls != nil) then 	
				ls = ls[:thong_tin_sinh_vien]						
				
				result[:hovaten] = "#{ls[:ho_dem].strip} #{ls[:ten].strip}" if ls.has_key?(:ho_dem) and ls.has_key?(:ten) and ls[:ho_dem] and ls[:ten] and ls[:ho_dem].kind_of? String and ls[:ten].kind_of? String
				begin
					ngaysinh = ls[:ngay_sinh].strip if ls.has_key?(:ngay_sinh) and ls[:ngay_sinh].kind_of? String
			        xngaysinh = Date.strptime(ngaysinh, '%d/%m/%Y')
			    rescue
			       puts "ngay sinh ko hop le"
			    end
				result[:ngaysinh] = xngaysinh
				result[:gioitinh] = 1 if ls.has_key?(:gioi_tinh) and ls[:gioi_tinh] and ls[:gioi_tinh].strip == 'Nam' and ls[:gioi_tinh].kind_of? String
				result[:gioitinh] = 0 if ls.has_key?(:gioi_tinh) and ls[:gioi_tinh] and ls[:gioi_tinh].strip == 'Nữ' and ls[:gioi_tinh].kind_of? String
				result[:diachi] = ls[:dia_chi].strip if ls.has_key?(:dia_chi) and ls[:dia_chi] and ls[:dia_chi].kind_of? String
				result[:dienthoai] = ls[:dien_thoai].strip if ls.has_key?(:dien_thoai) and ls[:dien_thoai] and ls[:dien_thoai].kind_of? String
				
				if user 
		  			user.attributes = result
		  			begin 
		  				user.save
		  			rescue
		  				puts "get student profile error"
		  				return nil
		  			end
		  		end
			else

				return nil
			end
		rescue
			return nil
		end
	end
	def checksv(email, msv)	
		begin	
			mail = getemail(msv)
			if mail[:code] == -2 then return {:code => -1, :msg => 'Không tồn tại mã sinh viên'}		
			elsif mail[:code] == -1 then 
				return {:code => -1, :msg => 'Bạn chưa điền Email ở cổng thông tin sinh viên, vui lòng liên hệ phòng Quản trị mạng tầng 2 nhà G'}
			elsif mail[:code] == -3 then 
				return {:code => -1, :msg => 'Internal Server Error'}
			else				
				if  email != mail[:email] then 					
					return {:code => -1, :msg => 'Email bạn cung cấp không trùng với Email trong cổng sinh viên, vui lòng liên hệ phòng Quản trị mạng tầng 2 nhà G'}
				else return {:code => 1, :msg => 'OK'}
				end
			end
		rescue
			return {:code => -1, :msg => 'Internal Server Error'}
		end
	end
	def checkgv(email)		
		begin
			l2 = @ds.select {|l| l[:email] and l[:email].is_a?(String) and l[:email].strip.downcase == email.downcase}
			return false if l2 == nil or l2 and l2.empty? # la can bo nhung ko phai co van
			#l3 = l2[0].to_hash if l2 and l2.length > 0
			#return {} unless l3.has_key?(:ma_nguoi_dung)
			#puts l3[:ma_nguoi_dung].strip if l3.has_key?
			#puts l2[0]["ma_nguoi_dung"].strip
			#return {:result => l3[:ma_nguoi_dung].strip}.to_json
			#return @@teacher.include?(email)
			return true
		rescue Exception => e
			puts e
			return false
		end
	end
	def get_user(email)
		return User.first(:email => email) rescue nil 
	end		
	def get_activated_user(user)
		return user.status == 1 rescue nil
	end
	def confirm_register(token) #tested
		# xac nhan dang ky va kich hoat thanh cong
		# tham so la token
		# result:
		# - code: 1: thanh cong, 0: that bai, -1: qua han
		# thuat toan:
		# - get token tu bang Activation
		# - mo thread moi xu ly tat ca token truoc cua user day
		# - tao token moi va sendmail xac nhan
		begin
			token = token.strip unless token.blank?
			activate_token = Activation.first(:token => token)
			if activate_token then 
				return {:code => -1, :msg => 'Vé đăng ký đã được sử dụng'} if activate_token.status == 1
				if activate_token.created_at + 3*3600*24 <= DateTime.parse(Time.now.to_s) # expire
					return {:code => -1, :msg => 'Thời gian kích hoạt đã quá hạn, vui lòng đăng nhập và sử dụng phần kích hoạt lại trong hồ sơ.'} # expired
				end
				user = activate_token.user
				if user == nil then return {:code => 0, :msg => 'Tài khoản này không tồn tại, vui lòng đăng ký'} end
				if user.status == 0  then 
					if user.role == 1 then
					newmail = getemail(user.masinhvien)					
					return {:code => -1, :msg => 'Vé đăng kí không còn hợp lệ'} if newmail[:code] != 1					
					return {:code => -1, :msg => 'Vé đăng kí không còn hợp lệ'} if newmail[:email] != user.email
					@redis.set("msv:#{user.masinhvien}", user.email)
					end
					user.status = 1 
					activate_token.token = Time.now.to_s
					activate_token.status = 1						
					if user.save and activate_token.save then return {:code => 1, :msg => 'Tài khoản của bạn đã được kích hoạt thành công.'} end
				else
					return {:code => 2, :msg => 'Tài khoản này đã kích hoạt'}
				end
			else
				return {:code => -1, :msg => 'Vé đăng ký không tồn tại'}
			end
		rescue => e
			return {:code => -2, :msg => "error #{e}"}
		end
	end
	def send_confirm(email)
		begin
			email = email.strip unless email.blank?
			user = get_user(email)
			return {:code => -1, :msg => 'Tài khoản này không tồn tại'} if user == nil 
			return {:code => 2, :msg => 'Tài khoản này đã kích hoạt'} if user.status == 1
			user.activations do |act|
				if act then
					act.status = 1
				end
			end
			register_confirm = Activation.new(:token => SecureRandom.hex, :created_at => Time.now, :description => 'Register reconfirmation', :status => 0)			 
			register_confirm.user = user
			if user.save and register_confirm.save then 
				#sm = SendEmail.new({:to => email, :token => register_confirm.token, :reason => 'register'})
				#sm.async.perform
				@emailclient.publish('/topic/hpumail', {:to => email, :token => register_confirm.token, :reason => 'register'}.to_json, {:persistent => 'true'})
				return {:code => 1, :msg => 'Một email kích hoạt đã được gởi đến hòm thư của bạn, vui lòng kiểm tra thư để kích hoạt trong vòng 10 phút nữa.'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error 4'}
		end
	end	
	def changepassword(email, old, p, p2)
		begin
			email = email.strip unless email.blank?
			return {:code => -1, :msg => 'Mật khẩu quá ngắn, phải có ít nhất 6 ký tự'} if (p.length < 6 or p2.length < 6)
			return {:code => -1, :msg => 'Mật khẩu và xác nhận không trùng'} if (p != p2)
			xold = hash_pass(old)
			xp = hash_pass(p)
			user = get_user(email)
			return {:code => -1, :msg => 'Mật khẩu xác nhận không trùng'} if (user[:password] != xold)
			user.password = xp
			if user.save 
				@emailclient.publish('/topic/hpumail', {:to => email, :token => p, :reason => 'resetpassword'}.to_json, {:persistent => 'true'})
				return {:code => 1, :msg => 'Mật khẩu đã cập nhật thành công'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error 0'}
		end
	end
	def resetpassword(email)
		begin			
			email = email.strip unless email.blank?			
			user = get_user(email)
			return {:code => -1, :msg => 'Không tồn tại tài khoản với email này'} unless user
			newpass = generate_password(8)
			user.password = hash_pass(newpass)
			if  user.save!					
				#sm = SendEmail.new({:to => email, :token => newpass, :reason => 'reset'})
	  			#sm.async.perform
				@emailclient.publish('/topic/hpumail', {:to => email, :token => newpass, :reason => 'reset'}.to_json, {:persistent => 'true'})
	  			return {:code => 1, :msg => 'Một email kèm thông tin tài khoản đã được gởi đến hòm thư của bạn, vui lòng kiểm tra thư trong vòng 10 phút nữa'}
			else
				return {:code => -1, :msg => 'Tài khoản này không tồn tại, vui lòng thử lại'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error 1'}
		end
	end
	def changeprofile(email, xprofile)
		begin			
			user = get_user(email)
			return {:code => -1, :msg => 'Tài khoản này không tồn tại'} if user == nil			
			user.attributes = {:hovaten => (xprofile[:hovaten] if xprofile.has_key?(:hovaten)),
				:gioitinh => (xprofile[:gioitinh] if xprofile.has_key?(:gioitinh)),
				:ngaysinh => (xprofile[:ngaysinh] if xprofile.has_key?(:ngaysinh)),
				:diachi => (xprofile[:diachi] if xprofile.has_key?(:diachi)),				
				:contact => (xprofile[:contact] if xprofile.has_key?(:contact)),
				:dienthoai => (xprofile[:dienthoai] if xprofile.has_key?(:dienthoai))}
			if user.save				
				return {:code => 1, :msg => 'Hồ sơ cập nhật thành công'}
			end
		rescue
			return {:code => -1, :msg => 'Unknown error 2'}
		end
	end
	def register(email, password, role, xprofile)		
		begin
			return {:code => 1, :msg => 'Registered'}  if get_user(email)
			return {:code => -1, :msg => 'Tài khoản này đã được đăng ký, nếu bạn quên mật khẩu hãy sử dụng chức năng quên mật khẩu' } if get_activated_user(get_user(email))
			user = User.new(:email => email, :contact => email, :password => hash_pass(password), :status => 0,  :created_at => Time.now, :role => role)					    
			register_confirm = Activation.new(:token => SecureRandom.hex, :created_at => Time.now, :description => 'Register confirmation', :status => 0)			 
			register_confirm.user = user
		  	user.masinhvien = xprofile[:masinhvien] if xprofile and xprofile.has_key?(:masinhvien)		  
		    if user.save and register_confirm.save  and register_confirm.save					  	
			  	#sm = SendEmail.new({:to => email, :token => register_confirm.token, :reason => 'register'})
			  	#sm.async.perform			  	
				@emailclient.publish('/topic/hpumail', {:to => email, :token => register_confirm.token, :reason => 'register'}.to_json, {:persistent => 'true'})
			  	self.async.getprofile(email, user.masinhvien) if xprofile and xprofile.has_key?(:masinhvien)			  	
			    return {:code => 1, :msg => 'Một email kích hoạt đã được gởi đến hòm thư của bạn, vui lòng kiểm tra thư để kích hoạt đăng ký trong vòng 10 phút nữa'}
			end
	    rescue
	  	  return {:code => -1, :msg => 'Unknown Error 3'}
	    end
	end	
	def register_guest(email, password, xprofile)	
		begin			
			gvtest = checkgv(email)		
			puts "gvtest"
			if gvtest			
				l2 = @ds.select {|l| l[:email] and l[:email].is_a?(String) and l[:email].strip == email}
				l3 = l2[0].to_hash if l2 and l2.length > 0				
				a1 = (l3[:ma_giao_vien].strip if l3.has_key?(:ma_giao_vien) and l3[:ma_giao_vien].is_a?(String) ) || ""			
				xprofile[:masinhvien] = "'" + a1 + "'"
				hodem = (l3[:ho_dem].strip if l3.has_key?(:ho_dem) ) || ""
				ten = (l3[:ten].strip if l3.has_key?(:ten) ) || ""
				xprofile[:hovaten] = "#{hodem} #{ten}"
				
				return register(email, password, 2, xprofile)
			else
				return register(email, password, 0, xprofile)
			end
		rescue
			return {:code => -1, :msg => 'Internal server error'}
		end
	end
	def register_student(sis, email, password, xprofile)
		begin
			if email.include?("hpu.vn") then 
				return {:code => -1, 
					:msg => "Email #{email} không thể sử dụng, vui lòng liên hệ phòng Quản trị mạng tầng 2 nhà G"} 
			end
			svtest = checksv(email, sis)
			if svtest[:code] == 1								
				return register(email, password, 1, xprofile)
			else
				return svtest
			end
		rescue
			return {:code => -1, :msg => 'Internal server error'}
		end
	end	
	
	
	def generate_password(size = 6)
	  charset = %w{ 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z}
	  (0...size).map{ charset.to_a[rand(charset.size)] }.join
	end
	def hash_pass(password)
		return Digest::MD5.hexdigest(password)
	end
end