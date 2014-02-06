# encoding: UTF-8
require_relative '../models'


user = User.first(:email => "dungth@hpu.edu.vn")
if user then 
	user.masinhvien="00020003"
 user.save end