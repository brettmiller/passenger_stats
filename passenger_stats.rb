#!/usr/bin/env ruby

require 'nokogiri'
require 'Socket'

#PROCESS_ELEMENTS = %w(pid real_memory cpu vmsize processed)
PROCESS_ELEMENTS = %w(real_memory cpu vmsize processed)
APP_PATH="/var/www/rails/"
TIMESTAMP = Time.now.to_i.to_s
METRIC_BASE_NAME = "#{Socket.gethostname}.passenger."

doc = Nokogiri::XML(File.open('./passenger-out.xml'))

def extract_elements(process, prefix_name)
  PROCESS_ELEMENTS.map { |el| "#{prefix_name}.#{el} " + process.xpath("./#{el}").first.content }
end

processes = doc.xpath('//process_count').children[0].to_s
max_pool_size = doc.xpath('//max').children[0].to_s
processes_used = doc.xpath('//capacity_used').children[0].to_s
top_level_queue = doc.xpath('//get_wait_list_size').children[0].to_s

puts METRIC_BASE_NAME + "processes " +  processes + " #{TIMESTAMP}\n"
puts METRIC_BASE_NAME + "max_pool_size " + max_pool_size + " #{TIMESTAMP}\n"
puts METRIC_BASE_NAME + "processes_used " + processes_used + " #{TIMESTAMP}\n"
puts METRIC_BASE_NAME + "top_level_queue " + top_level_queue + " #{TIMESTAMP}\n"


def name_format(name, process_index)
  name.gsub(/#{APP_PATH}/,'').gsub(/\//, '_').gsub(/_current$/,'_') + "process_#{process_index}"
end

doc.xpath('//supergroups')[0].xpath('./supergroup').each do |supergroup|
  name = METRIC_BASE_NAME + supergroup.xpath('./name')[0].content
  wait_list = supergroup.xpath('./get_wait_list_size')[0].content
  processes_used = supergroup.xpath('./capacity_used')[0].content
  prefix_name_ = name.gsub(/#{APP_PATH}/,'').gsub(/\//, '_').gsub(/_current$/,'')
  puts "#{prefix_name_}.wait_list #{wait_list}" + " #{TIMESTAMP}\n" 
  puts "#{prefix_name_}.processes_used #{processes_used}" + " #{TIMESTAMP}\n" 
  supergroup.xpath('./group/processes/process').each_with_index do |process, i|
    #puts "#{name_format(name, i)} wait_list: #{wait_list}" + "#{TIMESTAMP}\n" + extract_elements(process).join("\n ") + TIMESTAMP
    prefix_name = name_format(name, i)
    puts extract_elements(process, prefix_name).join(" #{TIMESTAMP}\n")
  end
end
