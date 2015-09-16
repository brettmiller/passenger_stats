#!/usr/bin/env ruby

require 'nokogiri'
require 'Socket'

#PROCESS_ELEMENTS = %w(pid real_memory cpu vmsize processed)
PROCESS_ELEMENTS = %w(real_memory cpu vmsize processed)
# APP_PATH is stripped from the metric name
APP_PATH="/var/www/rails/"
TIMESTAMP = Time.now.to_i.to_s
METRIC_BASE_NAME = "#{Socket.gethostname}.passenger."
GRAPHITE_HOST='lvvsmuldatap01.vitalbook.com'
GRAPHITE_PORT='2003'
CLIENT_SOCKET = TCPSocket.new( GRAPHITE_HOST, GRAPHITE_PORT )

doc = Nokogiri::XML(File.open('./passenger-out.xml'))

def extract_elements(process, prefix_name)
  PROCESS_ELEMENTS.map { |el| "#{prefix_name}.#{el} " + process.xpath("./#{el}").first.content }
end

# Get overall (top level) passenger stats
processes = doc.xpath('//process_count').children[0].to_s
max_pool_size = doc.xpath('//max').children[0].to_s
processes_used = doc.xpath('//capacity_used').children[0].to_s
top_level_queue = doc.xpath('//get_wait_list_size').children[0].to_s

CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.processes #{processes} #{TIMESTAMP}\n")
CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.max_pool_size #{max_pool_size} #{TIMESTAMP}\n")
CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.processes_used #{processes_used} #{TIMESTAMP}\n")
CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.top_level_queue #{top_level_queue} #{TIMESTAMP}\n")

# get process stats in the correct format and strip APP_PATH
def name_format(name, process_index)
  name.gsub(/#{APP_PATH}/,'').gsub(/\//, '_').gsub(/_current$/,'_') + "process_#{process_index}"
end

# Get per app and per process stats
doc.xpath('//supergroups')[0].xpath('./supergroup').each do |supergroup|
  name = METRIC_BASE_NAME + supergroup.xpath('./name')[0].content
  # Per app overall stats
  wait_list = supergroup.xpath('./get_wait_list_size')[0].content
  processes_used = supergroup.xpath('./capacity_used')[0].content
  prefix_name_ = name.gsub(/#{APP_PATH}/,'').gsub(/\//, '_').gsub(/_current$/,'')
  CLIENT_SOCKET.write("#{prefix_name_}.wait_list #{wait_list} #{TIMESTAMP}\n")
  CLIENT_SOCKET.write("#{prefix_name_}.processes_used #{processes_used} #{TIMESTAMP}\n") 
  # Per process stats
  supergroup.xpath('./group/processes/process').each_with_index do |process, i|
    prefix_name = name_format(name, i)
    extract_elements(process, prefix_name).each do |stat| 
      puts("#{stat} #{TIMESTAMP}\n")
      #CLIENT_SOCKET.write("#{stat} #{TIMESTAMP}\n")
    end
  end
end

# Close TCP socket
CLIENT_SOCKET.close_write
