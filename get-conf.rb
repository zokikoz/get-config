#!/usr/bin/env ruby
# get-conf
# Gets configurations of network devices via telnet session

require 'net-telnet'
require 'yaml'

require './templates'

# Adding to hash only new keys and values (don't change old)
class Hash
  def safe_merge!(from)
    merge!(from) { |_key, old| old }
  end
end

# Creating network device object using net-telnet module
class NetDevice
  DEFAULT = {
    name: 'localhost',
    host: 'localhost',
    port: 23,
    type: 'example',
    user: 'username',
    pswd: 'password'
  }.freeze

  def initialize(options)
    @options = DEFAULT.merge(options)
    # Generating connection hash for net-telnet module
    @connection = if @options.key?(:logs)
                    { 'Host' => @options[:host], 'Port' => @options[:port], 'Output_log' => @options[:logs] }
                  else
                    { 'Host' => @options[:host], 'Port' => @options[:port] }
                  end
  end

  # Setting default login from pswd.yml file if credentials is not set in pool.yml
  def self.set_login(options, passwords)
    default = { user: 'default-user', pswd: 'default-password' }
    catch(:done) do
      passwords.each do |group|
        case group[:type]
        when 'default'
          default.merge!(group) # Saving default login
        when Array
          group[:type].each do |type|
            if type == options[:type]
              options.safe_merge!(group)
              throw :done
            end
          end
        when options[:type]
          options.safe_merge!(group)
          throw :done
        end
      end
      options.safe_merge!(default) # Setting default login if not find any suitable type in pswd.yml
    end
  end
  # set_login

  # Mixin templates methods for various types of network devices
  include Templates

  # Getting gonfiguration by command line templates
  def load_config
    send(@options[:type]) # Using @options[:type] value as method name from templates module
  rescue StandardError => e
    e
  end
end
# NetDevice

# Creating pool and passwords example files
unless File.exist?('pool.yml')
  puts 'Creating example devices pool file (pool.yml)'
  pool = [{ name: 'full-example', host: 'localhost', port: 23, type: 'example',
            user: 'cisco', pswd: 'cisco', logs: 'example.log' },
          { name: 'base-example', host: '127.0.0.1', type: 'cisco' }]
  File.open('pool.yml', 'w') { |file| file.write(pool.to_yaml) }
end
unless File.exist?('pswd.yml')
  puts 'Creating example passwords file (pswd.yml)'
  passwords = [{ user: 'default-user', pswd: 'default-password', type: 'default' },
               { user: 'root', pswd: 'amnesiac', type: %w[juniper juniper1] }]
  File.open('pswd.yml', 'w') { |file| file.write(passwords.to_yaml) }
end

# Loading passwords and pool files
passwords = YAML.safe_load(File.read('pswd.yml'), [Symbol])
pool = YAML.safe_load(File.read('pool.yml'), [Symbol])

unless pool.nil? || passwords.nil?
  pool.each do |options|
    puts options
    NetDevice.set_login(options, passwords) unless options.key?(:user) && options.key?(:pswd)
    puts options
    device = NetDevice.new(options)
    result = device.load_config
    print result
  end
end
