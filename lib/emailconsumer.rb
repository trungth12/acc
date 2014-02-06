# encoding: UTF-8
require 'stomp'
require 'pony'
require 'json'
require 'logger'

@logger = Logger.new('emaillog.txt', 'daily')
@logger.level = Logger::INFO

def process(obj)
	oobj = JSON.parse(obj)
		to = oobj["to"]
		token = oobj["token"]
		reason = oobj["reason"]
		msubject = ""
  		@logger.info("sending email to #{to} with token #{token} with reason #{reason}")
      if reason == 'register'     
		msubject = "Xác nhận tài khoản đăng ký"
        body = "Cám ơn bạn đã đăng ký tài khoản tại Đại học Dân Lập Hải Phòng. \n
		Xin vui lòng nhấn vào   để hoàn thành đăng ký: \n
		http://acc.hpu.edu.vn/activate/" + token
	  elsif reason == 'resetpassword'
		msubject = "Yêu cầu đổi mật khẩu"
		body = "Bạn đã yêu cầu đổi mật khẩu. Tài khoản của bạn là:\n
		Tên đăng nhập: #{to} \n
		Mật khẩu: #{token}"
      else
		msubject = "Yêu cầu lấy mật khẩu mới"
        body = "Bạn đã yêu cầu khởi tạo mật khẩu. Tài khoản mới của bạn là:\n
		Tên đăng nhập: #{to} \n
		Mật khẩu mới: #{token} \n"
      end
	
	r = rand(10) + 5
	sleep r	
      Pony.mail :to => to,
                :from => ( to.upcase.include?("YAHOO.COM")  ? "nethpu@yahoo.com" : 'hpu@hpu.edu.vn'),
                :subject => msubject,
                :body =>  body,
				:via => :smtp,
                :via_options => {
					:address => ( to.upcase.include?("YAHOO.COM") ?  'smtp.mail.yahoo.com':'smtp.gmail.com'),
					:port => '587',
					:enable_starttls_auto => true,
					:user_name => ( to.upcase.include?("YAHOO.COM") ? 'nethpu@yahoo.com' : 'hpu@hpu.edu.vn'),
					:password => ( to.upcase.include?("YAHOO.COM") ? '@guimaildangkyAcctuyahoo2013%': 'hpuqtm786'),
					:authentication => :plain,
					:domain => "acc.hpu.edu.vn"
                }
	
	
  end

client_id = "hpustomp"
subscription_name = "hpustomp"

stomp_params = {
:hosts => [
	{:host => "localhost", :port => 61613}
],
:connect_headers => {'client-id' => client_id},
}

client = Stomp::Client.new stomp_params
client.subscribe "/topic/hpumail", {"ack" => "client", "activemq.subscriptionName" => subscription_name} do |message|
	logstr = "received: #{message.body} on #{message.headers['destination']}"
	@logger.info(logstr)
	puts logstr
	begin
		process(message.body) 
		client.acknowledge message
	rescue Exception => e
		puts "Error #{e}"
	end
end
client.join
 


  #client.close