# encoding: UTF-8
require 'sinatra/base'
require 'cas_helpers'
require 'rack-flash'
require 'rack/csrf'
require 'json'
require 'savon'
#require_relative './userservice_test'
require_relative './userservice'
class CasExample < Sinatra::Base
  #use Rack::Session::Cookie, :secret => 'changeme' #using session cookies in production with CAS is NOT recommended
  enable :sessions
  #use Rack::Csrf, :raise => true
  use Rack::Csrf, :check_only => ['POST:/signup']
  use Rack::Flash, :sweep => true
  helpers CasHelpers

  #use Rack::Flash
  set :environment, :production
  set :erb, :layout => false
  #set :root, File.dirname(__FILE__)
  set :root, File.expand_path('.')
  set :views, Proc.new { File.join(root, "lib/views") }
  set :public_folder, Proc.new { File.join(root, "static") }
  @@us = UserService.new
  @@service_url = 'http://acc.hpu.edu.vn'  
  @@cas_url = 'http://login.hpu.edu.vn'
  @@ds = @@us.getds
  # @@logservice = 
  before do    
	#@@ds = JSON.parse(IO.read("testres.json"))		
	@@key = "hpucas2013"
    process_cas_login(request, session)    
  end
  error 400..510 do
    'Boom'
  end
  post '/authenticate' do	
	begin		
		key = params[:key]
		return {}.to_json if key != @@key
		
		puts params[:user]
		puts params[:password]
		
		hash_pass = Digest::MD5.hexdigest(params[:password])
		us = User.first(:email => params[:user])	
		
		return {}.to_json unless us
		
		if us.password == hash_pass then
			return {}.to_json if us.role == 0
			if us.role == 1 # tai khoan sv
				puts us.email
				puts us.masinhvien.upcase
				
				return {:result => us.masinhvien.upcase}.to_json 
			end
			l2 = @@ds.select {|l| l[:email] and l[:email].is_a?(String) and l[:email].strip.downcase == us.email.downcase}	
			#l2 = @@ds.select {|l| l[:email] and l[:email].strip == us.email}
			if l2 == nil or l2.empty?
				puts "Empty l2"
				return {}.to_json  # la can bo nhung ko phai co van
			end
			l3 = l2[0].to_hash if l2 and l2.length > 0
			unless l3.has_key?(:ten_dang_nhap)
				puts "l3 khong co ten dang nhap"
				return {} 
			end
			#puts l3[:ma_nguoi_dung].strip if l3.has_key?
			#puts l2[0]["ma_nguoi_dung"].strip
			# log us.email vao cac time...
			puts us.email
			puts l3[:ten_dang_nhap].strip.downcase if l3.has_key?(:ten_dang_nhap)
			return {:result => l3[:ten_dang_nhap].strip}.to_json # tai khoan co van
		else
			return {}.to_json # sai mat khau
		end
	rescue
		return {}.to_json # unknown error
	end
  end
  post '/wifiauth' do
	begin
		key = params[:key]
		return {}.to_json if key != @@key
		
		hash_pass = Digest::MD5.hexdigest(params[:password])
		us = User.first(:email => params[:user])	
		return {}.to_json unless us
		puts "ok"
		if us.password == hash_pass then
			return {:role => 0}.to_json if us.role == 0
			return {:role => 1, :masinhvien => us.masinhvien.upcase, :ngaysinh => us.ngaysinh}.to_json if us.role == 1
			return {:role => 2, :ngaysinh => us.ngaysinh}.to_json if us.role == 2
		else
			return {}.to_json
		end
	rescue
		return {}.to_json
	end
  end
  
  get "/allemail" do
	key = params[:key]
	return {}.to_json unless key != 'hpuemail'
	return User.all(:status => 1, :role => 1).to_json
  end
  
  get "/" do   
    puts "ticket: #{session[:cas_ticket]}"  
    if !logged_in?(request, session) then       
      erb :index #, :locals => {:csrf => params[Rack::Csrf.field]}
    else      
      erb :home
    end
  end
  post "/reset" do
    redirect '/'  if logged_in?(request, session)
    email = params[:user][:email].gsub(/\s+/, "")
    v = @@us.resetpassword(email)
    case v[:code]
    when -2
      flash[:error] = v[:msg]
    when -1 
      flash[:error] = v[:msg]
    when 1
      flash[:success] = v[:msg]      
    end
    redirect "/"
  end

  get "/redirect" do
    require_authorization(request, session) unless logged_in?(request, session)    
    redirect '/'
  end
  # change profile
  post "/" do 
    redirect "/" unless logged_in?(request, session) 
    email = params[:profile][:contact].strip
    hovaten = params[:profile][:hovaten].strip
    ngaysinh = params[:profile][:ngaysinh].strip
    #hovaten, ngaysinh, diachi, gioitinh, sodienthoai
    diachi = params[:profile][:diachi].strip
    gioitinh = params[:profile][:gioitinh].strip
    dienthoai = params[:profile][:dienthoai].strip
    if !valid_date?(ngaysinh) 
          flash[:error] = "Vui lòng nhập ngày tháng theo định dạng ngày/tháng/năm (ví dụ: 18/05/1990)"
          redirect "/"      
    end
	if valid_date?(ngaysinh)
		ns = Date.strptime(ngaysinh,"%d/%m/%Y")
		begin_date = Date.strptime('01/01/1900',"%d/%m/%Y")
		end_date = Date.strptime('31/12/2012',"%d/%m/%Y")
		if ns < begin_date or ns > end_date then
			flash[:error] = "Vui lòng nhập ngày tháng theo định dạng ngày/tháng/năm (ví dụ: 18/05/1990)"
          redirect "/" 
		end
	end
    xprofile = {
      :contact => (email if @@us.checkrealmail(email) ),
      :hovaten => (hovaten unless hovaten.empty?),
      :ngaysinh => (ngaysinh if valid_date?(ngaysinh)),
      :diachi => (diachi unless diachi.empty?),
      :gioitinh => (gioitinh unless gioitinh.empty?),
      :dienthoai => (dienthoai unless dienthoai.empty?)}
    v = @@us.changeprofile(session[:cas_user], xprofile)
    case v[:code]
    when -1
      flash[:error] = v[:msg] 
    when 1
      flash[:success] = v[:msg]
    end
    redirect "/"
  end
  post '/reconfirm' do
    begin
      v = @@us.send_confirm(session[:cas_user])
      case v[:code]
      when -1
         flash[:error] = v[:msg]
      when -2
         flash[:error] = v[:msg]
      when 1
          flash[:success] = v[:msg]
      when 2
         flash[:notice] = v[:msg]
      end
      redirect '/'
    rescue
      flash[:error] = "Co loi xay ra"
      redirect "/"
    end
  end
  # change password
  post "/changepassword" do
    oldpassword = params[:user][:oldpassword].strip
    newpassword = params[:user][:password].strip
    newpassword2 = params[:user][:password2].strip
    v = @@us.changepassword(session[:cas_user], oldpassword, newpassword, newpassword2)
    case v[:code]
    when -1
      flash[:error] = v[:msg]
    when 1
      flash[:success] = v[:msg]
    end      
    redirect '/'
  end
  get "/activate/:token" do |token|    
    v = @@us.confirm_register(token)
    case v[:code]
    when -2
        flash[:error] = v[:msg]        
    when -1
        flash[:error] = v[:msg]        
    when 0
        flash[:error] = v[:msg]        
    when 1
        flash[:success] = v[:msg]        
    when 2
        flash[:notice] = v[:msg]        
    end    
    redirect "/"
  end
  # post register
  post "/signup" do
    redirect "/" if logged_in?(request, session)


    email = params[:user][:email]
	
	#if email == "anhnth@hpu.edu.vn" then puts @@us.checkrealmail(email) end
    #if @@us.checkrealmail(email) then
