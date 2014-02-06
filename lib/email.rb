require 'stomp'
require 'pony'
require 'json'
require 'logger'

logger = Logger.new('emaillog.txt', 'daily')
logger.level = Logger::INFO


def process(obj)
	oobj = JSON.parse(obj)
		to = oobj["to"]
		token = oobj["token"]
		reason = oobj["reason"]
		msubject = ""
  		logger.info("sending email to #{to} with token #{token} with reason #{reason}")
      if @reason == 'register'     
		msubject = "Xác nhận tài khoản đăng ký"
        body = 'Cám ơn bạn đã đăng ký tài khoản tại Đại học Dân Lập Hải Phòng. 
		Xin vui lòng nhấn vào  http://acc.hpu.edu.vn/activate/' + token+' để hoàn thành đăng ký.'
      else
		msubject = "Yêu cầu lấy mật khẩu mới"
        body = "Bạn đã yêu cầu khởi tạo mật khẩu. Tài khoản mới của bạn là:
		Tên đăng nhập: #{to}, Mật khẩu mới: #{token}. Bây giờ bạn có thể vào http://acc.hpu.edu.vn để thay đổi mật khẩu của mình." 
      end
	
	
      Pony.mail :to => to,
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
	
	r = rand(3*60) + 10
	sleep r	
  end

client = Stomp::Client.open "stomp://localhost:61613"
client.subscribe "/queue/hpumail" do |message|
	logger.info("received: #{message.body} on #{message.headers['destination']}")
	process(message.body)
end
client.join
 


  #client.close