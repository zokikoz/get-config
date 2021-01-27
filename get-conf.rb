#!/usr/bin/env ruby
# Get-Config
# Get network devices configuration using telnet session

require 'net-telnet'
require './templates'

# Creating network device object using net-telnet module
class NetDevice
  def initialize(options)
    @options = options
    @options[:host]      = 'localhost'  unless @options.has_key?(:host)
    @options[:port]      = 23           unless @options.has_key?(:port)
    @options[:type]      = 'cisco'      unless @options.has_key?(:type)
    @options[:login]     = 'cisco'      unless @options.has_key?(:login)
    @options[:password]  = 'cisco'      unless @options.has_key?(:password)
    # Generating connection hash for net-telnet module
    if @options.has_key?(:log_file)
      @connection = {"Host" => @options[:host], "Port" => @options[:port], "Output_log" => @options[:log_file]}
    else
      @connection = {"Host" => @options[:host], "Port" => @options[:port]}
    end
  end
  # Mixin templates methods for various types of network devices
  include Templates

  # Setting command line template based on network device type
  def GetConfig
    res = self.send(@options[:type]) # Using @options[:type] value as method name from templates module
  end
end

dev = NetDevice.new(host: '10.235.92.251', type: 'omnistack', login: 'cisco', password: 'cisco')
res = dev.GetConfig
print res