#		puts "email OK"
#	else
 #     flash[:error] = 'Email này không hợp lệ, vui lòng thử lại'
  #    redirect '/'
   # end
    if @@us.get_user(email) then
      flash[:warning] = 'Email này đã tồn tại, nếu bạn quên mật khẩu, vui lòng khởi tạo mật khẩu'
      redirect '/'
    end
	
    password = params[:user][:password].gsub(/\s+/, "")
    password2 = params[:user][:password2].gsub(/\s+/, "")
    

    if password == password2 then            

      if password.length < 6 then
        flash[:warning] = 'Mật khẩu quá ngắn, phải có ít nhất 6 ký tự'
        redirect '/'
      end 
      
      msv = params[:user][:msv].strip  unless params[:user][:msv].empty?      
      xprofile = {}       

      if msv && !msv.empty?  then 
        xprofile[:masinhvien] = msv
        #xprofile = xprofile.merge!(xxprofile) if xxprofile          
        v = @@us.register_student(msv, email, password, xprofile)
      else
        v = @@us.register_guest(email, password, xprofile)
      end

      if v[:code] == 1 then 
        flash[:success] = v[:msg]
        redirect "/"
      else 
        flash[:error] = v[:msg]
        redirect "/"
      end
    else
      flash[:error] = "Mật khẩu xác nhận không trùng"
      redirect "/"
    end
  end
  get "/logout" do    
    session[:cas_user] = ''
    session[:cas_ticket] = ''
    puts "logout: #{session[:cas_ticket]}"     
    redirect logout_url
  end
  
  helpers do
	def valid_date?( str, format="%d/%m/%Y" )
		  Date.strptime(str,format) rescue false		  
	end
     def logged_in?(request, session)
      session[:cas_user] and session[:cas_ticket] and !session[:cas_ticket].empty?    
    end
    def flash_types
      [:success, :notice, :warning, :error]
    end
    def login_url 
      "#{@@cas_url}/login?service=#{@@service_url}/redirect"
    end
    def logout_url
      "#{@@cas_url}/logout?service=#{@@service_url}"
    end
    def current_user
      @@us.get_user(session[:cas_user])    
    end
      
  end
end
