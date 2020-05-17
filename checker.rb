#!/usr/bin/env ruby

require 'date'
require 'json'
require 'net/smtp'
require 'open-uri'
require 'nokogiri'
require 'selenium-webdriver'

PASSWORD='youappkey'
FROM_EMAIL='test@gmail.com'
ACTUALLY_SEND=false

TO_CHECK = {
	bob_red_mill_ap: {
		type: :red_mill,
		name: "Bob Red Mill's AP Flour",
		url: "https://www.bobsredmill.com/shop/flours-and-meals/unbleached-all-purpose-white-flour.html",
	},
	bob_red_mill_ap_organic: {
		type: :red_mill,
		name: "Bob Red Mill's AP Organic Flour",
		url: "https://www.bobsredmill.com/shop/flours-and-meals/organic-all-purpose-unbleached-white-flour.html",
	},
	bob_red_mill_whole_wheat: {
		type: :red_mill,
		name: "Bob Red Mill's Whole Wheat Flour",
		url: "https://www.bobsredmill.com/shop/flours-and-meals/whole-wheat-flour.html",
	},
	bob_red_mill_whole_wheat_organic: {
		type: :red_mill,
		name: "Bob Red Mill's Whole Wheat Organic Flour",
		url: "https://www.bobsredmill.com/shop/flours-and-meals/organic-whole-wheat-flour.html",
	},
	king_arthur_ap_5lb: {
		type: :king_arthur,
		name: "King Arthur's AP Flour (5lb)",
		url: "https://shop.kingarthurflour.com/items/king-arthur-unbleached-all-purpose-flour-5-lb",
	},
	king_arthur_ap_10lb: {
		type: :king_arthur,
		name: "King Arthur's AP Flour (10lb)",
		url: "https://shop.kingarthurflour.com/items/king-arthur-unbleached-all-purpose-flour-10-lb",
	},
	king_arthur_whole_wheat: {
		type: :king_arthur,
		name: "King Arthur's Whole Wheat Flour",
		url: "https://shop.kingarthurflour.com/items/king-arthur-premium-100-whole-wheat-flour-5-lb",
	}
}

def send_mail(name, msg, time, prev_sent)
	puts "[#{time}]: Found product: #{name}"

	d = time.to_date.to_s
	if prev_sent.dig(d)&.include?(name)
		puts "[#{time}]: Suppressed sending mail about '#{name}'."
		return 0
	else
		if prev_sent.has_key?(d)
			prev_sent[d] << name
		else
			prev_sent[d] = [name]
		end
	end


	message = <<MESSAGE_END
From: Flour Checker <test@gmail.com>
To: Your Email <test@gmail.com>
Subject: #{name} Available

#{msg}
MESSAGE_END

	if ACTUALLY_SEND
		smtp = Net::SMTP.new 'smtp.gmail.com', 587
		smtp.enable_starttls
		smtp.start('gmail.com', FROM_EMAIL, PASSWORD, :login) do |smtp|
			smtp.send_message message, FROM_EMAIL, 'test@gmail.com'
		end
	else
		puts "Would send:\n#{message}"
	end
end

t = Time.new
puts "[#{t}]: STARTED"
r = rand(2)
puts "[#{t}]: Sleeping for #{r} seconds."
sleep r

prev_sent = {}
begin
	prev_sent = JSON.parse(File.read("sent"))
rescue
	prev_sent = {}
end

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
driver = Selenium::WebDriver.for :chrome, options: options
found = []
TO_CHECK.each do |k, v|
	if v[:type] == :king_arthur
		contents = URI.open(v[:url]).read
		unless contents.include? "Item is temporarily unavailable"
			send_mail(v[:name], v[:url], t, prev_sent)
			found << v[:name]
		end
	else # Bob Red Mill
		driver.navigate.to v[:url]
		doc = Nokogiri::HTML(driver.page_source)
		if doc.css(".product-info-main").search(".//span[contains(text(), 'Out of stock')]").empty?
			send_mail(v[:name], v[:url], t, prev_sent)
			found << v[:name]
		end
	end
end

File.write("sent", JSON.generate(prev_sent))

if found.empty?
	puts "[#{t}]: No product available :("
else
	puts "[#{t}]: Found some product availability: #{found.join(", ")}"
end

puts "[#{t}]: ENDED"
