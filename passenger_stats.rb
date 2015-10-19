#!/usr/bin/env ruby

require 'nokogiri'
require 'socket'
require 'optparse'
require 'yaml'

script_dir = File.dirname(__FILE__)
if ( File.exist?('/etc/passenger_stats.conf'))
  conf_file = '/etc/passenger_stats.conf'
elsif ( File.exist?('/usr/local/etc/passenger_stats.conf'))
  conf_file = '/usr/local/etc/passenger_stats.conf'
elsif ( File.exist?("#{script_dir}/passenger_stats.conf"))
  conf_file = "#{script_dir}/passenger_stats.conf"
else
    abort("\nNo configuration file in /etc, /usr/local/etc, or #{script_dir}")
end

options = YAML.load_file("#{conf_file}")

# set defaults for some options if not specified in config and abort if no server is specifed
if ( options['cmd_path'].nil? ) || (!options['cmd_path'].nil? && options['cmd_path'].empty?)
  options['cmd_path'] = '/usr/bin/passenger-status'
end
if ( options['scheme'].nil? ) || (!options['scheme'].nil? && options['scheme'].empty?)
  options['scheme'] = "#{Socket.gethostname}.passenger"
end
if ( options['server_port'].nil? ) || (!options['server_port'].nil? && options['server_port'].empty?)
  options['server_port'] = '2003'
end
if ( options['server'].nil? ) || (!options['server'].nil? && options['server'].empty?)
  abort("\n\nNo Graphite servers specifed in #{conf_file}\n\n")
end

# REMOVE_PATH is stripped from the metric name. The root directory which contains the directories for your app(s).
REMOVE_PATH = "#{options['metric_strip']}"
TIMESTAMP = Time.now.to_i.to_s
METRIC_BASE_NAME = "#{options['scheme']}"
GRAPHITE_HOST= "#{options['server']}"
GRAPHITE_PORT= "#{options['server_port']}"
CLIENT_SOCKET = TCPSocket.new( GRAPHITE_HOST, GRAPHITE_PORT )

#PROCESS_ELEMENTS = %w(pid real_memory cpu vmsize processed)
PROCESS_ELEMENTS = %w(real_memory cpu vmsize processed)

#doc = Nokogiri::XML(File.open("#{script_dir}/passenger-out.xml"))  # for testing with a local xml file
doc = Nokogiri::XML(`#{options['cmd_path']} --show=xml`)

# Get overall (top level) passenger stats
process_count = doc.xpath('//process_count').children[0].to_s
max_pool_size = doc.xpath('//max').children[0].to_s
capacity_used = doc.xpath('//capacity_used').children[0].to_s
top_level_queue = doc.xpath('//get_wait_list_size').children[0].to_s

CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.process_count #{process_count} #{TIMESTAMP}\n")
CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.max_pool_size #{max_pool_size} #{TIMESTAMP}\n")
CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.capacity_used #{capacity_used} #{TIMESTAMP}\n")
CLIENT_SOCKET.write("#{METRIC_BASE_NAME}.top_level_queue #{top_level_queue} #{TIMESTAMP}\n")
CLIENT_SOCKET.close
#puts("#{METRIC_BASE_NAME}.process_count #{process_count} #{TIMESTAMP}\n")
#puts("#{METRIC_BASE_NAME}.max_pool_size #{max_pool_size} #{TIMESTAMP}\n")
#puts("#{METRIC_BASE_NAME}.capacity_used #{capacity_used} #{TIMESTAMP}\n")
#puts("#{METRIC_BASE_NAME}.top_level_queue #{top_level_queue} #{TIMESTAMP}\n")

# extract stat given process element
def extract_elements(process, prefix_name)
  PROCESS_ELEMENTS.map { |el| "#{prefix_name}.#{el} " + process.xpath("./#{el}").first.content }
end

# get process stats in the correct format and strip REMOVE_PATH
def name_format(name, process_index)
  name.gsub(/#{REMOVE_PATH}/,'').gsub(/\//, '_').gsub(/_current$/,'.') + "process_#{process_index}"
end

# Get per app and per process stats
doc.xpath('//supergroups')[0].xpath('./supergroup').each do |supergroup|
  name = METRIC_BASE_NAME + '.' + supergroup.xpath('./name')[0].content
  # Per app overall stats
  wait_list = supergroup.xpath('./get_wait_list_size')[0].content
  capacity_used = supergroup.xpath('./capacity_used')[0].content
  prefix_name_ = name.gsub(/#{REMOVE_PATH}/,'').gsub(/\//, '_').gsub(/_current$/,'')
  supergroup_CLIENT_SOCKET = TCPSocket.new( GRAPHITE_HOST, GRAPHITE_PORT )
  supergroup_CLIENT_SOCKET.write("#{prefix_name_}.wait_list #{wait_list} #{TIMESTAMP}\n")
  supergroup_CLIENT_SOCKET.write("#{prefix_name_}.capacity_used #{capacity_used} #{TIMESTAMP}\n") 
  supergroup_CLIENT_SOCKET.close_write
  #puts("#{prefix_name_}.wait_list #{wait_list} #{TIMESTAMP}\n")
  #puts("#{prefix_name_}.capacity_used #{capacity_used} #{TIMESTAMP}\n") 
 # Per process stats
##  supergroup.xpath('./group/processes/process').each_with_index do |process, i|
##    prefix_name = name_format(name, i)
##    extract_elements(process, prefix_name).each do |stat| 
##      puts("prefix_name: #{prefix_name}")
##      puts("#{stat} #{TIMESTAMP}\n")
##      stat_CLIENT_SOCKET = TCPSocket.new( GRAPHITE_HOST, GRAPHITE_PORT )
##      stat_CLIENT_SOCKET.write("#{stat} #{TIMESTAMP}\n")
##      stat_CLIENT_SOCKET.flush
##      stat_CLIENT_SOCKET.close_write
##    end
## end
end

