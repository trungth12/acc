# encoding: UTF-8
require 'stomp'
require 'pony'
require 'json'
require 'logger'

@logger = Logger.new('emaillog.txt', 'daily')
@logger.level = Logger::INFO


def process
      Pony.mail :to => "thdung1807@yahoo.com",
                :from => 'dlhphpu@yahoo.com',
                :subject => "Test",
                :body =>  "Dung",
				:via => :smtp,
                :via_options => {
					:address => 'smtp.mail.yahoo.com',
					:port => '587',
					:enable_starttls_auto => true,
					:user_name => 'dlhphpu@yahoo.com',
					:password => 'Hpuqtm786',
					:authentication => :plain,
					:domain => "acc.hpu.edu.vn"
                }
	
	
  end


process()
 


  #client.close