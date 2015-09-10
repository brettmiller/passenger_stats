#!/usr/bin/env ruby

require 'nokogiri'
require 'Socket'

PROCESS_ELEMENTS = %w(pid real_memory cpu vmsize processed)
TIMESTAMP = Time.now.to_i.to_s
METRIC_BASE_NAME = "#{Socket.gethostname}.passenger"

doc = Nokogiri::XML(File.open('./passenger-out.xml'))

def extract_elements(process)
  PROCESS_ELEMENTS.map { |el| "#{el}: " + process.xpath("./#{el}").first.content }
end

def name_format(name, process_index)
  name.gsub(/\//, '_') + "process_#{process_index}.pid"
end

doc.xpath('//supergroups')[0].xpath('./supergroup').each do |supergroup|
  name = METRIC_BASE_NAME + '.' + supergroup.xpath('./name')[0].content
  wait_list = supergroup.xpath('./get_wait_list_size')[0].content
  supergroup.xpath('./group/processes/process').each_with_index do |process, i|
    puts "#{name_format(name, i)} wait_list: #{wait_list} " + extract_elements(process).join(" ") + TIMESTAMP
  end
end
