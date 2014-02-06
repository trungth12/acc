# encoding: UTF-8
require_relative '../userservice'
require 'json'

us = UserService.new
users = repository(:default).adapter.select('select masinhvien, role, status, count(*) from users
group by masinhvien, role, status having count(*) > 1  and role=1 and status=1')
res = []
users.each do |user|	
	uss = User.all(:masinhvien => user.masinhvien)
	puts "MSV: #{user.masinhvien}: #{uss.size}"
	uss.each do |su|		
		newmail = us.getemail(user.masinhvien)
		if user.email.casecmp(newmail[:email]) != 0 then
			res << user.id
		else
			puts "#{su.email}, #{user.id}"
		end
	end	
end
File.open("E:/dungth/ll.txt","w") {|f| f.write(Marshal.dump(res))}