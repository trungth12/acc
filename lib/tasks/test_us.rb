# encoding: UTF-8
require_relative '../models'
require 'savon'
require_relative '../userservice'

us = User.all(:role => 2, :email => 'dungth@hpu.edu.vn').first
@us = UserService.new
@@ds = @us.getds


	l2 = @@ds.select {|l| l[:email] and l[:email].is_a?(String) and l[:email].strip.downcase == us.email.downcase}	
	l3 = l2[0].to_hash if l2 and l2.length > 0	
	if l3
		a1 = (l3[:ma_giao_vien].strip.to_s if l3.has_key?(:ma_giao_vien) ) || ""
		puts l3[:ten_dang_nhap] if l3.has_key?(:ten_dang_nhap)
	end

