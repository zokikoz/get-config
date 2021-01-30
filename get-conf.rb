#!/usr/bin/env ruby
# Get-Config
# Get network devices configuration using telnet session

require 'net-telnet'
require 'yaml'

require './templates'

# Creating network device object using net-telnet module
class NetDevice
  def initialize(options)
    @options = options
    @options[:name] = 'localhost' unless @options.has_key?(:name)
    @options[:host] = 'localhost' unless @options.has_key?(:host)
    @options[:port] = 23          unless @options.has_key?(:port)
    @options[:type] = 'cisco'     unless @options.has_key?(:type)
    @options[:user] = 'username'  unless @options.has_key?(:user)
    @options[:pswd] = 'password'  unless @options.has_key?(:pswd)
    # Generating connection hash for net-telnet module
    if @options.has_key?(:logs)
      @connection = {"Host" => @options[:host], "Port" => @options[:port], "Output_log" => @options[:logs]}
    else
      @connection = {"Host" => @options[:host], "Port" => @options[:port]}
    end
  end
  # Mixin templates methods for various types of network devices
  include Templates

  # Getting gonfiguration by command line templates
  def getconfig
    res = self.send(@options[:type]) # Using @options[:type] value as method name from templates module
  end
end

# Creating pool and passwords example files
unless File.exist?("pool.yml")
  pool = [{ name: 'full-example', host: 'localhost', port: 23, type: 'cisco', user: 'cisco', pswd: 'cisco', logs: 'example.log' },
          { name: 'base-example', host: '127.0.0.1', type: 'cisco' }]
  File.open("pool.yml", "w") { |file| file.write(pool.to_yaml) }
end
unless File.exist?("pswd.yml")
  passwords = [{ user: 'default-user', pswd: 'default-password', type: 'default' },
          { user: 'root', pswd: 'amnesiac', type: ['juniper', 'juniper1'] }]
  File.open("pswd.yml", "w") { |file| file.write(passwords.to_yaml) }
end

# Loading passwords and pool files
passwords = YAML.load(File.read("pswd.yml"))
pool = YAML.load(File.read("pool.yml"))

pool.each do |options|
puts options
# Setting default login for device type if credentials is not set
  catch(:done) do
    if !(options.has_key?(:user) && options.has_key?(:pswd)) # Hello, De Morgan!
      def_user = nil ; def_pswd = nil
      passwords.each do |group|
        if group[:type] == 'default'
          def_user = group[:user] ; def_pswd = group[:pswd]
        elsif group[:type].is_a?(Array)
          group[:type].each do |type|
            if type == options[:type]
              options[:user] = group[:user] unless options.has_key?(:user)
              options[:pswd] = group[:pswd] unless options.has_key?(:pswd)
              throw :done
            end
          end
        elsif group[:type] == options[:type]
          options[:user] = group[:user] unless options.has_key?(:user)
          options[:pswd] = group[:pswd] unless options.has_key?(:pswd)
          throw :done
        end
      end
      options[:user] = def_user unless options.has_key?(:user)
      options[:pswd] = def_pswd unless options.has_key?(:pswd)
    end
  end

puts options

#  device = NetDevice.new(options)
#  result = device.getconfig
#  print result
end
