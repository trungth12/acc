# encoding: UTF-8
require_relative '../models'
require 'savon'

users = User.all(:role => 2)

client = Savon.client(wsdl: "http://10.1.0.238:8082/HPUWebService.asmx?wsdl")
response = client.call(:danh_sach_can_bo_giang_vien)
		
res_hash = response.body.to_hash;
ls = res_hash[:danh_sach_can_bo_giang_vien_response][:danh_sach_can_bo_giang_vien_result][:diffgram][:document_element][:danh_sach_can_bo_giang_vien];

users.each do |us|
	l2 = ls.select {|l| l[:email] and l[:email].is_a?(String) and l[:email].strip.downcase == us.email.downcase}	
	l3 = l2[0].to_hash if l2 and l2.length > 0	
	if l3
		a1 = (l3[:ma_giao_vien].strip.to_s if l3.has_key?(:ma_giao_vien) ) || ""
		puts l3[:ten_dang_nhap] if l3.has_key?(:ten_dang_nhap)
		us.masinhvien = "'" + a1 + "'"
		us.save
	end
end
