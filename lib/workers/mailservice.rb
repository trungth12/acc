# encoding: UTF-8
require 'pony'
require 'celluloid'

class SendEmail
  include Celluloid

  #@queue = :email
  def initialize(obj)
    @to = obj[:to]
    @token = obj[:token]
    @reason = obj[:reason]
  end
  def perform
		msubject = ""
  		puts "sending email to #{@to} with token #{@token} with reason #{@reason}"  
      if @reason == 'register'     
		msubject = "Xác nhận tài khoản đăng ký"
        body = 'Cám ơn bạn đã đăng ký tài khoản tại Đại học Dân Lập Hải Phòng. 
		Xin vui lòng nhấn vào  http://acc.hpu.edu.vn/activate/' + @token+' để hoàn thành đăng ký.'
      else
		msubject = "Yêu cầu lấy mật khẩu mới"
        body = "Bạn đã yêu cầu khởi tạo mật khẩu. Tài khoản mới của bạn là:
		Tên đăng nhập: #{@to}, Mật khẩu mới: #{@token}. Bây giờ bạn có thể vào http://acc.hpu.edu.vn để thay đổi mật khẩu của mình." 
      end
	r = rand(3*60) + 10
	after(r) {
      Pony.mail :to => @to,
                :from => 'hpu@hpu.edu.vn',
                :subject => msubject,
                :body =>  body,
				:via => :smtp,
                :via_options => {
					:address => 'smtp.gmail.com',
					:port => '587',
					:enable_starttls_auto => true,
					:user_name => 'hpu@hpu.edu.vn',
					:password => 'hpuqtm786',
					:authentication => :plain,
					:domain => "acc.hpu.edu.vn"
                }
	}
  #   Tire.index 'emaillog' do      
   #   create
    #  store :email_to => to,   :time => Time.now, :token => token, :reason => reason
     # refresh
    #end
	
  end
end